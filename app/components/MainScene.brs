' The home screen has two parts:
'   - the live card (focused at start): says whether the service is live; OK plays it
'   - the sermon archive row underneath: past services; OK plays one
' The live service starts by itself when it begins (AppConfig autoPlayLive),
' unless she pressed Back to leave it. Back during any video returns home.
'
' m.mode: "home" | "live" (watching live) | "archive" (watching a past service)
'         | "loading" (fetching a video link)

sub init()
    m.cfg = AppConfig()

    m.home = m.top.findNode("home")
    m.clock = m.top.findNode("clock")
    m.statusCode = m.top.findNode("statusCode")
    m.heroRing = m.top.findNode("heroRing")
    m.pillBg = m.top.findNode("pillBg")
    m.pillDot = m.top.findNode("pillDot")
    m.pillText = m.top.findNode("pillText")
    m.heroHeadline = m.top.findNode("heroHeadline")
    m.heroBody = m.top.findNode("heroBody")
    m.heroHint = m.top.findNode("heroHint")
    m.archiveMessage = m.top.findNode("archiveMessage")
    m.archiveRow = m.top.findNode("archiveRow")
    m.video = m.top.findNode("video")
    m.liveBadge = m.top.findNode("liveBadge")
    m.loading = m.top.findNode("loading")
    m.loadingTitle = m.top.findNode("loadingTitle")
    m.loadingDetail = m.top.findNode("loadingDetail")

    ' Size the "LIVE NOW" badge and put the title next to it.
    badgeText = m.top.findNode("badgeText")
    badgeWidth = 50 + badgeText.boundingRect().width + 22
    m.top.findNode("badgeBg").width = badgeWidth
    badgeTitle = m.top.findNode("badgeTitle")
    badgeTitle.text = m.cfg.liveTitle
    badgeTitle.translation = [96 + badgeWidth + 28, 49]

    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimer.duration = m.cfg.pollSeconds
    m.pollTimer.observeField("fire", "onPoll")
    m.pollTimer.control = "start"
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    m.badgeTimer = m.top.findNode("badgeTimer")
    m.badgeTimer.observeField("fire", "onBadgeTimer")
    m.video.observeField("state", "onVideoState")
    m.archiveRow.observeField("rowItemSelected", "onArchiveSelected")

    m.mode = "home"
    m.focusArea = "hero"
    m.heroState = ""
    m.isLive = false
    m.liveUrl = ""
    m.liveDismissed = false   ' she pressed Back during this live service
    m.reconnecting = false
    m.failures = 0            ' failed live checks in a row
    m.offlineStrikes = 0      ' "not live" answers in a row while watching
    m.bufferingStrikes = 0    ' checks in a row that found the live video stuck loading
    m.playErrors = 0
    m.archiveCount = 0
    m.archiveLoadedAt = 0
    m.liveTask = invalid
    m.archiveTask = invalid
    m.playTask = invalid

    updateClock()
    setHero("checking")
    focusHero()
    m.top.signalBeacon("AppLaunchComplete")
    checkLive()
    loadArchive()
end sub

' ---------- Asking Vimeo ----------

function startTask(fields as Object, callback as String) as Object
    task = CreateObject("roSGNode", "VimeoTask")
    task.setFields(fields)
    task.observeField("result", callback)
    task.control = "run"
    return task
end function

sub checkLive()
    if m.liveTask <> invalid then return
    m.liveTask = startTask({ mode: "live" }, "onLiveResult")
end sub

sub loadArchive()
    if m.archiveTask <> invalid then return
    if m.archiveCount = 0 then m.archiveMessage.text = "Loading past services..."
    m.archiveTask = startTask({ mode: "archive" }, "onArchiveResult")
end sub

sub onPoll()
    if m.mode = "live"
        ' Restart a live stream that has been stuck loading for two checks in a row.
        if m.video.state = "buffering"
            m.bufferingStrikes = m.bufferingStrikes + 1
        else
            m.bufferingStrikes = 0
        end if
        if m.bufferingStrikes >= 2
            m.bufferingStrikes = 0
            reconnectLive()
            return
        end if
    end if
    checkLive()

    ' Refresh the archive now and then, but not while she's browsing it.
    stale = nowSeconds() - m.archiveLoadedAt > m.cfg.archiveRefreshSeconds
    if m.mode = "home" and m.focusArea = "hero" and stale then loadArchive()
end sub

