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

        ' Optional line on the live card, e.g. "Sundays at 10:30 AM". Leave empty to hide it.
        serviceTimes: ""

        ' Start the live service by itself when it begins (unless she pressed Back to leave it).
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
