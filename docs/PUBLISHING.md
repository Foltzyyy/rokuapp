# Publishing to the Roku Channel Store

Publishing makes this a regular Roku app:
- it never expires
- it can be moved on the home screen
- it updates itself
- anyone with a Roku can install it by searching **The Chapel Littlestown**

It's free. Roku reviews ("certifies") every public app before it goes live, which usually takes from a few days to a couple of weeks.

**Before you start**
- **Get the church's OK.** The app will be public, under the church's name and logo. It's best to create the Roku developer account with a church email address, so the church owns the app rather than one person.
- **About the Vimeo connection:** the app reaches the stream the same way the website's Vimeo player does (see README, *How it works*). That's not an official Vimeo API. If Vimeo changes it, everyone's app stops playing until it's updated.

You'll need the Roku in developer mode (already done for Grandma's), a computer on the same Wi-Fi, and about an hour.

## 1. Create a Roku developer account

Go to **developer.roku.com** and sign up, ideally with a church email. Accept the developer agreement.

## 2. Make a signing key (one time)

Roku apps are signed with a key that lives on the Roku. Run this on the computer:

- **Windows:** turn on *Telnet Client* (Control Panel → Programs → Turn Windows features on or off → **Telnet Client**). Then open Command Prompt and type `telnet <roku-address> 8080`.
- **Mac:** open Terminal and type `nc <roku-address> 8080`.

`<roku-address>` is the number shown on the Developer Settings screen, like `192.168.1.23`. When it connects, type `genkey` and press Enter. It prints a **Password** and a **DevID**. **Save the password somewhere safe.** You'll need it for every update.

## 3. Package the app

1. Install the newest `dist/ChapelLive.zip` the usual way (`http://<roku-address>` → Upload → Install).
2. On that same page, open **Packager** (under *Utilities* on newer Rokus).
3. **App name:** `The Chapel Littlestown`. **Password:** the one from step 2. Click **Package**.
4. Click the link it shows to download the `.pkg` file. **Keep this first `.pkg` file with the password.** Together they can restore the key on any Roku (Utilities → **Rekey**), for example if this Roku is ever reset or replaced.

## 4. Create the app in the Developer Dashboard

On **developer.roku.com**, open the dashboard's app/channel list (*Manage My Apps*), choose **Add App**, name it **The Chapel Littlestown**, and pick **Public**. Then fill in:

- **Package:** upload the `.pkg` from step 3.
- **Store listing:** copy the name and descriptions from [store-listing.md](store-listing.md). For the category, pick *Religion/Faith* or the closest match.
- **Artwork:** the app poster is `app/images/icon_fhd.png` (540×405) and `app/images/icon_hd.png` (290×218).
- **Screenshots:** with the app open on the Roku, go to `http://<roku-address>`, choose **Utilities → Screenshot**, and save a few (the home screen, a past service playing, the live card).
- **Privacy policy URL:** add the text in [privacy-policy.md](privacy-policy.md) as a page on thechapel.info and paste its address.
- **Support contact:** the church's general email or contact page.
- **Content rating:** answer the questionnaire (religious services, no mature content).
- **Countries:** United States (or wherever you'd like it available).
- **Monetization:** none (free, no ads, no subscriptions).
- **Deep linking test values,** if asked: contentId `live` with mediaType `live`, or a sermon's Vimeo number (the digits in its vimeo.com link) with mediaType `episode`.

## 5. Submit for certification

Click **Submit**. Roku tests the app and emails the result. If they ask for changes, send me what they say and I'll fix it.

## 6. Switch Grandma's Roku to the store version

1. On her Roku: **Home → Streaming Store → Search** → *The Chapel Littlestown* → **Add app**.
2. Delete the developer-mode version (highlight it, press **\***, **Delete**).
3. Optional: turn developer mode off. Repeat the Home ×3, Up ×2, Right, Left, Right, Left, Right sequence and choose **Disable installer**.
4. The store app can be moved: highlight it, press **\***, **Move app**.

Her Continue watching history is stored per app, so it starts fresh in the store version.

## Updating later

1. Bump `minor_version` (or `build_version`) in `app/manifest` and rebuild (`tools/build.sh`).
2. Install the new zip on the Roku in developer mode, then package it again with the **same password** (step 3).
3. In the dashboard, upload the new `.pkg` and submit. Code changes go through certification again.

Everyone's installed app updates itself once Roku approves it.
