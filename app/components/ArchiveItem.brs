sub init()
    m.focusRing = m.top.findNode("focusRing")
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
end sub

sub onContentChange()
    content = m.top.itemContent
    if content = invalid then return
    m.thumb.uri = content.HDPosterUrl
    m.title.text = content.title
    m.subtitle.text = content.description

    progress = 0.0
    if content.hasField("progress") then progress = content.progress
    hasProgress = progress > 0
    m.progressTrack.visible = hasProgress
    m.progressFill.visible = hasProgress
    m.progressFill.width = 368 * progress
end sub

sub onFocusChange()
    amount = 0
    if m.top.rowListHasFocus then amount = m.top.focusPercent
    m.focusRing.opacity = amount
    if amount > 0.5
        m.title.color = "0xFFFFFFFF"
    else
        m.title.color = "0xEBEDE8FF"
    end if
end sub
