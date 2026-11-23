' Finds streams the same way the Vimeo player on the church website does:
'   1. vimeo.com/_next/viewer          -> an anonymous viewer token
'   2. api.vimeo.com/live_events/<id>  -> is a clip streaming right now?
'   3. .../live_events/<id>/videos     -> the event's videos (live one, or past services)
'   4. vimeo.com/event/<id>/embed      -> config link (embed-only events)
'   5. the player config               -> the .m3u8 link the Roku plays
' Failures return a short code shown on screen: V = live check, A = archive,
' R = playing an archive video; the number says which step failed.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    mode = m.top.mode
    if mode = "archive"
        m.top.result = loadArchive()
    else if mode = "play"
        m.top.result = resolvePlay(m.top.configUrl, m.top.videoUri)
    else
        m.top.result = resolveLive()
    end if
end sub

' ---------- Live ----------

function resolveLive() as Object
    cfg = AppConfig()
    auth = getAuth(cfg, "V")
    if not auth.ok then return auth.error

    ' The event: who can watch it, and which clip is live.
    eventFields = "title,uri,stream_privacy.view,stream_privacy.embed"
    eventFields = eventFields + ",clip_to_play.uri,clip_to_play.config_url,clip_to_play.live.status"
    eventFields = eventFields + ",streamable_clip.uri,streamable_clip.config_url,streamable_clip.live.status"
    r = httpGet(eventUrl(cfg) + "?fields=" + eventFields + "&clip_to_play_id=0" + referrerParam(cfg), apiHeaders(cfg, auth, "3.4.9"))
    event = invalid
    if r.code = 200 then event = ParseJson(r.body)
    if type(event) <> "roAssociativeArray" then return errorResult("V2", r)

    view = vpStr(vpGet(event, "stream_privacy.view"))
    if view = "nobody" then return { status: "error", code: "V2-PRIVATE" }

    clip = vpFindLiveClip(event)
    streamingSeen = clip.streaming
    configUrl = clip.configUrl

    ' Public events: look through the event's videos.
    if configUrl = "" and view <> "embed_only"
        r = fetchVideos(cfg, auth, "uri,config_url,created_time,live.status")
        if r.code = 200
            configUrl = vpFindVideo(ParseJson(r.body), false)
            if configUrl <> "" then streamingSeen = true
        else if not clip.known
            ' If the event already said nothing is live, a failure here doesn't matter.
            return errorResult("V3", r)
        end if
    end if

    ' Embed-only events: the embed page carries the config link.
    if configUrl = "" and view = "embed_only" and (clip.streaming or not clip.known)
        r = httpGet("https://vimeo.com/event/" + cfg.eventId + "/embed", {
            "Accept": "text/html,application/xhtml+xml"
            "Referer": cfg.embedPage
        })
        if r.code <> 200 then return errorResult("V4", r)
        configUrl = vpConfigUrlFromHtml(r.body)
    end if

    if configUrl = ""
        if streamingSeen then return { status: "error", code: "V4-NOCONFIG" }
        return { status: "offline" }
    end if

    ' The player config holds the actual video link.
    r = httpGet(configUrl, { "Accept": "application/json" })
    config = invalid
    if r.code = 200 then config = ParseJson(r.body)
    if type(config) <> "roAssociativeArray" then return errorResult("V5", r)
    stream = vpPickStream(config)

    isLive = (stream.liveStatus = "started") or (stream.liveStatus = "" and streamingSeen)
    if not isLive then return { status: "offline" }
    if stream.url = "" then return { status: "error", code: "V5-NOHLS" }
    return { status: "live", url: stream.url, title: stream.title }
end function

' ---------- Sermon archive ----------

function loadArchive() as Object
    cfg = AppConfig()
    auth = getAuth(cfg, "A")
    if not auth.ok then return auth.error

    ' The event's own title, so recordings that just repeat it can be labeled by date.
    eventTitle = ""
    r = httpGet(eventUrl(cfg) + "?fields=title" + referrerParam(cfg), apiHeaders(cfg, auth, "3.4.9"))
    if r.code = 200 then eventTitle = vpStr(vpGet(ParseJson(r.body), "title"))

    fields = "uri,name,created_time,duration,config_url,live.status"
    fields = fields + ",pictures.base_link,pictures.sizes.width,pictures.sizes.link"
    r = fetchVideos(cfg, auth, fields)
    if r.code <> 200 then return errorResult("A3", r)

    items = []
    for each video in vpArchiveItems(ParseJson(r.body), cfg.archiveCount)
        labels = vpItemLabels(video.name, eventTitle, vpFormatDate(video.created), vpDurationText(video.duration))
        items.Push({
            title: labels.title
            subtitle: labels.subtitle
            thumb: video.thumb
            configUrl: video.configUrl
            uri: video.uri
        })
    end for
    return { status: "ok", items: items }
