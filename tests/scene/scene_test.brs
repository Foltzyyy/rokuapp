' Drives the real MainScene code (app/components/MainScene.brs) through the
' situations it has to handle, with fake Vimeo answers and fake video states.
' Run with tests/scene/run.sh. Roku's Task, Video, RowList and Animation nodes are
' replaced by the stand-ins in tests/scene/stubs. (The interpreter has no on-device
' storage, so saved progress lives in memory here.)

sub runTests(args as Dynamic)
    m.tPassed = 0
    m.tFailed = 0

    ' Do field observers fire right away in this interpreter?
    probe = CreateObject("roSGNode", "Node")
    probe.addField("x", "string", false)
    m.probeFired = false
    probe.observeField("x", "onProbe")
    probe.x = "y"

    items = [
        { title: "Hope Week 2", subtitle: "Sunday, November 16", thumb: "https://t/2", configUrl: "https://c/2", uri: "/videos/2", duration: 3600 }
        { title: "Sunday, November 9", subtitle: "1 hr 12 min", thumb: "", configUrl: "https://c/1", uri: "/videos/1", duration: 3000 }
    ]
    hint = m.overlay.findNode("hint")

    ' --- Start-up ---
    expect("starts by checking", m.heroState, "checking")
    expect("live check started", m.liveTask <> invalid, true)
    expect("archive load started", m.archiveTask <> invalid, true)
    expect("live card focused", m.focusArea, "hero")
    expect("archive loading text", m.archiveMessage.text, "Loading past services...")

    ' --- Not live ---
    deliver("live", { status: "offline" })
    expect("offline card", m.heroState, "offline")
    expect("offline headline", m.heroHeadline.text, "Not live right now")

    ' --- Archive arrives ---
    deliver("archive", { status: "ok", items: items })
    expect("archive count", m.archiveCount, 2)
    expect("archive row shown", m.archiveRow.visible, true)
    expect("loading text hidden", m.archiveMessage.visible, false)
    expect("first tile", m.archiveRow.content.getChild(0).getChild(0).title, "Hope Week 2")
    expect("no continue row yet", m.continueSection.visible, false)

    ' --- Moving between the live card and the archive ---
    onKeyEvent("down", true)
    expect("down goes to archive", m.focusArea, "archive")
    expect("one row: no scrolling", m.scrollTarget, 0)
    onKeyEvent("up", true)
    expect("up goes to live card", m.focusArea, "hero")

    ' --- Service goes live: plays by itself, with controls ---
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8" })
    expect("live plays by itself", m.mode, "live")
    expect("live link", m.video.content.url, "https://x/live.m3u8")
    expect("marked live", m.video.content.live, true)
    expect("Roku's own controls off", m.video.enableUI, false)
    expect("controls shown", m.overlay.visible, true)
    expect("controls in live mode", m.overlay.isLive, true)
    expect("live title", m.overlay.title, m.cfg.liveTitle)
    expect("spinner while starting", m.spinner.visible, true)
    setVideoState("playing")
    expect("spinner gone once playing", m.spinner.visible, false)

    ' --- OK pauses and resumes; Left/Right don't skip during live ---
    onKeyEvent("OK", true)
    expect("OK pauses live", m.video.control, "pause")
    expect("paused symbol", m.overlay.paused, true)
    expect("paused hint", hint.text, "OK to play  ·  Back for home")
    onKeyEvent("OK", true)
    expect("OK resumes live", m.video.control, "resume")
    expect("playing hint", hint.text, "OK to pause  ·  Back for home")
    onKeyEvent("right", true)
    expect("no skipping live", m.video.seek, 0)

    ' --- Back leaves live and doesn't restart it ---
    expect("back handled", onKeyEvent("back", true), true)
    expect("back to home", m.mode, "home")
    expect("remembers she left", m.liveDismissed, true)
    expect("controls hidden at home", m.overlay.visible, false)
    expect("card says live", m.heroHeadline.text, "The service is live")
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8" })
    expect("doesn't restart after Back", m.mode, "home")
    onKeyEvent("OK", true)
    expect("OK on the card rejoins", m.mode, "live")
    setVideoState("playing")

    ' --- One odd "offline" answer doesn't cut the stream; two in a row do ---
    checkLive()
    deliver("live", { status: "offline" })
    expect("one offline ignored", m.mode, "live")
    checkLive()
    deliver("live", { status: "offline" })
    expect("two offline -> home", m.mode, "home")
    expect("thanks for watching", m.heroState, "ended")
    deliver("archive", { status: "ok", items: items })

    ' --- Playing a past service with the app's controls ---
    focusArchive()
    selectArchive(1)
    expect("loading screen", m.mode, "loading")
    expect("loading shows title", m.loadingDetail.text, "Sunday, November 9")
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("past service playing", m.mode, "archive")
    expect("archive link", m.video.content.url, "https://x/a.m3u8")
    expect("starts at the beginning", m.video.content.PlayStart, 0)
    expect("controls in recording mode", m.overlay.isLive, false)
    expect("recording title", m.overlay.title, "Sunday, November 9")
    setVideoState("playing")
    m.video.duration = 3000
    m.video.position = 600
    expect("elapsed time", m.overlay.findNode("elapsed").text, "10:00")
    expect("total time", m.overlay.findNode("total").text, "50:00")
    onKeyEvent("right", true)
    expect("Right skips ahead 30", m.video.seek, 630)
    onKeyEvent("left", true)
    expect("Left skips back 10", m.video.seek, 590)
    onKeyEvent("fastforward", true)
    expect("Fast-forward skips ahead", m.video.seek, 630)
    m.video.position = 2990
    onKeyEvent("right", true)
    expect("can't skip past the end", m.video.seek, 2995)
    m.video.position = 5
    onKeyEvent("left", true)
    expect("can't skip before the start", m.video.seek, 0)
    m.video.position = 600

    onKeyEvent("OK", true)
    expect("OK pauses", m.video.control, "pause")
    expect("pausing saves the spot", progressResumePoint("/videos/1", 3000), 600)
    expect("paused hint", hint.text, "OK to play  ·  Left/Right to skip")
    onKeyEvent("play", true)
    expect("Play resumes", m.video.control, "resume")

    ' --- Leaving partway: Continue watching appears ---
    onKeyEvent("back", true)
    expect("back home", m.mode, "home")
    expect("continue row appears", m.continueSection.visible, true)
    expect("continue count", m.continueCount, 1)
    expect("continue tile", m.continueRow.content.getChild(0).getChild(0).title, "Sunday, November 9")
    expect("time left", m.continueRow.content.getChild(0).getChild(0).description, "40 min left")
    expect("archive tile progress", m.archiveRow.content.getChild(0).getChild(1).progress, 0.2)
    expect("archive moves down", m.archiveSection.translation[1], 1068)
    expect("focus back on archive", m.focusArea, "archive")
    expect("rows scrolled into view", m.scrollTarget, -426)
    onKeyEvent("up", true)
    expect("up goes to continue row", m.focusArea, "continue")
    onKeyEvent("up", true)
    expect("then to the live card", m.focusArea, "hero")
    expect("scrolled back up", m.scrollTarget, 0)
    onKeyEvent("down", true)
    expect("down goes to continue row first", m.focusArea, "continue")

    ' --- Continue watching resumes right away ---
    selectContinue(0)
    expect("no question asked", m.dialog.visible, false)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("resumes where she stopped", m.video.content.PlayStart, 600)
    setVideoState("playing")
    m.video.position = 900
    onKeyEvent("back", true)
    expect("new spot saved", progressResumePoint("/videos/1", 3000), 900)
    expect("focus back on continue row", m.focusArea, "continue")

    ' --- From the archive, a started service asks first ---
    focusArchive()
    selectArchive(1)
    expect("asks resume or start over", m.mode, "dialog")
    expect("dialog shown", m.dialog.visible, true)
    expect("resume button", m.dialog.findNode("label0").text, "Resume from 15:00")
    m.dialog.choice = "resume"
    if not m.probeFired then onDialogChoice()
    expect("dialog closed", m.dialog.visible, false)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("resume choice", m.video.content.PlayStart, 900)
    setVideoState("playing")
    onKeyEvent("back", true)

    selectArchive(1)
    m.dialog.choice = "restart"
    if not m.probeFired then onDialogChoice()
    expect("start over forgets the spot", progressResumePoint("/videos/1", 3000), 0)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("start over plays from 0", m.video.content.PlayStart, 0)
    setVideoState("playing")
    m.video.position = 1200
    onKeyEvent("back", true)

    selectArchive(1)
    m.dialog.choice = "cancel"
    if not m.probeFired then onDialogChoice()
    expect("cancel goes home", m.mode, "home")
    expect("cancel keeps focus", m.focusArea, "archive")
    expect("cancel plays nothing", m.playTask = invalid, true)

    ' --- Watching to the end clears it from Continue watching ---
    selectContinue(0)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    setVideoState("playing")
    setVideoState("finished")
    expect("finished -> home", m.mode, "home")
    expect("finished is forgotten", progressResumePoint("/videos/1", 3000), 0)
    expect("continue row gone", m.continueSection.visible, false)
    expect("archive back up", m.archiveSection.translation[1], 622)
    expect("focus falls to archive", m.focusArea, "archive")

    ' --- Leaving before the video starts keeps the old spot ---
    progressSet("/videos/2", 1000, 3600)
    selectArchive(0)
    m.dialog.choice = "resume"
    if not m.probeFired then onDialogChoice()
    deliver("play", { status: "play", url: "https://x/b.m3u8", title: "" })
    m.video.position = 0
    onKeyEvent("back", true)
    expect("spot kept if it never started", progressResumePoint("/videos/2", 3600), 1000)

    ' --- The live service takes over from a past service, saving her spot ---
    selectContinue(0)
    deliver("play", { status: "play", url: "https://x/b.m3u8", title: "" })
    setVideoState("playing")
    m.video.position = 1500
    checkLive()
    deliver("live", { status: "live", url: "https://x/live1.m3u8" })
    expect("live takes over", m.mode, "live")
    expect("spot saved when live took over", progressResumePoint("/videos/2", 3600), 1500)

    ' --- Live video error reconnects with a fresh link ---
    setVideoState("playing")
    setVideoState("error")
    expect("reconnecting", m.mode, "loading")
    expect("reconnect screen", m.loadingTitle.text, "Reconnecting")
    deliver("live", { status: "live", url: "https://x/live2.m3u8" })
    expect("back to live", m.mode, "live")
    expect("fresh link", m.video.content.url, "https://x/live2.m3u8")
    expect("reconnect screen hidden", m.loading.visible, false)

    ' --- Stuck loading during live restarts it ---
    setVideoState("buffering")
    onPoll()
    deliver("live", { status: "live", url: "https://x/live2.m3u8" })
    expect("one stuck check keeps waiting", m.mode, "live")
    onPoll()
    expect("two stuck checks reconnect", m.mode, "loading")
    deliver("live", { status: "live", url: "https://x/live3.m3u8" })
    expect("restarted", m.video.content.url, "https://x/live3.m3u8")

    ' --- Stream ends ---
    setVideoState("finished")
    expect("live finished -> home", m.mode, "home")
    expect("live finished -> thanks", m.heroState, "ended")
    deliver("archive", { status: "ok", items: items })

    ' --- Back while loading cancels ---
    focusArchive()
    selectArchive(1)
    expect("loading again", m.mode, "loading")
    onKeyEvent("back", true)
    expect("cancelled", m.mode, "home")
    deliver("play", { status: "play", url: "https://x/late.m3u8", title: "" })
    expect("late answer ignored", m.video.visible, false)

    ' --- A past service that fails ---
    selectArchive(1)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    m.video.errorCode = -3
    setVideoState("error")
    expect("error -> home", m.mode, "home")
    expect("error code shown", m.statusCode.text, "Code P-3")
    selectArchive(1)
    deliver("play", { status: "error", code: "R5-403" })
    expect("link error -> home", m.mode, "home")
    expect("link error code", m.statusCode.text, "Code R5-403")

    ' --- Vimeo errors ---
    focusHero()
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("error code on screen", m.statusCode.text, "Code V2-403")
    expect("one error: card unchanged", m.heroState, "ended")
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("two errors: trouble card", m.heroState, "trouble")
    checkLive()
    deliver("live", { status: "offline" })
    expect("recovers to offline", m.heroState, "offline")
    expect("error code cleared", m.statusCode.text, "")

    ' --- Archive failure message ---
    m.archiveCount = 0
    loadArchive()
    deliver("archive", { status: "error", code: "A3-403" })
    expect("archive error text", m.archiveMessage.text, "Past services couldn't be loaded right now. The app will try again later.")

    ' --- Service times line and leaving the app ---
    m.cfg.serviceTimes = "Sundays at 10:30 AM"
    setHero("offline")
    expect("service times hint", m.heroHint.text, "SUNDAYS AT 10:30 AM  ·  PRESS OK TO CHECK NOW")
    focusHero()
    expect("back on home leaves app", onKeyEvent("back", true), false)

    ' --- Saved progress: limits ---
    progressSet("/videos/9", 10, 3000)
    expect("under 30 sec isn't worth resuming", progressResumePoint("/videos/9", 3000), 0)
    progressSet("/videos/9", 2950, 3000)
    expect("last minute counts as finished", progressResumePoint("/videos/9", 3000), 0)
    for i = 1 to 50
        progressSet("/videos/x" + i.ToStr(), 100, 3000)
    end for
    expect("keeps at most 40", m.progress.Count(), 40)

    print ""
    print m.tPassed; " passed,"; m.tFailed; " failed"
    if m.tFailed > 0 then print "SCENE TESTS FAILED" else print "ALL SCENE TESTS PASSED"
