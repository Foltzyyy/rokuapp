' The app's one screen.
'
' Home: the live card (focused at start), then "Continue watching" (services she
' started) and the "Sermon archive" (past services). Moving down to the rows slides
' the live card up out of the way.
'
' Playing: the app's own controls (PlayerOverlay). OK or Play pauses and resumes,
' Left/Rewind skips back 10 seconds, Right/Fast-forward skips ahead 30, Back goes
' home. Where she stopped in each past service is remembered (Progress.brs).
'
' The live service starts by itself when it begins (AppConfig autoPlayLive), even
' from a past service, unless she pressed Back to leave it.
'
' m.mode:      "home" | "live" | "archive" (watching a past service)
'              | "loading" (getting a video link) | "dialog" (resume or start over?)
' m.focusArea: "hero" | "continue" | "archive"

sub init()
    m.cfg = AppConfig()
    progressInit()

    m.home = m.top.findNode("home")
    m.scroller = m.top.findNode("scroller")
    m.clock = m.top.findNode("clock")
    m.statusCode = m.top.findNode("statusCode")
    m.heroRing = m.top.findNode("heroRing")
    m.pillBg = m.top.findNode("pillBg")
    m.pillDot = m.top.findNode("pillDot")
    m.pillText = m.top.findNode("pillText")
    m.heroHeadline = m.top.findNode("heroHeadline")
    m.heroBody = m.top.findNode("heroBody")
    m.heroHint = m.top.findNode("heroHint")
    m.continueSection = m.top.findNode("continueSection")
    m.continueRow = m.top.findNode("continueRow")
    m.archiveSection = m.top.findNode("archiveSection")
    m.archiveMessage = m.top.findNode("archiveMessage")
    m.archiveRow = m.top.findNode("archiveRow")
    m.video = m.top.findNode("video")
    m.overlay = m.top.findNode("overlay")
    m.loading = m.top.findNode("loading")
    m.loadingTitle = m.top.findNode("loadingTitle")
    m.loadingDetail = m.top.findNode("loadingDetail")
    m.spinner = m.top.findNode("spinner")
    m.spinAnim = m.top.findNode("spinAnim")
    m.scrollAnim = m.top.findNode("scrollAnim")
    m.scrollInterp = m.top.findNode("scrollInterp")
    m.dialog = m.top.findNode("dialog")

    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimer.duration = m.cfg.pollSeconds
    m.pollTimer.observeField("fire", "onPoll")
    m.pollTimer.control = "start"
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    m.overlayTimer = m.top.findNode("overlayTimer")
    m.overlayTimer.observeField("fire", "onOverlayTimer")

    m.video.observeField("state", "onVideoState")
    m.video.observeField("position", "onVideoPosition")
    m.video.observeField("duration", "onVideoDuration")
    m.continueRow.observeField("rowItemSelected", "onContinueSelected")
    m.archiveRow.observeField("rowItemSelected", "onArchiveSelected")
    m.archiveRow.observeField("rowItemFocused", "onArchiveFocused")
    m.dialog.observeField("choice", "onDialogChoice")

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
    m.archiveItems = []
    m.byUri = {}
    m.archiveCount = 0
    m.continueCount = 0
    m.archiveIndex = 0
    m.archiveLoadedAt = 0
    m.rowsScroll = 0
    m.scrollTarget = 0
    m.current = invalid       ' what's playing: { uri, title, subtitle, duration, isLive, startAt }
    m.paused = false
    m.hasPlayed = false
    m.lastFlush = 0
    m.pendingItem = invalid
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
    if m.mode = "live" and not m.paused
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
            canStart = (m.mode = "home" or m.mode = "archive")
            if m.cfg.autoPlayLive and not m.liveDismissed and canStart then startLive()
        end if
    else if result.status = "offline"
        m.failures = 0
        clearError()
        if m.mode = "live"
            ' Don't cut off a stream that is still going because of one odd answer.
            m.offlineStrikes = m.offlineStrikes + 1
            state = m.video.state
            if (state <> "playing" and state <> "paused") or m.offlineStrikes >= 2
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
    if result.items.Count() = 0
        if m.archiveCount = 0 then m.archiveMessage.text = "No past services yet."
        return
    end if

    m.archiveItems = result.items
    m.byUri = {}
    for each item in m.archiveItems
        m.byUri[item.uri] = item
    end for
    buildRows()
    if m.mode = "home" then restoreFocus()
