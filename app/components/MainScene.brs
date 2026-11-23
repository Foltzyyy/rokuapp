' What the viewer sees:
'   idle   - "not live right now" screen; checks Vimeo every pollSeconds
'   live   - the live service, full screen; re-checks every liveCheckSeconds
'   replay - the most recent recording (press PLAY on the idle screen)
' The live service always takes over, even from a replay.

sub init()
    m.cfg = AppConfig()
    m.video = m.top.findNode("video")
    m.headline = m.top.findNode("headline")
    m.detail = m.top.findNode("detail")
    m.footer = m.top.findNode("footer")
    m.status = m.top.findNode("status")
    m.top.findNode("churchName").text = m.cfg.churchName
    m.top.findNode("subtitle").text = m.cfg.subtitle

    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimer.duration = m.cfg.pollSeconds
    m.pollTimer.observeField("fire", "onPollTimer")
    m.liveCheckTimer = m.top.findNode("liveCheckTimer")
    m.liveCheckTimer.duration = m.cfg.liveCheckSeconds
    m.liveCheckTimer.observeField("fire", "onLiveCheckTimer")
    m.video.observeField("state", "onVideoState")

    m.mode = "idle"
    m.liveTask = invalid
    m.replayTask = invalid
    m.failures = 0          ' failed checks in a row
    m.playErrors = 0        ' playback errors in a row
    m.offlineStrikes = 0    ' "not live" answers in a row while watching
    m.bufferingStrikes = 0  ' live checks in a row that found the video stuck buffering
    m.lastError = ""
    m.lastChecked = ""

    showScreen("Looking for the service...", "", "")
    m.top.setFocus(true)
    m.top.signalBeacon("AppLaunchComplete")
    checkLive()
end sub

' ---------- Asking Vimeo ----------

sub checkLive()
    if m.liveTask <> invalid then return
    m.liveTask = startTask("live", "onLiveResult")
end sub

sub loadReplay()
    if m.replayTask <> invalid then return
    showScreen("Loading the most recent service...", "", "")
    m.replayTask = startTask("replay", "onReplayResult")
end sub

function startTask(mode as String, callback as String) as Object
    task = CreateObject("roSGNode", "VimeoLiveTask")
    task.mode = mode
    task.observeField("result", callback)
    task.control = "run"
    return task
end function

sub onLiveResult()
    result = m.liveTask.result
    m.liveTask = invalid
    m.lastChecked = clockTime()
    ' Leave the screen alone while a replay is loading.
    idleScreen = (m.mode = "idle" and m.replayTask = invalid)

    if result.status = "live"
        m.failures = 0
        m.offlineStrikes = 0
        m.lastError = ""
        if m.mode <> "live" then startPlayback(result.url, true)
    else if result.status = "offline"
        m.failures = 0
        m.lastError = ""
        if m.mode = "live"
            ' Don't cut off a stream that is still playing because of one odd answer.
            m.offlineStrikes = m.offlineStrikes + 1
            if m.video.state <> "playing" or m.offlineStrikes >= 2
                stopPlayback()
                showEnded()
            end if
        else if idleScreen
            showOffline()
        end if
    else
        m.failures = m.failures + 1
        m.lastError = result.code
        ' A stream that is already playing keeps going through a failed check.
        if idleScreen
            if m.failures >= 2 then showTrouble() else showOffline()
        end if
    end if

    updateStatus()
    if m.mode <> "live" then schedulePoll()
end sub

sub onReplayResult()
    result = m.replayTask.result
    m.replayTask = invalid
    if m.mode <> "idle" then return ' the live service started meanwhile

    if result.status = "replay"
        startPlayback(result.url, false)
    else
        m.lastError = result.code
        showScreen("Sorry, the last service couldn't be loaded.", "When the live service starts, it will play here by itself.", "Press OK to check now.")
        updateStatus()
    end if
end sub

sub onPollTimer()
    checkLive()
