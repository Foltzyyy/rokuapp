' The app's one screen.
'
' Home: the live card (focused at start), then "Continue watching" (services she
' started) and the "Sermon archive" (past services). Moving down to the rows slides
' the live card up out of the way. While the service is live it plays inside the
' live card; OK makes it full screen, and Back shrinks it back into the card.
'
' Playing: the app's own controls (PlayerOverlay). OK or Play pauses and resumes.
' Left/Right (or Rewind/Fast-forward) skip 10 s back / 30 s ahead per tap; holding
' one slides the playhead along the timeline, faster the longer it's held. The video
' only jumps once she stops pressing, so several taps cost one load, not several.
' Back goes home.
'
' Remembered on the Roku (Progress.brs): where she stopped in each past service, and
' how far she got in a live service she left early (that one shows up under
' Continue watching once Vimeo posts the recording).
'
' The live service goes full screen by itself when it begins (AppConfig
' autoPlayLive), even from a past service, unless she pressed Back to leave it.
'
' Focus: each area has its own node that takes remote focus: the live card group,
' the two rows, the dialog, and "keys" during playback and loading. Never focus the
' Scene itself: on a Roku that doesn't take focus away from a row, which then keeps
' receiving OK, Left and Right.
'
' m.mode:       "home" | "live" | "archive" (watching a past service)
'               | "loading" (getting a video link) | "dialog" (resume or start over?)
' m.focusArea:  "hero" | "continue" | "archive"
' m.previewing: the live service is playing inside the live card (m.mode = "home")

sub init()
    m.cfg = AppConfig()
    progressInit()

    m.home = m.top.findNode("home")
    m.scroller = m.top.findNode("scroller")
    m.clock = m.top.findNode("clock")
    m.statusCode = m.top.findNode("statusCode")
    m.hero = m.top.findNode("hero")
    m.heroRing = m.top.findNode("heroRing")
    m.heroMark = m.top.findNode("heroMark")
    m.previewBg = m.top.findNode("previewBg")
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
    m.keys = m.top.findNode("keys")
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
    m.scrubTimer = m.top.findNode("scrubTimer")
    m.scrubTimer.observeField("fire", "onScrubTick")

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
    m.liveUri = ""            ' the live service's video (its recording keeps this)
    m.liveStart = 0           ' when the live service began, from Vimeo (Unix seconds)
    m.liveSeenAt = 0          ' when this app first saw it live (fallback for liveStart)
    m.liveDismissed = false   ' she pressed Back during this live service
    m.previewing = false
    m.reconnecting = false
    m.failures = 0            ' failed live checks in a row
    m.offlineStrikes = 0      ' "not live" answers in a row while watching
    m.bufferingStrikes = 0    ' checks in a row that found the live video stuck loading
    m.playErrors = 0
    m.endedAt = 0
    m.archiveItems = []
    m.byUri = {}
    m.archiveCount = 0
    m.continueCount = 0
    m.archiveIndex = 0
    m.archiveLoadedAt = 0
    m.rowsScroll = 0
    m.scrollTarget = 0
    m.current = invalid       ' what's playing: { uri, title, subtitle, duration, isLive, startAt, finished }
    m.paused = false
    m.hasPlayed = false
    m.lastFlush = 0
    m.scrubbing = false       ' skipping: the playhead is moving, the video hasn't jumped yet
    m.scrubHeld = false       ' Left/Right is held down
    m.scrubDir = 0
    m.scrubPos = 0
    m.holdTicks = 0
    m.idleTicks = 0
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
    ' Restart a live stream that has been stuck loading for two checks in a row.
    if (m.mode = "live" and not m.paused) or m.previewing
        if m.video.state = "buffering"
            m.bufferingStrikes = m.bufferingStrikes + 1
        else
            m.bufferingStrikes = 0
        end if
        if m.bufferingStrikes >= 2
            m.bufferingStrikes = 0
            if m.previewing
                stopPreview(false) ' the check below starts it again with a fresh link
            else
                reconnectLive()
                return
            end if
        end if
    end if

    ' Keep her spot in the live service, in case the app is closed with Home.
    if m.mode = "live" or m.previewing then saveLiveProgress()

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
            noteLive(result)
            startLive()
            return
        end if
        m.video.visible = false
        m.mode = "home"
        if result.status = "offline"
            ' It ended while she was watching.
            m.isLive = false
            serviceEnded(true)
            showHome()
            return
        end if
        showHome()
    end if

    if result.status = "live"
        m.failures = 0
        m.offlineStrikes = 0
        clearError()
        noteLive(result)
        if m.mode <> "live"
            setHero("live")
            canStart = (m.mode = "home" or m.mode = "archive")
            if m.cfg.autoPlayLive and not m.liveDismissed and canStart
                startLive()
            else if m.mode = "home"
                startPreview()
            end if
        end if
    else if result.status = "offline"
        m.failures = 0
        clearError()
        watching = (m.mode = "live" or m.previewing)
        if watching
            ' Don't cut off a stream that is still going because of one odd answer.
            m.offlineStrikes = m.offlineStrikes + 1
            state = m.video.state
            if (state <> "playing" and state <> "paused") or m.offlineStrikes >= 2
                m.isLive = false
                if m.mode = "live" then leavePlayback(false) else stopPreview(false)
                serviceEnded(true)
            end if
        else if m.isLive
            serviceEnded(false)
        else if m.heroState <> "ended" or nowSeconds() - m.endedAt > 7200
            setHero("offline") ' "Thanks for watching" turns back into this after 2 hours
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