end function

' Gets a playable link for an archive video. Saved config links can expire, so if
' the first try fails, ask Vimeo for a fresh one.
function resolvePlay(configUrl as String, videoUri as String) as Object
    stream = fetchConfigStream(configUrl)
    if not stream.ok and videoUri <> ""
        cfg = AppConfig()
        auth = getAuth(cfg, "R")
        if not auth.ok then return auth.error
        r = fetchVideos(cfg, auth, "uri,config_url")
        if r.code <> 200 then return errorResult("R3", r)
        data = vpGet(ParseJson(r.body), "data")
        if type(data) = "roArray"
            for each video in data
                if vpStr(vpGet(video, "uri")) = videoUri
                    stream = fetchConfigStream(vpStr(vpGet(video, "config_url")))
                    exit for
                end if
            end for
        end if
    end if
    if not stream.ok
        if stream.r = invalid then return { status: "error", code: "R5-NOHLS" }
        return errorResult("R5", stream.r)
    end if
    return { status: "play", url: stream.url, title: stream.title }
end function

' Downloads a player config and picks its video link.
' Returns { ok, url, title } or { ok: false, r } (r = the failed response, or invalid if no link).
function fetchConfigStream(configUrl as String) as Object
    if configUrl = "" then return { ok: false, r: invalid }
    r = httpGet(configUrl, { "Accept": "application/json" })
    config = invalid
    if r.code = 200 then config = ParseJson(r.body)
    if type(config) <> "roAssociativeArray" then return { ok: false, r: r }
    stream = vpPickStream(config)
    if stream.url = "" then return { ok: false, r: invalid }
    return { ok: true, url: stream.url, title: stream.title }
end function

' ---------- Vimeo plumbing ----------

' Returns { ok: true, auth } or { ok: false, error }.
function getAuth(cfg as Object, prefix as String) as Object
    if cfg.apiToken <> "" then return { ok: true, auth: "bearer " + cfg.apiToken }
    r = httpGet("https://vimeo.com/_next/viewer", { "Accept": "application/json" })
    if r.code <> 200 then return { ok: false, error: errorResult(prefix + "1", r) }
    jwt = vpStr(vpGet(ParseJson(r.body), "jwt"))
    if jwt = "" then return { ok: false, error: errorResult(prefix + "1J", r) }
    return { ok: true, auth: "jwt " + jwt }
end function

function eventUrl(cfg as Object) as String
    return "https://api.vimeo.com/live_events/" + cfg.eventId
end function

' Vimeo spells this query parameter with four R's.
function referrerParam(cfg as Object) as String
    return "&referrer=" + CreateObject("roUrlTransfer").Escape(cfg.embedPage)
end function

function apiHeaders(cfg as Object, auth as Object, version as String) as Object
    accept = "application/vnd.vimeo.*+json;version=" + version
    if version = "3.4.1" then accept = "application/vnd.vimeo.*;version=3.4.1"
    return { "Accept": accept, "Authorization": auth.auth, "Referer": cfg.embedPage }
end function

' The event's videos, newest first when Vimeo allows sorting.
function fetchVideos(cfg as Object, auth as Object, fields as String) as Object
    url = eventUrl(cfg) + "/videos?fields=" + fields + "&per_page=50&page=1" + referrerParam(cfg)
    headers = apiHeaders(cfg, auth, "3.4.1")
    r = httpGet(url + "&sort=date&direction=desc", headers)
    if r.code = 400 then r = httpGet(url, headers) ' sorting not supported here
    return r
end function

' Builds an error result like { code: "V2-403-3200" }: step, HTTP status, Vimeo error code.
function errorResult(stepCode as String, r as Object) as Object
    code = stepCode + "-" + r.code.ToStr()
    vimeoCode = ""
    if Left(r.body, 1) = "{" then vimeoCode = vpToText(vpGet(ParseJson(r.body), "error_code"))
    if vimeoCode <> "" then code = code + "-" + vimeoCode
    print "[VimeoTask] "; code; " "; r.reason; " "; Left(r.body, 300)
    return { status: "error", code: code }
end function

function httpGet(url as String, headers as Object) as Object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.RetainBodyOnError(true)
    xfer.EnableCookies()
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36")
    xfer.AddHeader("Accept-Language", "en-US,en;q=0.9")
    for each name in headers
        xfer.AddHeader(name, headers[name])
    end for

    result = { code: 0, body: "", reason: "" }
    if not xfer.AsyncGetToString()
        result.reason = "request did not start"
        return result
    end if
    msg = wait(15000, port)
    if type(msg) = "roUrlEvent"
        result.code = msg.GetResponseCode()
        result.body = msg.GetString()
        result.reason = msg.GetFailureReason()
    else
        xfer.AsyncCancel()
        result.reason = "timed out"
    end if
    return result
end function