end sub

' ---------- Home rows ----------

' Fills "Continue watching" and "Sermon archive" from the archive list and the
' saved progress.
sub buildRows()
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    for each item in m.archiveItems
        addTile(row, item, item.subtitle, progressFraction(item.uri, item.duration))
    end for
    m.archiveRow.content = root
    m.archiveCount = m.archiveItems.Count()
    m.archiveRow.visible = m.archiveCount > 0
    m.archiveMessage.visible = m.archiveCount = 0
    if m.archiveIndex >= m.archiveCount then m.archiveIndex = 0
    if m.archiveCount > 0 then m.archiveRow.jumpToRowItem = [0, m.archiveIndex]

    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    m.continueCount = 0
    for each uri in progressContinueUris()
        item = m.byUri[uri]
        if item <> invalid
            length = item.duration
            if length <= 0 then length = m.progress[uri].d
            timeLeft = fmtTimeLeft(length - progressResumePoint(uri, item.duration))
            addTile(row, item, timeLeft, progressFraction(uri, item.duration))
            m.continueCount = m.continueCount + 1
        end if
    end for
    m.continueRow.content = root
    if m.continueCount > 0 then m.continueRow.jumpToRowItem = [0, 0]

    ' With two rows, the live card slides up so both rows fit on screen.
    if m.continueCount > 0
        m.continueSection.visible = true
        m.archiveSection.translation = [96, 1068]
        m.rowsScroll = -426
    else
        m.continueSection.visible = false
        m.archiveSection.translation = [96, 622]
        m.rowsScroll = 0
    end if
    if m.focusArea <> "hero" then scrollTo(m.rowsScroll)
end sub

sub addTile(row as Object, item as Object, subtitle as String, progress as Float)
    node = row.createChild("ContentNode")
    node.title = item.title
    node.description = subtitle
    node.HDPosterUrl = item.thumb
    node.addFields({ videoUri: item.uri, progress: progress })
end sub

sub focusHero()
    m.focusArea = "hero"
    m.heroRing.visible = true
    m.top.setFocus(true)
    scrollTo(0)
end sub

sub focusContinue()
    if m.continueCount = 0 then return
    m.focusArea = "continue"
    m.heroRing.visible = false
    m.continueRow.setFocus(true)
    scrollTo(m.rowsScroll)
end sub

sub focusArchive()
    if m.archiveCount = 0 then return
    m.focusArea = "archive"
    m.heroRing.visible = false
    m.archiveRow.setFocus(true)
    scrollTo(m.rowsScroll)
end sub

' Puts focus back where it was on the home screen, or the nearest thing that exists.
sub restoreFocus()
    if m.focusArea = "continue" and m.continueCount > 0
        focusContinue()
    else if m.focusArea <> "hero" and m.archiveCount > 0
        focusArchive()
    else
        focusHero()
    end if
end sub

sub scrollTo(y as Integer)
    if m.scrollTarget = y then return
    m.scrollTarget = y
    m.scrollInterp.keyValue = [m.scroller.translation, [0, y]]
    m.scrollAnim.control = "start"
end sub

sub showHome()
    m.home.visible = true
    restoreFocus()
end sub

' ---------- Choosing a past service ----------

sub onContinueSelected()
    playContinueIndex(m.continueRow.rowItemSelected[1])
end sub

sub playContinueIndex(index as Integer)
    if m.continueRow.content = invalid then return
    node = m.continueRow.content.getChild(0).getChild(index)
    if node = invalid then return
    item = m.byUri[node.videoUri]
    if item = invalid then return
    playItem(item, progressResumePoint(item.uri, item.duration))
end sub

sub onArchiveSelected()
    chooseArchiveIndex(m.archiveRow.rowItemSelected[1])
end sub

sub onArchiveFocused()
    focused = m.archiveRow.rowItemFocused
    if type(focused) = "roArray" and focused.Count() > 1 then m.archiveIndex = focused[1]
end sub