end sub

sub onProbe()
    m.probeFired = true
end sub

' Hands a fake Vimeo answer to the task MainScene is waiting on.
sub deliver(kind as String, result as Object)
    if kind = "live"
        task = m.liveTask
    else if kind = "archive"
        task = m.archiveTask
    else
        task = m.playTask
    end if
    if task = invalid
        m.tFailed = m.tFailed + 1
        print "FAIL: no "; kind; " task was waiting for an answer"
        return
    end if
    task.result = result
    if m.probeFired then return ' the observer already ran
    if kind = "live"
        onLiveResult()
    else if kind = "archive"
        onArchiveResult()
    else
        onPlayResult()
    end if
end sub

sub setVideoState(state as String)
    m.video.state = state
    if not m.probeFired then onVideoState()
end sub

sub selectArchive(index as Integer)
    m.archiveRow.rowItemFocused = [0, index]
    m.archiveRow.rowItemSelected = [0, index]
    if not m.probeFired then onArchiveSelected()
end sub

sub selectContinue(index as Integer)
    m.continueRow.rowItemFocused = [0, index]
    m.continueRow.rowItemSelected = [0, index]
    if not m.probeFired then onContinueSelected()
end sub

sub expect(name as String, actual as Dynamic, expected as Dynamic)
    if actual = expected
        m.tPassed = m.tPassed + 1
    else
        m.tFailed = m.tFailed + 1
        print "FAIL: "; name; " -> got ["; actual; "] expected ["; expected; "]"
    end if
end sub
