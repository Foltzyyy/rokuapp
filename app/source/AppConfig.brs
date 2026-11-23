' Settings for the app. This is the only file you should need to edit.
function AppConfig() as Object
    return {
        ' The number in the Vimeo event embed link: https://vimeo.com/event/2327573/embed
        eventId: "2327573"

        ' The web page where the stream is embedded. Vimeo checks this for streams
        ' that are only allowed to play on certain websites.
        embedPage: "https://thechapel.info/littlestown/"

        ' Shown at the top of the screen while the live service plays.
        liveTitle: "The Chapel Littlestown"

        ' Line on the live card. Leave empty to hide it.
        serviceTimes: "Sundays at 10:30 AM"

        ' Go full screen by itself when the service begins (unless she pressed Back to
        ' leave it). If false, the service plays in the live card until she presses OK.
        autoPlayLive: true

        ' How many past services to show in the sermon archive.
        archiveCount: 30

        ' How often to check whether the service is live (seconds).
        pollSeconds: 60

        ' How often to refresh the sermon archive (seconds).
        archiveRefreshSeconds: 1800

        ' Optional: a Vimeo personal access token with only the "public" scope.
        ' Leave empty unless the app shows a code ending in 1 (V1, A1 or R1).
        apiToken: ""
    }
end function