' Plays a past service, asking first if she's partway through it.
sub chooseArchiveIndex(index as Integer)
    if index < 0 or index >= m.archiveItems.Count() then return
    m.archiveIndex = index
    item = m.archiveItems[index]
    resumeAt = progressResumePoint(item.uri, item.duration)
    if resumeAt > 0
        m.pendingItem = item
        m.dialog.title = item.title
        m.dialog.resumeAt = resumeAt
        m.dialog.visible = true
        m.dialog.setFocus(true)
        m.mode = "dialog"
    else
        playItem(item, 0)
    end if
end sub

sub onDialogChoice()
    choice = m.dialog.choice
    item = m.pendingItem
    m.pendingItem = invalid
    m.dialog.visible = false
    m.mode = "home"
    if item <> invalid and choice = "resume"
        playItem(item, progressResumePoint(item.uri, item.duration))
    else if item <> invalid and choice = "restart"
        progressClear(item.uri)
        progressFlush()
        playItem(item, 0)
    else
        restoreFocus()
    end if
end sub

sub playItem(item as Object, startAt as Integer)
    m.current = { uri: item.uri, title: item.title, subtitle: item.subtitle, duration: item.duration, isLive: false, startAt: startAt, finished: false }
    showLoading("Loading", item.title)
    m.mode = "loading"
    m.playTask = startTask({ mode: "play", configUrl: item.configUrl, videoUri: item.uri }, "onPlayResult")
end sub

sub onPlayResult()
    result = m.playTask.result
    m.playTask = invalid
    if m.mode <> "loading" or m.reconnecting then return ' she pressed Back, or the live service took over

    hideLoading()
    if result.status = "play"
        m.mode = "archive"
        playUrl(result.url)
    else
        showError(result.code)
        m.mode = "home"
        showHome()
    end if
end sub

' ---------- Playing ----------

sub startLive()
    if m.mode = "archive" then saveProgress()
    m.liveDismissed = false
    m.offlineStrikes = 0
    m.bufferingStrikes = 0
    m.current = { uri: "", title: m.cfg.liveTitle, subtitle: fmtToday(), duration: 0, isLive: true, startAt: 0, finished: false }
    m.mode = "live"
    playUrl(m.liveUrl)
end sub

' Live video stalled or errored: get a fresh link and start again.
sub reconnectLive()
    m.video.control = "stop"
    hideOverlay()
    showLoading("Reconnecting", "Getting the live service back for you.")
    m.mode = "loading"
    m.reconnecting = true
    checkLive()
end sub

sub playUrl(url as String)
    item = m.current
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = "hls"
    content.live = item.isLive
    content.title = item.title
    content.HttpHeaders = ["Referer: https://player.vimeo.com/"]
    if item.startAt > 0 then content.PlayStart = item.startAt

    m.video.control = "stop"
    m.video.content = content
    m.home.visible = false
    m.video.visible = true
    m.video.control = "play"
    m.top.setFocus(true) ' this screen handles every button during playback
    m.paused = false
    m.hasPlayed = false
    m.lastFlush = nowSeconds()

    m.overlay.title = item.title
    m.overlay.subtitle = item.subtitle
    m.overlay.isLive = item.isLive
    m.overlay.paused = false
    m.overlay.duration = item.duration
    m.overlay.position = item.startAt
    showOverlay()
    setSpinner(true, 492)
end sub

' Back to the home screen. byUser = she pressed Back.
sub leavePlayback(byUser as Boolean)
    if m.mode = "archive" then saveProgress()
    if m.mode = "live" and byUser then m.liveDismissed = true
    m.video.control = "stop"
    m.video.visible = false
    hideOverlay()
    hideLoading()
    m.mode = "home"
    m.paused = false
    buildRows()
    showHome()
end sub

' Remembers where she is in the past service that's playing, and writes it to the Roku.
sub saveProgress()
    item = m.current
    if item = invalid or item.isLive or item.uri = "" then return
    if item.finished
        progressClear(item.uri)
    else if m.hasPlayed
        duration = m.video.duration
        if duration <= 0 then duration = item.duration
        progressSet(item.uri, m.video.position, duration)
    else
        return ' never got going; keep the old resume point
    end if
    progressFlush()
    m.lastFlush = nowSeconds()
