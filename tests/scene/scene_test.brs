' Drives the real MainScene code (app/components/MainScene.brs) through the
' situations it has to handle, with fake Vimeo answers and fake video states.
' Run with tests/scene/run.sh. Roku's Task, Video, RowList and Animation nodes are
' replaced by the stand-ins in tests/scene/stubs. (The interpreter has no on-device
' storage, so saved progress lives in memory here.)
'
' Focus matters: on a real Roku, focusing the Scene doesn't take focus away from a
' row, so these tests check that the right node holds focus at each step.

sub runTests(args as Dynamic)
    m.tPassed = 0
    m.tFailed = 0

    ' Do field observers fire right away in this interpreter?
    probe = CreateObject("roSGNode", "Node")
    probe.addField("x", "string", false)
    m.probeFired = false
    probe.observeField("x", "onProbe")
    probe.x = "y"

    hope = { title: "Hope Week 2", subtitle: "Sunday, November 16", thumb: "https://t/2", configUrl: "https://c/2", uri: "/videos/2", duration: 3600 }
    nov9 = { title: "Sunday, November 9", subtitle: "1 hr 12 min", thumb: "", configUrl: "https://c/1", uri: "/videos/1", duration: 3000 }
    nov23 = { title: "Sunday, November 23", subtitle: "1 hr", thumb: "", configUrl: "https://c/7", uri: "/videos/7", duration: 3600 }
    hint = m.overlay.findNode("hint")
    now = nowSeconds()

    ' --- Start-up ---
    expect("starts by checking", m.heroState, "checking")
    expect("live check started", m.liveTask <> invalid, true)
    expect("archive load started", m.archiveTask <> invalid, true)
    expect("live card has focus", m.hero.hasFocus(), true)
    expect("scene itself never has focus", m.top.hasFocus(), false)

    deliver("live", { status: "offline" })
    expect("offline card", m.heroState, "offline")
    expect("service times line", m.heroHint.text, "SUNDAYS AT 10:30 AM  ·  PRESS OK TO CHECK NOW")
    deliver("archive", { status: "ok", items: [hope, nov9] })
    expect("archive count", m.archiveCount, 2)
    expect("archive row shown", m.archiveRow.visible, true)
    expect("no continue row yet", m.continueSection.visible, false)

    ' --- Moving around; OK on the live card must not open a sermon ---
    onKeyEvent("down", true)
    expect("down: archive row has focus", m.archiveRow.hasFocus(), true)
    onKeyEvent("up", true)
    expect("up: live card has focus", m.hero.hasFocus(), true)
    expect("up: row no longer has focus", m.archiveRow.hasFocus(), false)
    onKeyEvent("OK", true)
    expect("OK on the card checks now", m.heroState, "checking")
    expect("OK on the card doesn't play a sermon", m.playTask = invalid, true)
    deliver("live", { status: "offline" })

    ' --- Service goes live: full screen by itself ---
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8", uri: "/videos/7", startTime: now - 1200 })
    expect("live plays by itself", m.mode, "live")
    expect("full screen", m.video.width, 1920)
    expect("marked live", m.video.content.live, true)
    expect("Roku's own controls off", m.video.enableUI, false)
    expect("player has focus", m.keys.hasFocus(), true)
    expect("controls shown", m.overlay.visible, true)
    expect("controls in live mode", m.overlay.isLive, true)
    expect("spinner while starting", m.spinner.visible, true)
    setVideoState("playing")
    expect("spinner gone once playing", m.spinner.visible, false)

    onKeyEvent("OK", true)
    expect("OK pauses live", m.video.control, "pause")
    expect("paused hint", hint.text, "OK to play  ·  Back for home")
    onKeyEvent("OK", true)
    expect("OK resumes live", m.video.control, "resume")
    tap("right")
    expect("no skipping live", m.scrubbing, false)

    ' --- Back: the live service keeps playing inside the live card ---
    expect("back handled", onKeyEvent("back", true), true)
    expect("back to home", m.mode, "home")
    expect("plays in the card", m.previewing, true)
    expect("still playing", m.video.visible and m.video.control <> "stop", true)
    expect("card-sized video", m.video.width, 711)
    expect("video in the card", m.video.translation[0], 1113)
    expect("logo mark hidden behind video", m.heroMark.visible, false)
    expect("live card has focus again", m.hero.hasFocus(), true)
    expect("controls hidden at home", m.overlay.visible, false)
    expect("card says live", m.heroHint.text, "PRESS OK TO WATCH FULL SCREEN")
    checkLive()
    deliver("live", { status: "live", url: "https://x/live.m3u8", uri: "/videos/7", startTime: now - 1200 })
    expect("doesn't jump back to full screen", m.mode, "home")

    onKeyEvent("OK", true)
    expect("OK goes full screen", m.mode, "live")
    expect("full size again", m.video.width, 1920)
    expect("same stream, no reload", m.video.content.url, "https://x/live.m3u8")
    expect("not previewing now", m.previewing, false)
    onKeyEvent("back", true)
    expect("back into the card", m.previewing, true)

    ' --- Moving down stops the card video and remembers how far she got ---
    onKeyEvent("down", true)
    expect("card video stopped", m.previewing, false)
    expect("video hidden", m.video.visible, false)
    expect("logo mark back", m.heroMark.visible, true)
    livePos = progressResumePoint("/videos/7", 0)
    expect("live spot saved", livePos >= 1199 and livePos <= 1203, true)
    onKeyEvent("up", true)
    expect("up restarts the card video", m.previewing, true)
    expect("spinner over the card", m.spinner.translation[0], 1420)
    onKeyEvent("down", true)

    ' --- It ends while she's elsewhere: her spot is kept for the recording ---
    checkLive()
    deliver("live", { status: "offline" })
    expect("ended card", m.heroState, "ended")
    expect("left early: spot kept", progressResumePoint("/videos/7", 0) > 0, true)
    deliver("archive", { status: "ok", items: [nov23, hope, nov9] })
    expect("recording in continue watching", m.continueCount, 1)
    expect("continue tile", m.continueRow.content.getChild(0).getChild(0).title, "Sunday, November 23")
    expect("continue time left", m.continueRow.content.getChild(0).getChild(0).description, "40 min left")

    ' --- Playing a past service; the player has focus, not the row ---
    focusArchive()
    selectArchive(2)
    expect("loading screen", m.mode, "loading")
    expect("loading holds focus", m.keys.hasFocus(), true)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("past service playing", m.mode, "archive")
    expect("player has focus", m.keys.hasFocus(), true)
    expect("row doesn't", m.archiveRow.hasFocus(), false)
    expect("starts at the beginning", m.video.content.PlayStart, 0)
    expect("recording controls", m.overlay.isLive, false)
    setVideoState("playing")
    m.video.duration = 3000
    m.video.position = 600
    expect("elapsed time", m.overlay.findNode("elapsed").text, "10:00")
    expect("total time", m.overlay.findNode("total").text, "50:00")
    expect("playing hint", hint.text, "OK to pause  ·  Hold Left/Right to skip")

    ' --- Skipping: the playhead moves now, the video jumps once ---
    tap("right")
    expect("tap moves the playhead", m.overlay.position, 630)
    expect("video hasn't jumped yet", m.video.seek, 0)
    expect("bubble shows", m.overlay.findNode("bubble").visible, true)
    expect("skip hint", hint.text, "Let go to jump here")
    settle()
    expect("then the video jumps", m.video.seek, 630)
    expect("bubble gone", m.overlay.findNode("bubble").visible, false)

    m.video.position = 630
    tap("right")
    ticks(2)
    tap("fastforward")
    ticks(2)
    expect("quick taps: still one jump pending", m.video.seek, 630)
    tap("left")
    expect("taps add up", m.overlay.position, 680)
    settle()
    expect("one jump for several taps", m.video.seek, 680)

    m.video.position = 680
    onKeyEvent("right", true)
    ticks(20)
    expect("holding speeds along", m.overlay.position, 960)
    expect("no jump while held", m.video.seek, 680)
    onKeyEvent("right", false)
    settle()
    expect("jumps where she let go", m.video.seek, 960)

    m.video.position = 960
    tap("rewind")
    onKeyEvent("OK", true)
    expect("OK jumps right away", m.video.seek, 950)
    expect("OK didn't pause", m.paused, false)

    m.video.position = 2990
    tap("right")
    settle()
    expect("can't skip past the end", m.video.seek, 2995)
    m.video.position = 5
    tap("left")
    settle()
    expect("can't skip before the start", m.video.seek, 0)
    m.video.position = 600

    onKeyEvent("OK", true)
    expect("OK pauses", m.video.control, "pause")
    expect("pausing saves the spot", progressResumePoint("/videos/1", 3000), 600)
    onKeyEvent("play", true)
    expect("Play resumes", m.video.control, "resume")

    ' --- Leaving partway: Continue watching ---
    onKeyEvent("back", true)
    expect("back home", m.mode, "home")
    expect("row has focus again", m.archiveRow.hasFocus(), true)
    expect("two in continue watching", m.continueCount, 2)
    expect("most recent first", m.continueRow.content.getChild(0).getChild(0).title, "Sunday, November 9")
    expect("time left", m.continueRow.content.getChild(0).getChild(0).description, "40 min left")
    expect("archive tile progress", m.archiveRow.content.getChild(0).getChild(2).progress, 0.2)
    expect("archive moves down", m.archiveSection.translation[1], 1068)
    expect("rows scrolled into view", m.scrollTarget, -426)
    onKeyEvent("up", true)
    expect("up: continue row", m.continueRow.hasFocus(), true)
    onKeyEvent("up", true)
    expect("up: live card", m.hero.hasFocus(), true)
    expect("scrolled back up", m.scrollTarget, 0)
    onKeyEvent("down", true)

    selectContinue(0)
    expect("continue: no question asked", m.dialog.visible, false)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("resumes where she stopped", m.video.content.PlayStart, 600)
    setVideoState("playing")
    m.video.position = 900
    onKeyEvent("back", true)
    expect("new spot saved", progressResumePoint("/videos/1", 3000), 900)
    expect("focus back on continue row", m.continueRow.hasFocus(), true)

    ' --- From the archive, a started service asks first ---
    focusArchive()
    selectArchive(2)
    expect("asks resume or start over", m.mode, "dialog")
    expect("dialog has focus", m.dialog.hasFocus(), true)
    expect("resume button", m.dialog.findNode("label0").text, "Resume from 15:00")
    choose("resume")
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("resume choice", m.video.content.PlayStart, 900)
    setVideoState("playing")
    onKeyEvent("back", true)

    selectArchive(2)
    choose("restart")
    expect("start over forgets the spot", progressResumePoint("/videos/1", 3000), 0)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    expect("start over plays from 0", m.video.content.PlayStart, 0)
    setVideoState("playing")
    m.video.position = 1200
    onKeyEvent("back", true)

    selectArchive(2)
    choose("cancel")
    expect("cancel goes home", m.mode, "home")
    expect("cancel: row has focus", m.archiveRow.hasFocus(), true)
    expect("cancel plays nothing", m.playTask = invalid, true)

    ' --- Watching to the end clears it ---
    selectArchive(2)
    choose("resume")
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    setVideoState("playing")
    setVideoState("finished")
    expect("finished -> home", m.mode, "home")
    expect("finished is forgotten", progressResumePoint("/videos/1", 3000), 0)
    expect("one left in continue watching", m.continueCount, 1)

    ' --- Leaving before the video starts keeps the old spot ---
    progressSet("/videos/2", 1000, 3600)
    selectArchive(1)
    choose("resume")
    deliver("play", { status: "play", url: "https://x/b.m3u8", title: "" })
    m.video.position = 0
    onKeyEvent("back", true)
    expect("spot kept if it never started", progressResumePoint("/videos/2", 3600), 1000)

    ' --- Next service: takes over from a past service, saving her spot ---
    selectArchive(1)
    choose("resume")
    deliver("play", { status: "play", url: "https://x/b.m3u8", title: "" })
    setVideoState("playing")
    m.video.position = 1500
    checkLive()
    deliver("live", { status: "live", url: "https://x/live1.m3u8", uri: "/videos/8", startTime: nowSeconds() - 120 })
    expect("live takes over", m.mode, "live")
    expect("spot saved when live took over", progressResumePoint("/videos/2", 3600), 1500)
    setVideoState("playing")
    onPoll()
    deliver("live", { status: "live", url: "https://x/live1.m3u8", uri: "/videos/8" })
    expect("live spot kept up to date", progressResumePoint("/videos/8", 0) >= 119, true)

    ' --- Live video error reconnects with a fresh link ---
    setVideoState("error")
    expect("reconnecting", m.mode, "loading")
    expect("reconnect screen", m.loadingTitle.text, "Reconnecting")
    deliver("live", { status: "live", url: "https://x/live2.m3u8", uri: "/videos/8" })
    expect("back to live", m.mode, "live")
    expect("fresh link", m.video.content.url, "https://x/live2.m3u8")

    ' --- Stuck loading during live restarts it ---
    setVideoState("buffering")
    onPoll()
    deliver("live", { status: "live", url: "https://x/live2.m3u8", uri: "/videos/8" })
    expect("one stuck check keeps waiting", m.mode, "live")
    onPoll()
    expect("two stuck checks reconnect", m.mode, "loading")
    deliver("live", { status: "live", url: "https://x/live3.m3u8", uri: "/videos/8" })
    expect("restarted", m.video.content.url, "https://x/live3.m3u8")

    ' --- Watched to the end: nothing to continue ---
    setVideoState("finished")
    expect("live finished -> home", m.mode, "home")
    expect("thanks for watching", m.heroState, "ended")
    expect("watched to the end: spot cleared", progressResumePoint("/videos/8", 0), 0)
    deliver("archive", { status: "ok", items: [nov23, hope, nov9] })
    m.endedAt = nowSeconds() - 7300
    checkLive()
    deliver("live", { status: "offline" })
    expect("thanks turns back into not live after 2 hours", m.heroState, "offline")

    ' --- Back while loading cancels ---
    focusArchive()
    selectArchive(2)
    expect("loading again", m.mode, "loading")
    onKeyEvent("back", true)
    expect("cancelled", m.mode, "home")
    deliver("play", { status: "play", url: "https://x/late.m3u8", title: "" })
    expect("late answer ignored", m.video.visible, false)

    ' --- A past service that fails ---
    selectArchive(2)
    deliver("play", { status: "play", url: "https://x/a.m3u8", title: "" })
    m.video.errorCode = -3
    setVideoState("error")
    expect("error -> home", m.mode, "home")
    expect("error code shown", m.statusCode.text, "Code P-3")
    selectArchive(2)
    deliver("play", { status: "error", code: "R5-403" })
    expect("link error -> home", m.mode, "home")
    expect("link error code", m.statusCode.text, "Code R5-403")

    ' --- Vimeo errors ---
    focusHero()
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("error code on screen", m.statusCode.text, "Code V2-403")
    checkLive()
    deliver("live", { status: "error", code: "V2-403" })
    expect("two errors: trouble card", m.heroState, "trouble")
    checkLive()
    deliver("live", { status: "offline" })
    expect("recovers", m.heroState, "offline")
    expect("error code cleared", m.statusCode.text, "")

    ' --- Archive failure message; leaving the app ---
    m.archiveCount = 0
    loadArchive()
    deliver("archive", { status: "error", code: "A3-403" })
    expect("archive error text", m.archiveMessage.text, "Past services couldn't be loaded right now. The app will try again later.")
    focusHero()
    expect("back on home leaves app", onKeyEvent("back", true), false)
    expect("scene itself never had focus", m.top.hasFocus(), false)

    ' --- Deep links (Roku search and certification tests) ---
    deepLink("1")
    expect("deep link opens that service", m.mode, "loading")
    expect("deep link: right video", m.current.uri, "/videos/1")
    deliver("play", { status: "play", url: "https://x/d.m3u8", title: "" })
    expect("deep link plays", m.mode, "archive")
    deepLink("999")
    expect("unknown video: keeps playing", m.mode, "archive")
    expect("unknown video: link dropped", m.pendingDeepLink, "")
    deepLink("live")
    expect("live link while not live: home screen", m.mode, "home")
    setHero("checking")
    checkLive()
    deepLink("live")
    expect("live link waits for the check", m.pendingDeepLink, "live")
    deliver("live", { status: "live", url: "https://x/live9.m3u8", uri: "/videos/9" })
    expect("then plays live", m.mode, "live")
    expect("link used up", m.pendingDeepLink, "")
    deepLink("live")
    expect("live link while watching: no reload", m.video.content.url, "https://x/live9.m3u8")

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

' A quick press and release.
sub tap(key as String)
    onKeyEvent(key, true)
    onKeyEvent(key, false)
end sub

' The skip timer firing (every 0.15 s on the Roku).
sub ticks(count as Integer)
    for i = 1 to count
        onScrubTick()
    end for
end sub

' Long enough after the last press for the video to jump.
sub settle()
    ticks(4)
end sub

sub deepLink(contentId as String)
    m.top.deepLink = { contentId: contentId, mediaType: "episode" }
    if not m.probeFired then onDeepLink()
end sub

sub choose(choice as String)
    m.dialog.choice = choice
    if not m.probeFired then onDialogChoice()
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
