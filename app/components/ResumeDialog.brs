sub init()
    m.itemTitle = m.top.findNode("itemTitle")
    m.buttons = [m.top.findNode("button0"), m.top.findNode("button1")]
    m.labels = [m.top.findNode("label0"), m.top.findNode("label1")]
    m.selected = 0
    highlight()
end sub

sub onTitle()
    m.itemTitle.text = m.top.title
end sub

' Called each time the dialog opens: Resume is always the first choice.
sub onResumeAt()
    m.labels[0].text = "Resume from " + fmtTime(m.top.resumeAt)
    m.selected = 0
    highlight()
end sub

' Selected button: Sky with Navy text. Other: Graphite with white text.
sub highlight()
    for i = 0 to 1
        if i = m.selected
            m.buttons[i].color = "0x00A7DDFF"
            m.labels[i].color = "0x19335EFF"
        else
            m.buttons[i].color = "0x4E4F4DFF"
            m.labels[i].color = "0xFFFFFFFF"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" or key = "down"
        m.selected = 1 - m.selected
        highlight()
    else if key = "OK" or key = "play"
        if m.selected = 0 then m.top.choice = "resume" else m.top.choice = "restart"
    else if key = "back"
        m.top.choice = "cancel"
    end if
    return true
end function
