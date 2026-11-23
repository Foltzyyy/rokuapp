sub init()
    m.livePill = m.top.findNode("livePill")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.bar = m.top.findNode("bar")
    m.fill = m.top.findNode("fill")
    m.knob = m.top.findNode("knob")
    m.elapsed = m.top.findNode("elapsed")
    m.total = m.top.findNode("total")
    m.hint = m.top.findNode("hint")
    m.pausedIcon = m.top.findNode("pausedIcon")
    m.barWidth = 1728

    pillText = m.top.findNode("livePillText")
    m.top.findNode("livePillBg").width = 50 + pillText.boundingRect().width + 22
    onMode()
end sub

sub onText()
    m.title.text = m.top.title
    m.subtitle.text = m.top.subtitle
end sub

sub onMode()
    live = m.top.isLive
    m.livePill.visible = live
    m.bar.visible = not live
    m.elapsed.visible = not live
    m.total.visible = not live
    m.pausedIcon.visible = m.top.paused

    action = "OK to pause"
    if m.top.paused then action = "OK to play"
    if live
        m.hint.text = action + "  ·  Back for home"
    else
        m.hint.text = action + "  ·  Left/Right to skip"
    end if
end sub

sub onProgress()
    position = m.top.position
    duration = m.top.duration
    m.elapsed.text = fmtTime(position)
    if duration > 0
        fraction = position / duration
        if fraction < 0 then fraction = 0
        if fraction > 1 then fraction = 1
        m.fill.width = m.barWidth * fraction
        m.knob.translation = [m.barWidth * fraction - 10, -6]
        m.total.text = fmtTime(duration)
    else
        m.fill.width = 0
        m.knob.translation = [-10, -6]
        m.total.text = ""
    end if
end sub
