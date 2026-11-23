' Finds the stream the same way the Vimeo player on the church website does:
'   1. vimeo.com/_next/viewer          -> an anonymous viewer token
'   2. api.vimeo.com/live_events/<id>  -> is a clip streaming right now?
'   3. .../live_events/<id>/videos     -> the event's videos (public events)
'   4. vimeo.com/event/<id>/embed      -> config link (embed-only events)
'   5. the player config               -> the .m3u8 link the Roku plays
' Each failure returns a short code (V1..V5) shown on screen to help debugging.

sub init()
    m.top.functionName = "fetchStream"
end sub

sub fetchStream()
    m.top.result = resolveStream(m.top.mode)
end sub

function resolveStream(mode as String) as Object
    cfg = AppConfig()
    wantReplay = (mode = "replay")

    ' 1. Authorization for api.vimeo.com.
    if cfg.apiToken <> ""
        auth = "bearer " + cfg.apiToken
    else
        r = httpGet("https://vimeo.com/_next/viewer", { "Accept": "application/json" })
        if r.code <> 200 then return errorResult("V1", r)
        jwt = vpStr(vpGet(ParseJson(r.body), "jwt"))
        if jwt = "" then return errorResult("V1J", r)
        auth = "jwt " + jwt
    end if

    api = "https://api.vimeo.com/live_events/" + cfg.eventId
    ' Vimeo spells this query parameter with four R's.
    referrerParam = "&referrer=" + CreateObject("roUrlTransfer").Escape(cfg.embedPage)

    ' 2. The event: who can watch it, and which clip is live.
    eventFields = "title,uri,stream_privacy.view,stream_privacy.embed"
    eventFields = eventFields + ",clip_to_play.uri,clip_to_play.config_url,clip_to_play.live.status"
    eventFields = eventFields + ",streamable_clip.uri,streamable_clip.config_url,streamable_clip.live.status"
    r = httpGet(api + "?fields=" + eventFields + "&clip_to_play_id=0" + referrerParam, {
        "Accept": "application/vnd.vimeo.*+json;version=3.4.9"
        "Authorization": auth
        "Referer": cfg.embedPage
    })
    event = invalid
    if r.code = 200 then event = ParseJson(r.body)
    if type(event) <> "roAssociativeArray" then return errorResult("V2", r)

    view = vpStr(vpGet(event, "stream_privacy.view"))
    if view = "nobody" then return { status: "error", code: "V2-PRIVATE" }

    clip = vpFindLiveClip(event)
    streamingSeen = clip.streaming
    configUrl = ""
    if not wantReplay then configUrl = clip.configUrl

    ' 3. Public events: look through the event's videos.
    if configUrl = "" and view <> "embed_only"
        r = httpGet(api + "/videos?fields=uri,config_url,created_time,live.status&page=1" + referrerParam, {
            "Accept": "application/vnd.vimeo.*;version=3.4.1"
            "Authorization": auth
            "Referer": cfg.embedPage
        })
        if r.code = 200
            configUrl = vpFindVideo(ParseJson(r.body), wantReplay)
            if configUrl <> "" and not wantReplay then streamingSeen = true
        else if wantReplay or not clip.known
            ' If step 2 already said nothing is live, a failure here doesn't matter.
            return errorResult("V3", r)
        end if
    end if

    if wantReplay and configUrl = "" and vpStr(vpGet(event, "clip_to_play.live.status")) = "done"
        configUrl = vpStr(vpGet(event, "clip_to_play.config_url"))
    end if

    ' 4. Embed-only events: the embed page carries the config link.
    if configUrl = "" and view = "embed_only" and (wantReplay or clip.streaming or not clip.known)
        r = httpGet("https://vimeo.com/event/" + cfg.eventId + "/embed", {
            "Accept": "text/html,application/xhtml+xml"
            "Referer": cfg.embedPage
        })
        if r.code <> 200 then return errorResult("V4", r)
        configUrl = vpConfigUrlFromHtml(r.body)
    end if

    if configUrl = ""
        if wantReplay then return { status: "error", code: "R-NONE" }
        if streamingSeen then return { status: "error", code: "V4-NOCONFIG" }
        return { status: "offline" }
    end if

    ' 5. The player config holds the actual video link.
    r = httpGet(configUrl, { "Accept": "application/json" })
    config = invalid
    if r.code = 200 then config = ParseJson(r.body)
    if type(config) <> "roAssociativeArray" then return errorResult("V5", r)
    stream = vpPickStream(config)

    if wantReplay
        if stream.url = "" then return { status: "error", code: "R-NOHLS" }
        return { status: "replay", url: stream.url, title: stream.title }
    end if

    isLive = (stream.liveStatus = "started") or (stream.liveStatus = "" and streamingSeen)
    if not isLive then return { status: "offline" }
    if stream.url = "" then return { status: "error", code: "V5-NOHLS" }
    return { status: "live", url: stream.url, title: stream.title }
end function

' Builds an error result like { code: "V2-403-3200" }: step, HTTP status, Vimeo error code.
function errorResult(stepCode as String, r as Object) as Object
    code = stepCode + "-" + r.code.ToStr()
    vimeoCode = ""
    if Left(r.body, 1) = "{" then vimeoCode = vpToText(vpGet(ParseJson(r.body), "error_code"))
    if vimeoCode <> "" then code = code + "-" + vimeoCode
    print "[VimeoLiveTask] "; code; " "; r.reason; " "; Left(r.body, 300)
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