end sub

sub onVideoState()
    if m.mode <> "live" and m.mode <> "archive" then return
    state = m.video.state
    if state = "playing"
        m.playErrors = 0
        m.hasPlayed = true
        setSpinner(false, 492)
        if m.paused
            m.paused = false
            m.overlay.paused = false
        end if
    else if state = "buffering"
        setSpinner(true, 492)
    else if state = "paused"
        setSpinner(false, 492)
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
        if not wasLive then m.current.finished = true
        leavePlayback(false)
        if wasLive then serviceEnded()
    end if
end sub

sub onVideoPosition()
    if m.mode <> "live" and m.mode <> "archive" then return
    m.overlay.position = m.video.position
    ' Save now and then, so a power cut loses at most a minute.
    if m.mode = "archive" and m.hasPlayed and nowSeconds() - m.lastFlush >= 60 then saveProgress()
end sub

sub onVideoDuration()
    if m.video.duration > 0 then m.overlay.duration = m.video.duration
end sub

' ---------- Remote ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.mode = "live" or m.mode = "archive" then return onPlayerKey(key)

    if m.mode = "loading"
        if key = "back"
            if m.reconnecting then m.liveDismissed = true
            m.reconnecting = false
            leavePlayback(true)
        end if
        return true
    end if

    if m.mode = "dialog" then return true ' the dialog handles its own buttons

    if m.focusArea = "hero"
        if key = "OK" or key = "play"
            if m.isLive and m.liveUrl <> ""
                startLive()
            else
                setHero("checking")
                checkLive()
            end if
        else if key = "down"
            if m.continueCount > 0 then focusContinue() else focusArchive()
        else if key = "back"
            progressFlush()
            return false ' leave the app, like any other channel
        end if
        return true
    end if

    ' The rows handle Left, Right and OK themselves.
    if m.focusArea = "continue"
        if key = "up" or key = "back"
            focusHero()
        else if key = "down"
            focusArchive()
        else if key = "play"
            playContinueIndex(m.continueRow.rowItemFocused[1])
        end if
        return true
    end if

    if key = "up"
        if m.continueCount > 0 then focusContinue() else focusHero()
    else if key = "back"
        focusHero()
    else if key = "play"
        chooseArchiveIndex(m.archiveIndex)
    end if
    return true
end function

function onPlayerKey(key as String) as Boolean
    isArchive = (m.mode = "archive")
    if key = "back"
        leavePlayback(true)
    else if key = "OK" or key = "play"
        togglePause()
    else if (key = "left" or key = "rewind" or key = "replay") and isArchive
        seekBy(-10)
    else if (key = "right" or key = "fastforward") and isArchive
        seekBy(30)
    else
        showOverlay()
    end if
    return true
end function

sub togglePause()
    if m.paused
        m.video.control = "resume"
        m.paused = false
    else
        m.video.control = "pause"
        m.paused = true
        if m.mode = "archive" then saveProgress()
    end if
    m.overlay.paused = m.paused
    showOverlay()
end sub

sub seekBy(seconds as Integer)
    duration = m.video.duration
    if duration <= 0 then duration = m.current.duration
    target = m.video.position + seconds
    if duration > 0 and target > duration - 5 then target = duration - 5
    if target < 0 then target = 0
    m.video.seek = target
    m.overlay.position = target
    showOverlay()
end sub

' The controls show on any button and fade after 5 seconds (they stay while paused).
sub showOverlay()
    m.overlay.visible = true
    m.overlayTimer.control = "stop"
    m.overlayTimer.control = "start"
end sub

sub onOverlayTimer()
    if not m.paused then m.overlay.visible = false
end sub

sub hideOverlay()
    m.overlayTimer.control = "stop"
    m.overlay.visible = false
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
    setSpinner(true, 790)
end sub

sub hideLoading()
    m.loading.visible = false
    setSpinner(false, 492)
end sub

sub setSpinner(visible as Boolean, y as Integer)
    m.spinner.translation = [912, y]
    m.spinner.visible = visible
    if visible then m.spinAnim.control = "start" else m.spinAnim.control = "stop"
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
