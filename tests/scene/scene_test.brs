' Drives the real MainScene code (app/components/MainScene.brs) through the
' situations it has to handle, with fake Vimeo answers and fake video states.
' Run with tests/scene/run.sh. Roku's Task, Video and RowList nodes are replaced
' by the stand-ins in tests/scene/stubs.

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
        { title: "Hope Week 2", subtitle: "Sunday, November 16", thumb: "https://t/2", configUrl: "https://c/2", uri: "/videos/2" }
        { title: "Sunday, November 9", subtitle: "1 hr 12 min", thumb: "", configUrl: "https://c/1", uri: "/videos/1" }
    ]

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
    expect("offline pill", m.pillText.text, "NOT LIVE")

    ' --- Archive arrives ---
    deliver("archive", { status: "ok", items: items })
    expect("archive count", m.archiveCount, 2)
    expect("archive row shown", m.archiveRow.visible, true)
    expect("loading text hidden", m.archiveMessage.visible, false)
    expect("first item title", m.archiveRow.content.getChild(0).getChild(0).title, "Hope Week 2")
    expect("item keeps config link", m.archiveRow.content.getChild(0).getChild(1).configUrl, "https://c/1")

    ' --- Moving between the live card and the archive ---
    onKeyEvent("down", true)
    expect("down goes to archive", m.focusArea, "archive")
    expect("live card ring hidden", m.heroRing.visible, false)
    onKeyEvent("up", true)
    expect("up goes to live card", m.focusArea, "hero")

    ' --- Service goes live: plays by itself ---
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8" })
    expect("live plays by itself", m.mode, "live")
    expect("live link", m.video.content.url, "https://x/live.m3u8")
    expect("marked live", m.video.content.live, true)
    expect("no pausing live", m.video.enableTrickPlay, false)
    expect("home hidden while watching", m.home.visible, false)
    expect("LIVE NOW badge", m.liveBadge.visible, true)
    setVideoState("playing")

    ' --- Back leaves live and doesn't restart it ---
    expect("back handled", onKeyEvent("back", true), true)
    expect("back to home", m.mode, "home")
    expect("remembers she left", m.liveDismissed, true)
    expect("home visible", m.home.visible, true)
    expect("card says live", m.heroHeadline.text, "The service is live")
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8" })
    expect("doesn't restart after Back", m.mode, "home")

    ' --- OK on the live card watches ---
    onKeyEvent("OK", true)
    expect("OK plays live", m.mode, "live")
    setVideoState("playing")

    ' --- One odd "offline" answer doesn't cut the stream; two in a row do ---
    checkLive()
    deliver("live", { status: "offline" })
    expect("one offline ignored while playing", m.mode, "live")
    checkLive()
    deliver("live", { status: "offline" })
    expect("two offline -> home", m.mode, "home")
    expect("thanks for watching", m.heroState, "ended")
    expect("archive refreshed after service", m.archiveTask <> invalid, true)
    deliver("archive", { status: "ok", items: items })

    ' --- Playing a past service ---
    focusArchive()
    selectArchive(1)
    expect("loading screen", m.mode, "loading")
    expect("loading shows title", m.loadingDetail.text, "Sunday, November 9")
    expect("play task started", m.playTask <> invalid, true)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("archive playing", m.mode, "archive")
    expect("archive link", m.video.content.url, "https://x/a.m3u8")
    expect("can pause recordings", m.video.enableTrickPlay, true)
    expect("loading hidden", m.loading.visible, false)
    setVideoState("playing")
    onKeyEvent("back", true)
    expect("back from recording", m.mode, "home")
    expect("focus back on archive", m.focusArea, "archive")

    ' --- Back while loading cancels ---
    selectArchive(0)
    expect("loading again", m.mode, "loading")
    onKeyEvent("back", true)
    expect("cancelled", m.mode, "home")
    deliver("play", { status: "play", url: "https://x/late.m3u8", title: "" })
    expect("late answer ignored", m.video.visible, false)

    ' --- A recording that fails to play ---
    selectArchive(1)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    m.video.errorCode = -3
    setVideoState("error")
    expect("error -> home", m.mode, "home")
    expect("error code shown", m.statusCode.text, "Code P-3")

    ' --- Archive link couldn't be resolved ---
    selectArchive(0)
    deliver("play", { status: "error", code: "R5-403" })
    expect("resolve error -> home", m.mode, "home")
    expect("resolve error code", m.statusCode.text, "Code R5-403")

    ' --- Live video error reconnects with a fresh link ---
    focusHero()
    checkLive()
    deliver("live", { status: "live", url: "https://x/live1.m3u8" })
    expect("live again", m.mode, "live")
    setVideoState("playing")
    setVideoState("error")
    expect("reconnecting", m.mode, "loading")
    expect("reconnect screen", m.loadingTitle.text, "Reconnecting")
    deliver("live", { status: "live", url: "https://x/live2.m3u8" })
    expect("back to live", m.mode, "live")
    expect("fresh link", m.video.content.url, "https://x/live2.m3u8")
    expect("reconnect screen hidden", m.loading.visible, false)

    ' --- Stream ends ---
    setVideoState("finished")
    expect("finished -> home", m.mode, "home")
    expect("finished -> thanks", m.heroState, "ended")

    ' --- Stuck loading during live restarts it ---
    deliver("archive", { status: "ok", items: items })
    checkLive()
    deliver("live", { status: "live", url: "https://x/live3.m3u8" })
    expect("live for stall test", m.mode, "live")
    setVideoState("buffering")
    onPoll()
    deliver("live", { status: "live", url: "https://x/live3.m3u8" })
    expect("one stuck check keeps waiting", m.mode, "live")
    onPoll()
    expect("two stuck checks reconnect", m.mode, "loading")
    deliver("live", { status: "live", url: "https://x/live4.m3u8" })
    expect("restarted", m.video.content.url, "https://x/live4.m3u8")
    setVideoState("finished")

    ' --- Vimeo errors ---
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("error code on screen", m.statusCode.text, "Code V2-403")
    expect("one error: card unchanged", m.heroState, "ended")
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("two errors: trouble card", m.heroState, "trouble")
    expect("trouble headline", m.heroHeadline.text, "Having trouble connecting")
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

sub expect(name as String, actual as Dynamic, expected as Dynamic)
    if actual = expected
        m.tPassed = m.tPassed + 1
    else
        m.tFailed = m.tFailed + 1
        print "FAIL: "; name; " -> got ["; actual; "] expected ["; expected; "]"
    end if
end sub
