# The Chapel Littlestown — Roku app

A Roku app for The Chapel Littlestown's Vimeo livestream and sermon archive, styled to The Chapel's branding guide.

**The home screen**
- **Live card** (selected when the app opens) says whether the service is live.
  - When the service starts, it **goes full screen by itself**, even if she's watching a past service.
  - While it's live, **the service plays right inside the card**. OK makes it full screen, and Back from full screen shrinks it back into the card.
  - When it isn't live, the card shows the service time, and OK checks again right now.
- **Continue watching** lists services she started, newest first, with how much time is left. OK picks up exactly where she stopped. This includes a live service she left early: its recording shows up here once Vimeo posts it.
- **Sermon archive** lists past services from the Vimeo event, newest first. Tiles show a blue bar for how much she's watched. Opening one she's partway through asks **Resume from 25:12** or **Start from the beginning**.
- **Moving around:** Up and Down move between the live card and the rows, and Left/Right move along a row. Back on a row goes to the live card, and Back on the live card leaves the app.

**While a video plays** (the app's own controls, in The Chapel's style)

| Button | What it does |
|---|---|
| **OK** or **Play/Pause** | Pause and resume (the live service too) |
| **Left** / **Right** (or **Rewind** / **Fast-forward**) | Tap: back 10 seconds / ahead 30 seconds. Hold: the playhead slides along the timeline, faster the longer you hold, with a time bubble showing where you'll land. |
| **Up**, **Down** or **\*** | Show the controls (they fade after 5 seconds, and stay while paused) |
| **Back** | Back to the home screen |

When skipping, the video jumps only once you stop pressing (about half a second after the last press), so several taps or a long hold load the video once instead of every time. OK jumps right away. A Roku can't store a whole service ahead of time (too big for its memory), so each jump does need a moment to load.

**Where she stopped is saved on the Roku itself.** It's saved when she pauses, when she leaves a video, and every minute while it plays, so it survives turning the TV off. Services she finishes, or watches to the last minute of, drop off Continue watching.

## Install it on the Roku (one time, about 15 minutes)

You need a computer on **the same Wi-Fi as the Roku**. If you're setting up Grandma's Roku, do this at her house.

1. **Download the app file.** On GitHub, open `dist/ChapelLive.zip` and click the download button (**Download raw file**).
2. **Turn on developer mode on the Roku.** With the Roku remote, press:
   **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
   A *Developer Settings* screen appears with an address like `http://192.168.1.23`. Write it down.
   Choose **Enable installer and restart**, agree to the license, and pick a password (write that down too). The Roku restarts.
   - If it won't enable, the Roku account linked to the box may need a free sign-up at developer.roku.com first.
3. **Open that address in the computer's web browser.** Log in with username `rokudev` and the password you picked.
4. Click **Upload**, choose `ChapelLive.zip`, then click **Install** (on some models: **Install with zip**).
5. The app opens on the TV. It also appears on the home screen as **The Chapel Littlestown**.
   Roku doesn't let you move apps installed this way: pressing **\*** on it only offers close and delete. To make it easier to find, remove apps she doesn't use from the home screen. The store version (below) can be moved.

**Updating later:** repeat steps 3–4 with the new zip. It replaces the old version.

**Older Roku boxes:** the app needs Roku software 9.1 or newer. Any box that still gets updates has it. Check under **Settings → System → About**.

**Good to know:** a Roku holds only one app installed this way. If it ever disappears (for example after a factory reset), repeat the steps.

## Make it permanent: publish it to the Roku Channel Store

Installing it this way works, but it stays a developer-mode app: it can't be moved, and it needs reinstalling after a reset. Publishing it to the Roku Channel Store makes it a regular app. It never expires, can be moved, updates itself, and anyone at church can install it. It's free, and Roku reviews it first. Step-by-step: **[docs/PUBLISHING.md](docs/PUBLISHING.md)**, with a ready-made [store listing](docs/store-listing.md) and [privacy policy](docs/privacy-policy.md).

## Test it before Sunday

1. Open the app. The live card should say **Not live right now**, and the sermon archive should fill with past services. That means the app can reach Vimeo.
2. Press **Down**, then **OK** on a past service. It should play. Try **OK** (pause), tapping and holding **Right** (skip ahead) and **Back**.
3. Back on the home screen, **Continue watching** should show that service. Open it, and it should pick up where you stopped.
4. During the next live service: it should go full screen by itself. Press **Back**, and it should keep playing in the live card. **OK** makes it full screen again.

## If it shows a code

A code at the top right says which step failed. Send a photo of the screen.

| Code starts with | What failed |
|---|---|
| `V` | Checking whether the service is live. |
| `A` | Loading the sermon archive. |
| `R` | Getting a past service ready to play. |
| `P` + number | The Roku couldn't play the video. The number is Roku's error code. |

The number after the letter is the step: **1** getting a viewer pass from vimeo.com (fix: set `apiToken` in `app/source/AppConfig.brs`), **2** reading the event (`-3200` means the event only plays on certain websites; `PRIVATE` means it's set to private), **3** listing the event's videos, **4** reading the event's embed page, **5** loading the player settings.

## How it works

The Roku asks Vimeo for the stream the same way the Vimeo player on the church website does:

1. `vimeo.com/_next/viewer` gives an anonymous viewer token.
2. `api.vimeo.com/live_events/2327573` says whether a broadcast is streaming.
3. `…/live_events/2327573/videos` lists the event's videos: the live one, and past services for the archive.
4. `vimeo.com/event/2327573/embed` holds the player link when the event is set to embed-only.
5. The player config contains the `.m3u8` link the Roku plays.

These are **not official Vimeo APIs**. They can change without notice, and Vimeo's terms don't allow this use. When Vimeo changes things, the app shows a code instead of playing, and the code above says which step to fix. If it breaks for good, the free fallback is simulcasting to YouTube from the Vimeo event's Destinations settings and watching in the YouTube app.

## Branding

Everything follows The Chapel's branding guide (2022):

- **Colors.** Charcoal background, a Navy live card and dialog, and Sky for the selection outline and progress bars. Text uses White, Cloud and Silver, all contrast pairs the guide lists as accessible. Crimson is used only for the "LIVE NOW" tag.
- **Fonts.** Montserrat for text, and Playfair Display Bold Italic for headlines. Both are under the SIL Open Font License, with license files in `app/fonts/`.
- **Writing.** Headlines are in sentence case with no end punctuation, and subheadings are in all caps. Dates are spelled out, like "Sunday, November 16".
- **Logos.** The originals are in `brand/`. `tools/make_images.py` builds every app image from them, only ever scaling them down. Nothing is recolored, outlined or shadowed.

## Changing settings

Everything is in `app/source/AppConfig.brs`:
- the Vimeo event number and the church web page
- an optional **service times** line on the live card (e.g. "Sundays at 10:30 AM")
- whether the live service starts by itself
- how many past services to show
- how often it checks

Rebuild the zip after changing anything.

## Development

```bash
python3 tools/make_images.py     # rebuild images from brand/
tools/build.sh                   # build dist/ChapelLive.zip

# unit tests for the Vimeo parsing logic (BrightScript interpreter)
npx @rokucommunity/brs app/components/Util.brs app/components/VimeoParse.brs tests/parse_test.brs

# screen-logic tests: drives the real screen code through live, the archive, the
# player controls, resume / continue watching, and errors
tests/scene/run.sh

# compile check
npx -p brighterscript bsc --rootDir app --createPackage false
```

Logs: while the Roku is in developer mode, `telnet <roku-address> 8085` shows the app's console output.
