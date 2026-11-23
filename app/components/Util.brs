' Small text helpers shared by the screen, the player and the Vimeo task.

' 83 -> "1:23", 3723 -> "1:02:03"
function fmtTime(seconds as Dynamic) as String
    total = Int(seconds)
    if total < 0 then total = 0
    hours = Int(total / 3600)
    minutes = Int((total - hours * 3600) / 60)
    secs = total - hours * 3600 - minutes * 60
    text = ""
    if hours > 0
        text = hours.ToStr() + ":"
        if minutes < 10 then text = text + "0"
    end if
    text = text + minutes.ToStr() + ":"
    if secs < 10 then text = text + "0"
    return text + secs.ToStr()
end function

' "1 hr 12 min", "48 min", or "" for unknown.
function fmtDuration(seconds as Dynamic) as String
    total = Int(seconds)
    if total <= 0 then return ""
    minutes = Int((total + 30) / 60)
    if minutes < 1 then minutes = 1
    if minutes < 60 then return minutes.ToStr() + " min"
    hours = Int(minutes / 60)
    rest = minutes - hours * 60
    if rest = 0 then return hours.ToStr() + " hr"
    return hours.ToStr() + " hr " + rest.ToStr() + " min"
end function

' "23 min left"
function fmtTimeLeft(seconds as Dynamic) as String
    text = fmtDuration(seconds)
    if text = "" then return ""
    return text + " left"
end function

' A roDateTime (already in local time) -> "Sunday, November 16", adding the year
' if it isn't this year. Spelled out per the branding guide.
function fmtDate(when as Object) as String
    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    text = days[when.GetDayOfWeek()] + ", " + months[when.GetMonth() - 1] + " " + when.GetDayOfMonth().ToStr()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    if when.GetYear() <> now.GetYear() then text = text + ", " + when.GetYear().ToStr()
    return text
end function

function fmtToday() as String
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    return fmtDate(now)
end function

' Safe reads of values that might be missing (invalid) or the wrong type.
function asText(v as Dynamic) as String
    t = type(v)
    if t = "String" or t = "roString" then return v
    return ""
end function

function asInt(v as Dynamic) as Integer
    t = type(v)
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v)
    return 0
end function
