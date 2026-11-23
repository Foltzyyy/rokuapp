' Starts the app. Also passes Roku "deep links" to the screen: when Roku search (or
' Roku's certification tests) opens the app straight to a video, at launch (args)
' or while it's already running (roInput).
sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()

    if type(args) = "roAssociativeArray" and args.DoesExist("contentId")
        scene.deepLink = { contentId: args.contentId, mediaType: args.mediaType }
    end if

    input = CreateObject("roInput")
    input.SetMessagePort(port)

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed()
            return
        else if type(msg) = "roInputEvent" and msg.IsInput()
            info = msg.GetInfo()
            if type(info) = "roAssociativeArray" and info.DoesExist("contentId")
                scene.deepLink = { contentId: info.contentId, mediaType: info.mediaType }
            end if
        end if
    end while
end sub