' Remembers the details of the live service Vimeo just reported.
sub noteLive(result as Object)
    m.isLive = true
    m.liveUrl = result.url
    uri = asText(result.uri)
    if uri <> "" then m.liveUri = uri
    now = nowSeconds()
    start = asInt(result.startTime)
    if start > now - 6 * 3600 and start <= now + 60 then m.liveStart = start
    if m.liveSeenAt = 0 then m.liveSeenAt = now
end sub

' watching = she was watching when it ended, so she saw it through.
sub serviceEnded(watching as Boolean)
    if watching and m.liveUri <> ""
        progressClear(m.liveUri)
        progressFlush()
    end if
    m.isLive = false
    m.liveDismissed = false
    m.liveUri = ""
    m.liveStart = 0
    m.liveSeenAt = 0
    m.endedAt = nowSeconds()
    setHero("ended")
    loadArchive() ' today's recording shows up once Vimeo has processed it
end sub

' Saves how far into the live service she is, so if she leaves early the recording
' shows up under Continue watching at about that spot.
sub saveLiveProgress()
    if m.liveUri = "" or not m.isLive then return
    start = m.liveStart
    if start = 0 then start = m.liveSeenAt
    if start = 0 then return
    position = nowSeconds() - start
    if position < progressMinSeconds() then return
    progressSet(m.liveUri, position, 0)
    progressFlush()
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
    m.hero.setFocus(true)
    scrollTo(0)
    startPreview()
end sub

sub focusContinue()
    if m.continueCount = 0 then return
    stopPreview(true)
    m.focusArea = "continue"
    m.heroRing.visible = false
    m.continueRow.setFocus(true)
    scrollTo(m.rowsScroll)
end sub

sub focusArchive()
    if m.archiveCount = 0 then return
    stopPreview(true)
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

' ---------- Live service in the live card ----------

function liveItem() as Object
    return { uri: m.liveUri, title: m.cfg.liveTitle, subtitle: fmtToday(), duration: 0, isLive: true, startAt: 0, finished: false }
end function

' Plays the live service inside the live card (with sound) while the card is focused.
sub startPreview()
    if m.previewing or not m.isLive or m.liveUrl = "" then return
    if m.mode <> "home" or m.focusArea <> "hero" then return
    m.current = liveItem()
    m.previewing = true
    m.bufferingStrikes = 0
    m.offlineStrikes = 0
    setVideoFullScreen(false)
    m.previewBg.visible = true
    m.heroMark.visible = false
    loadVideo(m.liveUrl)
    setSpinner(true, 1420, 328)
end sub

' saveSpot: she's moving away while it's still live, so remember how far she got.
sub stopPreview(saveSpot as Boolean)
    if not m.previewing then return
    if saveSpot then saveLiveProgress()
    m.previewing = false
    m.video.control = "stop"
    m.video.visible = false
    m.previewBg.visible = false
    m.heroMark.visible = true
    setSpinner(false, 912, 492)
end sub