sub onLiveResult()
    result = m.liveTask.result
    m.liveTask = invalid

    if m.reconnecting
        m.reconnecting = false
        hideLoading()
        if result.status = "live"
            m.liveUrl = result.url
            m.isLive = true
            startLive()
            return
        end if
        m.mode = "home"
        showHome()
    end if

    if result.status = "live"
        m.failures = 0
        m.offlineStrikes = 0
        clearError()
        m.liveUrl = result.url
        m.isLive = true
        if m.mode <> "live"
            setHero("live")
            if m.cfg.autoPlayLive and not m.liveDismissed and m.mode <> "loading" then startLive()
        end if
    else if result.status = "offline"
        m.failures = 0
        clearError()
        if m.mode = "live"
            ' Don't cut off a stream that is still playing because of one odd answer.
            m.offlineStrikes = m.offlineStrikes + 1
            if m.video.state <> "playing" or m.offlineStrikes >= 2
                leavePlayback(false)
                serviceEnded()
            end if
        else if m.isLive
            serviceEnded()
        else if m.heroState <> "ended"
            setHero("offline")
        end if
    else
        m.failures = m.failures + 1
        showError(result.code)
        ' A stream that is playing keeps going through a failed check.
        if not m.isLive
            if m.failures >= 2
                setHero("trouble")
            else if m.heroState = "checking"
                setHero("offline")
            end if
        end if
    end if
end sub

sub serviceEnded()
    m.isLive = false
    m.liveDismissed = false
    setHero("ended")
    loadArchive() ' today's recording shows up once Vimeo has processed it
end sub

sub onArchiveResult()
    result = m.archiveTask.result
    m.archiveTask = invalid

    if result.status <> "ok"
        showError(result.code)
        if m.archiveCount = 0 then m.archiveMessage.text = "Past services couldn't be loaded right now. The app will try again later."
        return
    end if

    m.archiveLoadedAt = nowSeconds()
    items = result.items
    if items.Count() = 0
        if m.archiveCount = 0 then m.archiveMessage.text = "No past services yet."
        return
    end if

    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    for each item in items
        node = row.createChild("ContentNode")
        node.title = item.title
        node.description = item.subtitle
        node.HDPosterUrl = item.thumb
        node.addFields({ configUrl: item.configUrl, videoUri: item.uri })
    end for
    m.archiveRow.content = root
    m.archiveCount = items.Count()
    m.archiveRow.visible = true
    m.archiveMessage.visible = false
end sub

' ---------- Playing ----------

sub startLive()
    m.liveDismissed = false
    m.offlineStrikes = 0
    m.bufferingStrikes = 0
    playUrl(m.liveUrl, true, m.cfg.liveTitle)
    m.mode = "live"
    m.top.setFocus(true) ' nothing to pause or rewind during the live service
    m.liveBadge.visible = true
    m.badgeTimer.control = "start"
end sub

' Live video stalled or errored: get a fresh link and start again.
sub reconnectLive()
    m.video.control = "stop"
    m.liveBadge.visible = false
    showLoading("Reconnecting", "Getting the live service back for you.")
    m.mode = "loading"
    m.reconnecting = true
    checkLive()
end sub

sub onArchiveSelected()
    playArchiveItem(m.archiveRow.rowItemSelected[1])
end sub

sub playArchiveItem(index as Integer)
    if m.archiveRow.content = invalid then return
    item = m.archiveRow.content.getChild(0).getChild(index)
    if item = invalid then return
    m.archiveTitle = item.title
    showLoading("Loading", item.title)
    m.mode = "loading"
    m.playTask = startTask({ mode: "play", configUrl: item.configUrl, videoUri: item.videoUri }, "onPlayResult")
end sub

sub onPlayResult()
    result = m.playTask.result
    m.playTask = invalid
    if m.mode <> "loading" or m.reconnecting then return ' she pressed Back, or the live service took over

    hideLoading()
    if result.status = "play"
        playUrl(result.url, false, m.archiveTitle)
        m.mode = "archive"
        m.video.setFocus(true) ' lets her pause and rewind
    else
        showError(result.code)
        m.mode = "home"
        showHome()
    end if
end sub

sub playUrl(url as String, isLive as Boolean, title as String)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = "hls"
    content.live = isLive
    content.title = title
    content.HttpHeaders = ["Referer: https://player.vimeo.com/"]

    m.video.control = "stop"
    m.video.content = content
    m.video.enableTrickPlay = not isLive
    m.home.visible = false
    m.video.visible = true
    m.video.control = "play"
end sub

' Back to the home screen. byUser = she pressed Back.
sub leavePlayback(byUser as Boolean)
    if m.mode = "live" and byUser then m.liveDismissed = true
    m.video.control = "stop"
    m.video.visible = false
    m.liveBadge.visible = false
    hideLoading()
    m.mode = "home"
    showHome()
end sub

sub showHome()
    m.home.visible = true
    if m.focusArea = "archive" and m.archiveCount > 0
        focusArchive()
    else
        focusHero()
    end if
