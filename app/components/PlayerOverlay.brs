sub init()
    m.livePill = m.top.findNode("livePill")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.bar = m.top.findNode("bar")
    m.fill = m.top.findNode("fill")
    m.knob = m.top.findNode("knob")
    m.bubble = m.top.findNode("bubble")
    m.bubbleText = m.top.findNode("bubbleText")
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
    scrubbing = m.top.scrubbing and not live
    m.livePill.visible = live
    m.bar.visible = not live
    m.elapsed.visible = not live
    m.total.visible = not live
    m.pausedIcon.visible = m.top.paused and not scrubbing
    m.bubble.visible = scrubbing
    m.subtitle.visible = not scrubbing ' the bubble needs the room

    action = "OK to pause"
    if m.top.paused then action = "OK to play"
    if scrubbing
        m.hint.text = "Let go to jump here"
    else if live
        m.hint.text = action + "  ·  Back for home"
    else
        m.hint.text = action + "  ·  Hold Left/Right to skip"
    end if
    onProgress()
end sub

sub onProgress()
    position = m.top.position
    duration = m.top.duration
    m.elapsed.text = fmtTime(position)
    m.bubbleText.text = fmtTime(position)
    x = 0
    if duration > 0
        fraction = position / duration
        if fraction < 0 then fraction = 0
        if fraction > 1 then fraction = 1
        x = m.barWidth * fraction
        m.total.text = fmtTime(duration)
    else
        m.total.text = ""
    end if
    m.fill.width = x
    if m.top.scrubbing
        m.knob.width = 28
        m.knob.height = 28
        m.knob.translation = [x - 14, -10]
    else
        m.knob.width = 20
        m.knob.height = 20
        m.knob.translation = [x - 10, -6]
    end if
    bubbleX = x - 80
    if bubbleX < 0 then bubbleX = 0
    if bubbleX > m.barWidth - 160 then bubbleX = m.barWidth - 160
    m.bubble.translation = [bubbleX, -72]
end sub
