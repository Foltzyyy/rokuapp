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