end sub

sub onVideoState()
    if m.mode <> "live" and m.mode <> "archive" then return
    state = m.video.state
    if state = "playing"
        m.playErrors = 0
    else if state = "error"
        print "[MainScene] video error "; m.video.errorCode; " "; m.video.errorMsg
        showError("P" + m.video.errorCode.ToStr())
        if m.mode = "live" and m.playErrors < 2
            m.playErrors = m.playErrors + 1
            reconnectLive() ' Vimeo's links expire; a fresh one usually fixes it
        else
            wasLive = (m.mode = "live")
            leavePlayback(false)
            if wasLive then setHero("trouble")
        end if
    else if state = "finished"
        wasLive = (m.mode = "live")
        leavePlayback(false)
        if wasLive then serviceEnded()
    end if
end sub

sub onBadgeTimer()
    m.liveBadge.visible = false
end sub

' ---------- Remote ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.mode = "live" or m.mode = "archive"
        if key = "back" then leavePlayback(true)
        return true
    end if

    if m.mode = "loading"
        if key = "back"
            if m.reconnecting then m.liveDismissed = true
            m.reconnecting = false
            leavePlayback(true)
        end if
        return true
    end if

    if m.focusArea = "hero"
        if key = "OK" or key = "play"
            if m.isLive and m.liveUrl <> ""
                startLive()
            else
                setHero("checking")
                checkLive()
            end if
        else if key = "down"
            focusArchive()
        else if key = "back"
            return false ' leave the app, like any other channel
        end if
        return true
    end if

    ' Archive row (it handles left, right and OK itself).
    if key = "up" or key = "back"
        focusHero()
    else if key = "play"
        playArchiveItem(m.archiveRow.rowItemFocused[1])
    end if
    return true
end function

sub focusHero()
    m.focusArea = "hero"
    m.heroRing.visible = true
    m.top.setFocus(true)
end sub

sub focusArchive()
    if m.archiveCount = 0 then return
    m.focusArea = "archive"
    m.heroRing.visible = false
    m.archiveRow.setFocus(true)
end sub

' ---------- Live card ----------

sub setHero(state as String)
    m.heroState = state
    checkHint = "PRESS OK TO CHECK NOW"
    if m.cfg.serviceTimes <> "" then checkHint = UCase(m.cfg.serviceTimes) + "  ·  " + checkHint

    if state = "live"
        setPill("LIVE NOW", "0x9C2D40FF", true)
        m.heroHeadline.text = "The service is live"
        m.heroBody.text = "We're glad you're here. Come worship with us."
        m.heroHint.text = "PRESS OK TO WATCH"
    else if state = "ended"
        setPill("NOT LIVE", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Thanks for watching"
        m.heroBody.text = "The service has ended. The next one will play here by itself when it starts."
        m.heroHint.text = checkHint
    else if state = "trouble"
        setPill("OFFLINE", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Having trouble connecting"
        m.heroBody.text = "It will keep trying by itself. If it doesn't start, ask for help and mention the code at the top right."
        m.heroHint.text = "PRESS OK TO TRY AGAIN NOW"
    else if state = "checking"
        setPill("CHECKING", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Looking for the service"
        m.heroBody.text = "This only takes a moment."
        m.heroHint.text = ""
    else
        setPill("NOT LIVE", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Not live right now"
        m.heroBody.text = "Leave this on. When the service starts, it will play here by itself."
        m.heroHint.text = checkHint
    end if
end sub

sub setPill(text as String, color as String, showDot as Boolean)
    m.pillText.text = text
    m.pillBg.color = color
    m.pillDot.visible = showDot
    left = 22
    if showDot then left = 50
    m.pillText.translation = [left, 0]
    m.pillBg.width = left + m.pillText.boundingRect().width + 22
end sub

' ---------- Small helpers ----------

sub showLoading(title as String, detail as String)
    m.loadingTitle.text = title
    m.loadingDetail.text = detail
    m.loading.visible = true
end sub

sub hideLoading()
    m.loading.visible = false
end sub

sub showError(code as String)
    m.statusCode.text = "Code " + code
end sub

sub clearError()
    m.statusCode.text = ""
end sub

sub updateClock()
    m.clock.text = clockTime()
end sub

function nowSeconds() as Integer
    return CreateObject("roDateTime").AsSeconds()
end function

function clockTime() as String
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    suffix = "AM"
    if hour >= 12 then suffix = "PM"
    hour = hour MOD 12
    if hour = 0 then hour = 12
    minutes = now.GetMinutes()
    pad = ""
    if minutes < 10 then pad = "0"
    return hour.ToStr() + ":" + pad + minutes.ToStr() + " " + suffix
end function