sub setVideoFullScreen(full as Boolean)
    if full
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
    else
        ' The right-hand side of the live card.
        m.video.translation = [1113, 176]
        m.video.width = 711
        m.video.height = 400
    end if
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
    stopPreview(true)
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
    m.mode = "live"
    if m.previewing
        ' Already playing in the live card: just make it big.
        m.previewing = false
        m.previewBg.visible = false
        m.heroMark.visible = true
        enterFullScreen()
        setSpinner(not m.hasPlayed, 912, 492)
    else
        m.current = liveItem()
        playUrl(m.liveUrl)
    end if
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

' Starts m.current from the beginning (or its startAt), full screen.
sub playUrl(url as String)
    setVideoFullScreen(true)
    loadVideo(url)
    enterFullScreen()
    setSpinner(true, 912, 492)
end sub

sub loadVideo(url as String)
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
    m.video.visible = true
    m.video.control = "play"
    m.paused = false
    m.hasPlayed = false
end sub

' Switches to the player screen: video full screen, controls showing.
sub enterFullScreen()
    item = m.current
    setVideoFullScreen(true)
    m.home.visible = false
    m.keys.setFocus(true) ' every button now comes to this screen
    m.lastFlush = nowSeconds()
    m.overlay.title = item.title
    m.overlay.subtitle = item.subtitle
    m.overlay.isLive = item.isLive
    m.overlay.paused = m.paused
    m.overlay.scrubbing = false
    m.overlay.duration = item.duration
    m.overlay.position = item.startAt
    showOverlay()
end sub

' Back to the home screen. byUser = she pressed Back.
sub leavePlayback(byUser as Boolean)
    wasLive = (m.mode = "live")
    stopScrub()
    if m.mode = "archive" then saveProgress()
    if wasLive and byUser then m.liveDismissed = true
    hideOverlay()
    hideLoading()
    m.mode = "home"

    if wasLive and byUser and m.isLive and m.focusArea = "hero"
        ' Shrink the live service back into the live card; it keeps playing.
        setVideoFullScreen(false)
        if m.paused then m.video.control = "resume"
        m.previewing = true
        m.previewBg.visible = true
        m.heroMark.visible = false
    else
        if wasLive and m.isLive then saveLiveProgress()
        m.video.control = "stop"
        m.video.visible = false
    end if
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
        progressSet(item.uri, m.video.position, playDuration())
    else
        return ' never got going; keep the old resume point
    end if
    progressFlush()
    m.lastFlush = nowSeconds()
end sub

function playDuration() as Float
    duration = m.video.duration
    if duration <= 0 and m.current <> invalid then duration = m.current.duration
    return duration
end function

sub onVideoState()
    state = m.video.state

    if m.previewing
        if state = "playing"
            m.hasPlayed = true
            setSpinner(false, 1420, 328)
        else if state = "buffering"
            setSpinner(true, 1420, 328)
        else if state = "error"
            print "[MainScene] preview error "; m.video.errorCode; " "; m.video.errorMsg
            showError("P" + m.video.errorCode.ToStr())
            stopPreview(false) ' the next live check tries again
        else if state = "finished"
            m.isLive = false
            stopPreview(false)
            serviceEnded(true)
        end if
        return
    end if

    if m.mode <> "live" and m.mode <> "archive" then return
    if state = "playing"
        m.playErrors = 0
        m.hasPlayed = true
        setSpinner(false, 912, 492)
        if m.paused
            m.paused = false
            m.overlay.paused = false
        end if
    else if state = "buffering"
        setSpinner(true, 912, 492)
    else if state = "paused"
        setSpinner(false, 912, 492)
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
        if m.mode = "live"
            m.isLive = false
            leavePlayback(false)
            serviceEnded(true)
        else
            m.current.finished = true
            leavePlayback(false)
        end if
    end if
end sub

sub onVideoPosition()
    if m.mode <> "live" and m.mode <> "archive" then return
    if not m.scrubbing then m.overlay.position = m.video.position
    ' Save now and then, so a power cut loses at most a minute.
    if m.mode = "archive" and m.hasPlayed and nowSeconds() - m.lastFlush >= 60 then saveProgress()
end sub

sub onVideoDuration()
    if m.video.duration > 0 then m.overlay.duration = m.video.duration
end sub

