' Pure helpers for reading Vimeo's JSON and HTML. No network calls here, so these
' can be unit-tested off the TV (see tests/parse_test.brs).

' Reads a nested value such as "clip_to_play.live.status". Returns invalid if any
' part of the path is missing.
function vpGet(obj as Dynamic, path as String) as Dynamic
    cur = obj
    for each key in path.Split(".")
        if type(cur) <> "roAssociativeArray" then return invalid
        cur = cur.Lookup(key)
    end for
    return cur
end function

' Returns v if it is a string, otherwise "".
function vpStr(v as Dynamic) as String
    t = type(v)
    if t = "String" or t = "roString" then return v
    return ""
end function

' Formats a string or whole number for display; anything else becomes "".
function vpToText(v as Dynamic) as String
    t = type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v.ToStr()
    return ""
end function

' Looks at the event's clip_to_play / streamable_clip.
' Returns { known, streaming, configUrl }:
'   known     - Vimeo told us the live status of at least one clip
'   streaming - a clip is live right now
'   configUrl - player config link for the live clip, if Vimeo gave one
function vpFindLiveClip(eventJson as Dynamic) as Object
    out = { known: false, streaming: false, configUrl: "" }
    for each key in ["clip_to_play", "streamable_clip"]
        status = vpStr(vpGet(eventJson, key + ".live.status"))
        if status <> ""
            out.known = true
            if status = "streaming"
                out.streaming = true
                if out.configUrl = "" then out.configUrl = vpStr(vpGet(eventJson, key + ".config_url"))
            end if
        end if
    end for
    return out
end function

' Picks a video from the event's /videos list and returns its config link.
'   wantReplay = false: the one that is live right now
'   wantReplay = true:  the newest finished recording
function vpFindVideo(videosJson as Dynamic, wantReplay as Boolean) as String
    items = vpGet(videosJson, "data")
    if type(items) <> "roArray" then return ""
    best = ""
    bestTime = ""
    for each v in items
        status = vpStr(vpGet(v, "live.status"))
        url = vpStr(vpGet(v, "config_url"))
        if url <> ""
            if not wantReplay
                if status = "streaming" then return url
            else if status = "done" or status = ""
                created = vpStr(vpGet(v, "created_time"))
                if best = "" or created > bestTime
                    best = url
                    bestTime = created
                end if
            end if
        end if
    end for
    return best
end function

' Finds the player config link in the HTML of https://vimeo.com/event/<id>/embed
function vpConfigUrlFromHtml(html as String) as String
    q = Chr(34)
    re = CreateObject("roRegex", "data-config-url=" + q + "([^" + q + "]+)" + q, "")
    found = re.Match(html)
    if found.Count() > 1 then return found[1].Replace("&amp;", "&")

    ' Fallback: the link inside embedded JSON, e.g. "config_url":"https:\/\/player.vimeo.com\/..."
    re = CreateObject("roRegex", q + "config_url" + q + "\s*:\s*" + q + "([^" + q + "]+)" + q, "")
    found = re.Match(html)
    if found.Count() > 1 then return found[1].Replace("\/", "/").Replace("&", "&")
    return ""
end function

' Reads the HLS (.m3u8) link and live status out of a player config.
' Returns { url, liveStatus, title }. liveStatus is "started" while live.
function vpPickStream(config as Dynamic) as Object
    out = {
        url: ""
        liveStatus: vpStr(vpGet(config, "video.live_event.status"))
        title: vpStr(vpGet(config, "video.title"))
    }

    hls = vpGet(config, "request.files.hls")
    if type(vpGet(hls, "cdns")) <> "roAssociativeArray" then hls = vpGet(config, "video.files.hls")
    cdns = vpGet(hls, "cdns")
    if type(cdns) <> "roAssociativeArray" then return out

    ' Try Vimeo's preferred CDN first, then the others.
    order = []
    preferred = vpStr(vpGet(hls, "default_cdn"))
    if preferred <> "" and cdns.DoesExist(preferred) then order.Push(preferred)
    for each name in cdns
        if name <> preferred then order.Push(name)
    end for

    for each name in order
        cdn = cdns.Lookup(name)
        ' avc_url, when present, is H.264-only, which every Roku can decode.
        url = vpStr(vpGet(cdn, "avc_url"))
        if url = "" then url = vpStr(vpGet(cdn, "url"))
        if url <> ""
            out.url = url
            return out
        end if
    end for
    return out
end function
