# Chapel Live

A Roku app that opens straight to The Chapel (Littlestown) livestream on Vimeo.

- **When the service is live:** it plays full screen right away.
- **When it isn't:** it shows "The service isn't live right now," checks once a minute, and starts playing on its own when the service begins.
- **PLAY** on the waiting screen plays the most recent service. **OK** checks again right now.
- **Back** leaves the app, like any other channel.

## Install it on the TV (one time, about 15 minutes)

You need a computer on **the same Wi-Fi as the TV**. If you're setting up Grandma's TV, do this at her house.

1. **Download the app file.** On GitHub, open `dist/ChapelLive.zip` and click the download button (**Download raw file**).
2. **Turn on developer mode on the TV.** With the TV's remote, press:
   **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
   A *Developer Settings* screen appears with an address like `http://192.168.1.23`. Write it down.
   Choose **Enable installer and restart**, agree to the license, and pick a password (write that down too). The TV restarts.
   - If the TV won't enable it, the Roku account linked to the TV may need a free sign-up at developer.roku.com first.
3. **Open that address in the computer's web browser.** Log in with username `rokudev` and the password you picked.
4. Click **Upload**, choose `ChapelLive.zip`, then click **Install** (on some TVs: **Install with zip**).
5. The app opens on the TV. It also appears on the home screen as **Chapel Live**, usually at the end of the list.
   To move it to the top, highlight it, press **\***, and choose **Move channel**.

**Updating later:** repeat steps 3–4 with the new zip. It replaces the old version.

**Good to know:** a Roku holds only one app installed this way. If it ever disappears (for example after a factory reset), repeat the steps.

## Test it before Sunday

1. Open the app. You should see "The service isn't live right now" and, at the bottom right, "Last checked …" with **no Code** next to it. That means the Vimeo checks work.
2. Press **PLAY**. Last week's service should start. That means video playback works.
3. The real test is the next live service.

## If it shows a code

The code at the bottom right says which step failed. Send a photo of the screen.

| Code starts with | What failed |
|---|---|
| `V1` | Getting a viewer pass from vimeo.com. Vimeo may be blocking the TV. Fix: set `apiToken` in `app/source/AppConfig.brs`. |
| `V2` | Reading the event. `-3200` means the event only plays on certain websites. `PRIVATE` means the event is set to private. |
| `V3` | Listing the event's videos. |
| `V4` | Reading the event's embed page (used when the event is "embed only"). |
| `V5` | Loading the player settings, or no playable link in them. |
| `R-` | Loading the most recent service (PLAY button). |
| `P` + number | The Roku couldn't play the video link. The number is Roku's error code. |

## How it works

The Roku asks Vimeo for the stream the same way the Vimeo player on the church website does:

1. `vimeo.com/_next/viewer` gives an anonymous viewer token.
2. `api.vimeo.com/live_events/2327573` says whether a broadcast is streaming.
3. `…/live_events/2327573/videos` lists the event's videos (public events).
4. `vimeo.com/event/2327573/embed` holds the player link (embed-only events).
5. The player config contains the `.m3u8` link the Roku plays.

These are **not official Vimeo APIs**. They can change without notice, and Vimeo's terms don't allow this use. When Vimeo changes things, the app shows a code instead of playing, and the code above says which step to fix. If it breaks for good, the free fallback is simulcasting to YouTube from the Vimeo event's Destinations settings and watching in the YouTube app.

## Changing settings

Everything is in `app/source/AppConfig.brs`: the Vimeo event number, the church web page, the names on screen, and how often it checks. Rebuild the zip after changing anything.

## Development

```bash
python3 tools/make_images.py     # regenerate the tile and splash images
tools/build.sh                   # build dist/ChapelLive.zip

# unit tests for the Vimeo parsing logic (BrightScript interpreter)
npx @rokucommunity/brs app/components/VimeoParse.brs tests/parse_test.brs

# compile check
npx -p brighterscript bsc --rootDir app --createPackage false
```

Logs: while the TV is in developer mode, `telnet <tv-address> 8085` shows the app's console output.
