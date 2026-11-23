' Unit tests for app/components/VimeoParse.brs.
' Run: npx @rokucommunity/brs app/components/VimeoParse.brs tests/parse_test.brs
' The sample JSON mirrors the fields Vimeo returns (see yt-dlp's Vimeo extractor).

sub Main()
    m.failed = 0
    m.passed = 0

    ' --- vpFindLiveClip ---
    live = ParseJson("{""stream_privacy"":{""view"":""anybody""},""clip_to_play"":{""uri"":""/videos/111"",""config_url"":""https://player.vimeo.com/video/111/config?s=a"",""live"":{""status"":""streaming""}}}")
    clip = vpFindLiveClip(live)
    check("live clip known", clip.known, true)
    check("live clip streaming", clip.streaming, true)
    check("live clip config url", clip.configUrl, "https://player.vimeo.com/video/111/config?s=a")

    done = ParseJson("{""clip_to_play"":{""config_url"":""https://x/config"",""live"":{""status"":""done""}},""streamable_clip"":{""live"":{""status"":""unavailable""}}}")
    clip = vpFindLiveClip(done)
    check("done clip known", clip.known, true)
    check("done clip not streaming", clip.streaming, false)
    check("done clip has no live url", clip.configUrl, "")

    ' streamable_clip is live while clip_to_play is the last recording
    mixed = ParseJson("{""clip_to_play"":{""config_url"":""https://old"",""live"":{""status"":""done""}},""streamable_clip"":{""config_url"":""https://new"",""live"":{""status"":""streaming""}}}")
    check("streamable clip used when live", vpFindLiveClip(mixed).configUrl, "https://new")

    clip = vpFindLiveClip(ParseJson("{""title"":""x""}"))
    check("no clip info -> unknown", clip.known, false)
    check("invalid input is safe", vpFindLiveClip(invalid).known, false)

    ' --- vpFindVideo ---
    videos = ParseJson("{""data"":[{""config_url"":""https://a"",""created_time"":""2026-11-09T15:00:00+00:00"",""live"":{""status"":""done""}},{""config_url"":""https://c"",""created_time"":""2026-11-23T15:00:00+00:00"",""live"":{""status"":""streaming""}},{""config_url"":""https://b"",""created_time"":""2026-11-16T15:00:00+00:00"",""live"":{""status"":""done""}},{""config_url"":""https://d"",""created_time"":""2026-11-30T15:00:00+00:00"",""live"":{""status"":""unavailable""}}]}")
    check("live video picked", vpFindVideo(videos, false), "https://c")
    check("newest finished recording picked", vpFindVideo(videos, true), "https://b")
    noneLive = ParseJson("{""data"":[{""config_url"":""https://a"",""live"":{""status"":""done""}}]}")
    check("no live video", vpFindVideo(noneLive, false), "")
    check("empty list", vpFindVideo(ParseJson("{""data"":[]}"), true), "")
    check("bad list", vpFindVideo(invalid, true), "")

    ' --- vpConfigUrlFromHtml ---
    html = "<div id=""player"" data-config-url=""https://player.vimeo.com/video/222/config?a=1&amp;b=2"" class=""x""></div>"
    check("config url from data attribute", vpConfigUrlFromHtml(html), "https://player.vimeo.com/video/222/config?a=1&b=2")
    html = "<script>window.x = {""config_url"":""https:\/\/player.vimeo.com\/video\/333\/config?a=1&b=2""}</script>"
    check("config url from embedded JSON", vpConfigUrlFromHtml(html), "https://player.vimeo.com/video/333/config?a=1&b=2")
    check("no config url", vpConfigUrlFromHtml("<html></html>"), "")

    ' --- vpPickStream ---
    cfg = ParseJson("{""video"":{""title"":""Sunday Service"",""live_event"":{""status"":""started""}},""request"":{""files"":{""hls"":{""default_cdn"":""fastly_skyfire"",""cdns"":{""akfire_interconnect_quic"":{""url"":""https://ak/playlist.m3u8""},""fastly_skyfire"":{""url"":""https://fastly/playlist.m3u8"",""avc_url"":""https://fastly/avc/playlist.m3u8""}}}}}}")
    s = vpPickStream(cfg)
    check("live status", s.liveStatus, "started")
    check("title", s.title, "Sunday Service")
    check("default cdn, H.264 link preferred", s.url, "https://fastly/avc/playlist.m3u8")

    cfg = ParseJson("{""video"":{""live_event"":{""status"":""ended""}},""request"":{""files"":{""hls"":{""default_cdn"":""gone"",""cdns"":{""akfire_interconnect_quic"":{""url"":""https://ak/playlist.m3u8""}}}}}}")
    s = vpPickStream(cfg)
    check("missing default cdn falls back", s.url, "https://ak/playlist.m3u8")
    check("ended status", s.liveStatus, "ended")

    cfg = ParseJson("{""video"":{""files"":{""hls"":{""cdns"":{""x"":{""url"":""https://vf/playlist.m3u8""}}}}},""request"":{}}")
    check("video.files fallback", vpPickStream(cfg).url, "https://vf/playlist.m3u8")
    check("no hls -> empty", vpPickStream(ParseJson("{""video"":{}}")).url, "")
    check("invalid config -> empty", vpPickStream(invalid).url, "")

    ' --- vpToText ---
    check("error_code number", vpToText(vpGet(ParseJson("{""error_code"":3200}"), "error_code")), "3200")
    check("missing error_code", vpToText(vpGet(ParseJson("{}"), "error_code")), "")

    ' --- vpPickThumb ---
    pics = ParseJson("{""base_link"":""https://i.vimeocdn.com/video/1-a-d"",""sizes"":[{""width"":295,""link"":""https://t/295""},{""width"":1280,""link"":""https://t/1280""},{""width"":640,""link"":""https://t/640""},{""width"":960,""link"":""https://t/960""}]}")
    check("thumb: smallest >= 640", vpPickThumb(pics, 640), "https://t/640")
    pics = ParseJson("{""sizes"":[{""width"":100,""link"":""https://t/100""},{""width"":295,""link"":""https://t/295""}]}")
    check("thumb: largest when all small", vpPickThumb(pics, 640), "https://t/295")
    check("thumb: base_link fallback", vpPickThumb(ParseJson("{""base_link"":""https://i/v/1-a-d""}"), 640), "https://i/v/1-a-d_640x360")
    check("thumb: nothing", vpPickThumb(invalid, 640), "")

    ' --- vpArchiveItems ---
    list = ParseJson("{""data"":[{""uri"":""/videos/1"",""name"":""Sunday Worship"",""created_time"":""2026-11-09T15:00:00+00:00"",""duration"":4320,""config_url"":""https://c/1"",""live"":{""status"":""done""}},{""uri"":""/videos/3"",""name"":""Sunday Worship"",""created_time"":""2026-11-23T15:00:00+00:00"",""config_url"":""https://c/3"",""live"":{""status"":""streaming""}},{""uri"":""/videos/2"",""name"":""Hope Week 2"",""created_time"":""2026-11-16T15:00:00+00:00"",""duration"":3000,""config_url"":""https://c/2"",""live"":{""status"":""done""},""pictures"":{""sizes"":[{""width"":640,""link"":""https://t/2""}]}},{""uri"":""/videos/4"",""created_time"":""2026-11-30T15:00:00+00:00"",""config_url"":""https://c/4"",""live"":{""status"":""unavailable""}},{""uri"":""/videos/5"",""name"":""Uploaded"",""created_time"":""2026-10-01T12:00:00+00:00"",""config_url"":""https://c/5""}]}")
    items = vpArchiveItems(list, 10)
    check("archive: live/upcoming skipped", items.Count(), 3)
    check("archive: newest first", items[0].uri, "/videos/2")
    check("archive: then older", items[1].uri, "/videos/1")
    check("archive: uploaded video kept", items[2].uri, "/videos/5")
    check("archive: duration", items[0].duration, 3000)
    check("archive: thumb", items[0].thumb, "https://t/2")
    check("archive: max count", vpArchiveItems(list, 2).Count(), 2)
    check("archive: bad input", vpArchiveItems(invalid, 10).Count(), 0)

    ' --- vpDurationText ---
    check("duration 0", vpDurationText(0), "")
    check("duration 48 min", vpDurationText(48 * 60 + 10), "48 min")
    check("duration 1 hr", vpDurationText(3600), "1 hr")
    check("duration 1 hr 12 min", vpDurationText(4320), "1 hr 12 min")

    ' --- vpItemLabels ---
    l = vpItemLabels("Sunday Worship", "sunday worship", "Sunday, November 16", "1 hr 12 min")
    check("labels: generic name -> date title", l.title, "Sunday, November 16")
    check("labels: generic name -> duration subtitle", l.subtitle, "1 hr 12 min")
    l = vpItemLabels("Hope Week 2", "Sunday Worship", "Sunday, November 16", "50 min")
    check("labels: real title kept", l.title, "Hope Week 2")
    check("labels: date as subtitle", l.subtitle, "Sunday, November 16")
    check("labels: no name, no date", vpItemLabels("", "x", "", "").title, "")

    ' --- vpFormatDate (needs roDateTime; the test machine's clock is UTC) ---
    year = CreateObject("roDateTime").GetYear().ToStr()
    thisYear = vpFormatDate(year + "-06-15T15:00:00+00:00")
    check("date this year: month and day", Instr(1, thisYear, ", June 15") > 0, true)
    check("date this year: no year shown", Instr(1, thisYear, year), 0)
    check("date other year", vpFormatDate("2025-12-25T15:00:00+00:00"), "Thursday, December 25, 2025")
    check("date too short", vpFormatDate("2026"), "")

    print ""
    print m.passed; " passed,"; m.failed; " failed"
    if m.failed > 0 then print "TESTS FAILED" else print "ALL TESTS PASSED"
end sub

sub check(name as String, actual as Dynamic, expected as Dynamic)
    if actual = expected
        m.passed = m.passed + 1
    else
        m.failed = m.failed + 1
        print "FAIL: "; name; " -> got ["; actual; "] expected ["; expected; "]"
    end if
end sub
