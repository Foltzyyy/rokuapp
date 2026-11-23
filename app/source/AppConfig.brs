' Settings for the app. This is the only file you should need to edit.
function AppConfig() as Object
    return {
        ' The number in the Vimeo event embed link: https://vimeo.com/event/2327573/embed
        eventId: "2327573"

        ' The web page where the stream is embedded. Vimeo checks this for streams
        ' that are only allowed to play on certain websites.
        embedPage: "https://thechapel.info/littlestown/"

        ' Text on the "not live right now" screen.
        churchName: "The Chapel"
        subtitle: "Littlestown Livestream"

        ' How often to check whether the service has started (seconds).
        pollSeconds: 60

        ' While watching, how often to double-check the service is still live (seconds).
        liveCheckSeconds: 120

        ' Optional: a Vimeo personal access token with only the "public" scope.
        ' Leave empty unless the app shows a code starting with V1.
        apiToken: ""
    }
end function