end sub

sub onLiveCheckTimer()
    if m.mode <> "live" then return
    ' Restart a live stream that has been stuck loading for two checks in a row.
    if m.video.state = "buffering"
        m.bufferingStrikes = m.bufferingStrikes + 1
    else
        m.bufferingStrikes = 0
    end if
    if m.bufferingStrikes >= 2
        m.bufferingStrikes = 0
        stopPlayback()
        showScreen("Reconnecting to the service...", "", "")
    end if
    checkLive()
end sub

sub schedulePoll()
    m.pollTimer.control = "stop"
    m.pollTimer.control = "start"
end sub

' ---------- Playing ----------

sub startPlayback(url as String, isLive as Boolean)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = "hls"
    content.live = isLive
    content.title = m.cfg.churchName
    content.HttpHeaders = ["Referer: https://player.vimeo.com/"]

    m.video.control = "stop"
    m.video.content = content
    m.video.enableTrickPlay = not isLive
    m.video.visible = true
    m.video.control = "play"

    if isLive
        m.mode = "live"
        m.offlineStrikes = 0
        m.bufferingStrikes = 0
        m.pollTimer.control = "stop"
        m.liveCheckTimer.control = "start"
        m.top.setFocus(true) ' nothing to pause or rewind during the live service
    else
        m.mode = "replay"
        m.video.setFocus(true) ' lets her pause and rewind a recording
    end if
end sub

sub stopPlayback()
    m.video.control = "stop"
    m.video.visible = false
    m.liveCheckTimer.control = "stop"
    m.mode = "idle"
    m.top.setFocus(true)
end sub

sub onVideoState()
    state = m.video.state
    if m.mode = "idle" then return ' leftover events from a stream we already stopped

    if state = "playing"
        m.playErrors = 0
    else if state = "error"
        print "[MainScene] video error "; m.video.errorCode; " "; m.video.errorMsg
        m.lastError = "P" + m.video.errorCode.ToStr()
        wasLive = (m.mode = "live")
        stopPlayback()
        m.playErrors = m.playErrors + 1
        if wasLive and m.playErrors < 3
            ' Vimeo's links expire. Get a fresh one and try again right away.
            showScreen("Reconnecting to the service...", "", "")
            checkLive()
        else
            showTrouble()
            schedulePoll()
        end if
        updateStatus()
    else if state = "finished"
        wasLive = (m.mode = "live")
        stopPlayback()
        if wasLive then showEnded() else showOffline()
        schedulePoll()
    end if
end sub

' ---------- Remote ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        if m.mode = "replay"
            stopPlayback()
            showOffline()
            updateStatus()
            return true
        end if
        return false ' leave the app, like any other channel
    end if

    if m.mode = "idle"
        if key = "OK"
            showScreen("Checking for the service...", "", "")
            checkLive()
        else if key = "play"
            loadReplay()
        end if
    end if
    ' Swallow every other button so nothing unexpected happens.
    return true
end function

' ---------- Screens ----------

sub showScreen(headline as String, detail as String, footer as String)
    m.headline.text = headline
    m.detail.text = detail
    m.footer.text = footer
end sub

sub showOffline()
    showScreen("The service isn't live right now.", "Leave this on. When the service starts, it will play here by itself.", "Press OK to check now.      Press PLAY to watch the last service.")
end sub

sub showEnded()
    showScreen("The service has ended.", "Thanks for watching! The next service will play here by itself when it starts.", "Press PLAY to watch the last service.")
end sub

sub showTrouble()
    showScreen("Having trouble reaching the service.", "It will keep trying by itself. If it doesn't start, ask for help and mention the code at the bottom.", "Press OK to try again now.")
end sub

sub updateStatus()
    text = ""
    if m.lastChecked <> "" then text = "Last checked " + m.lastChecked
    if m.lastError <> "" then text = text + "      Code " + m.lastError
    m.status.text = text
end sub

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
