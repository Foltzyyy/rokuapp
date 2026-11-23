' Remembers how far she got in each past service, on the Roku itself (the channel
' registry), so it survives restarts. Stored as one small JSON object:
'   { "/videos/123": { p: seconds watched, d: length in seconds, t: when saved }, ... }
' If the registry isn't available (e.g. in tests), it works from memory only.

function progressMinSeconds() as Integer
    return 30 ' less than this isn't worth resuming
end function

function progressEndSeconds() as Integer
    return 60 ' this close to the end counts as finished
end function

function progressMaxEntries() as Integer
    return 40
end function

sub progressInit()
    m.progress = {}
    m.progressSection = CreateObject("roRegistrySection", "ChapelLive")
    if m.progressSection = invalid then return
    if m.progressSection.Exists("progress")
        data = ParseJson(m.progressSection.Read("progress"))
        if type(data) = "roAssociativeArray" then m.progress = data
    end if
end sub

' Saves to memory; call progressFlush() to write it to the Roku.
sub progressSet(uri as String, position as Dynamic, duration as Dynamic)
    if uri = "" then return
    m.progress[uri] = { p: Int(position), d: Int(duration), t: CreateObject("roDateTime").AsSeconds() }
    while m.progress.Count() > progressMaxEntries()
        oldestKey = ""
        oldestTime = 0
        for each key in m.progress
            if oldestKey = "" or m.progress[key].t < oldestTime
                oldestKey = key
                oldestTime = m.progress[key].t
            end if
        end for
        m.progress.Delete(oldestKey)
    end while
end sub

sub progressClear(uri as String)
    if m.progress.DoesExist(uri) then m.progress.Delete(uri)
end sub

sub progressFlush()
    if m.progressSection = invalid then return
    m.progressSection.Write("progress", FormatJson(m.progress))
    m.progressSection.Flush()
end sub

' Where to resume (seconds), or 0 to start from the beginning.
function progressResumePoint(uri as String, duration as Dynamic) as Integer
    entry = m.progress[uri]
    if entry = invalid then return 0
    length = Int(duration)
    if length <= 0 then length = entry.d
    if entry.p < progressMinSeconds() then return 0
    if length > 0 and entry.p > length - progressEndSeconds() then return 0
    return entry.p
end function

' How much has been watched, 0 to 1, for the progress bar on a tile.
function progressFraction(uri as String, duration as Dynamic) as Float
    position = progressResumePoint(uri, duration)
    if position = 0 then return 0
    length = Int(duration)
    if length <= 0 then length = m.progress[uri].d
    if length <= 0 then return 0
    return position / length
end function

' Videos to show under "Continue watching", most recently watched first.
function progressContinueUris() as Object
    entries = []
    for each key in m.progress
        if progressResumePoint(key, 0) > 0 then entries.Push({ uri: key, t: m.progress[key].t })
    end for
    for i = 1 to entries.Count() - 1
        current = entries[i]
        j = i - 1
        while j >= 0 and entries[j].t < current.t
            entries[j + 1] = entries[j]
            j = j - 1
        end while
        entries[j + 1] = current
    end for
    uris = []
    for each entry in entries
        uris.Push(entry.uri)
    end for
    return uris
end function