' ---------- Skipping ----------
' Each tap moves the playhead on screen right away (10 s back, 30 s ahead). Holding
' keeps it moving, faster the longer it's held. The video jumps once she has stopped
' pressing for about half a second, so a run of taps or a long hold is one load.
' Roku sends a "press" when a button goes down and a "release" when it comes up;
' scrubTimer (every 0.15 s) does the moving and the waiting.

sub skipPressed(direction as Integer)
    if m.scrubHeld and m.scrubDir = direction then return ' a repeated press while held
    if not m.scrubbing
        m.scrubbing = true
        m.scrubPos = m.video.position
        m.overlay.scrubbing = true
        m.scrubTimer.control = "start"
    end if
    m.scrubHeld = true
    m.scrubDir = direction
    m.holdTicks = 0
    m.idleTicks = 0
    if direction < 0 then moveScrub(-10) else moveScrub(30)
    showOverlay()
end sub

sub skipReleased()
    m.scrubHeld = false
    m.idleTicks = 0
end sub

sub onScrubTick()
    if not m.scrubbing then return
    if m.scrubHeld
        m.holdTicks = m.holdTicks + 1
        if m.holdTicks > 600 then skipReleased() ' never heard the button come up
        if m.holdTicks < 4 then return ' not held long enough yet to count as holding
        stepSize = 10
        if m.holdTicks > 16 then stepSize = 30
        if m.holdTicks > 36 then stepSize = 60
        moveScrub(m.scrubDir * stepSize)
        showOverlay()
    else
        m.idleTicks = m.idleTicks + 1
        if m.idleTicks >= 4 then commitScrub()
    end if
end sub

sub moveScrub(seconds as Integer)
    duration = playDuration()
    target = m.scrubPos + seconds
    if duration > 0 and target > duration - 5 then target = duration - 5
    if target < 0 then target = 0
    m.scrubPos = target
    m.overlay.position = target
end sub

' Jumps the video to where the playhead was moved.
sub commitScrub()
    if not m.scrubbing then return
    stopScrub()
    m.video.seek = m.scrubPos
    m.overlay.position = m.scrubPos
    showOverlay()
end sub

sub stopScrub()
    m.scrubTimer.control = "stop"
    m.scrubbing = false
    m.scrubHeld = false
    m.overlay.scrubbing = false
end sub

' ---------- Remote ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if m.mode = "live" or m.mode = "archive"
        if press then return onPlayerKey(key)
        if isSkipKey(key) then skipReleased()
        return true
    end if
    if not press then return false

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
            if m.previewing then saveLiveProgress()
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

function isSkipKey(key as String) as Boolean
    return key = "left" or key = "right" or key = "rewind" or key = "fastforward" or key = "replay"
end function

function onPlayerKey(key as String) as Boolean
    isArchive = (m.mode = "archive")
    if key = "back"
        leavePlayback(true)
    else if key = "OK" or key = "play"
        if m.scrubbing then commitScrub() else togglePause()
    else if isArchive and (key = "left" or key = "rewind" or key = "replay")
        skipPressed(-1)
    else if isArchive and (key = "right" or key = "fastforward")
        skipPressed(1)
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

' The controls show on any button and fade after 5 seconds (they stay while paused
' or skipping).
sub showOverlay()
    m.overlay.visible = true
    m.overlayTimer.control = "stop"
    m.overlayTimer.control = "start"
end sub

sub onOverlayTimer()
    if not m.paused and not m.scrubbing then m.overlay.visible = false
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
        m.heroHint.text = "PRESS OK TO WATCH FULL SCREEN"
    else if state = "ended"
        setPill("NOT LIVE", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Thanks for watching"
        m.heroBody.text = "The service has ended. The next one will play here by itself when it starts."
        m.heroHint.text = checkHint
    else if state = "trouble"
        setPill("OFFLINE", "0x4E4F4DFF", false)
        m.heroHeadline.text = "Having trouble connecting"
        m.heroBody.text = "It keeps trying by itself. If it doesn't start, mention the code at the top right."
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
    m.keys.setFocus(true) ' so a row behind this doesn't get OK presses
    setSpinner(true, 912, 790)
end sub

sub hideLoading()
    m.loading.visible = false
    setSpinner(false, 912, 492)
end sub

sub setSpinner(visible as Boolean, x as Integer, y as Integer)
    m.spinner.translation = [x, y]
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
