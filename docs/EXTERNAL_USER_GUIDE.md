# MageeMedia — External User Connection Guide

Welcome to **MageeMedia**! This guide explains how to connect to our media streaming services (**Jellyfin** & **Plex**), request new movies and TV shows (**Seerr**), and access photo sharing (**Immich**).

---

## 1. Jellyfin (Primary Streaming)

Jellyfin lets you stream movies, TV shows, and anime from any web browser, smart TV, phone, or tablet without subscriptions or ads.

### Quick Connection Details
* **Public Server URL:** `https://mageemedia.tailcc77cc.ts.net`
* **Local Home Wi-Fi URL:** `http://192.168.1.237:8096`

---

### A. Web Browser (PC, Mac, Laptop)
1. Open Chrome, Safari, Edge, or Firefox.
2. Go to: **[https://mageemedia.tailcc77cc.ts.net](https://mageemedia.tailcc77cc.ts.net)**
3. Enter your **Username** and **Password** provided by the server admin.

---

### B. Mobile Devices (iOS & Android)
1. Download the official **Jellyfin** app from the App Store or Google Play Store:
   * **iOS:** [Jellyfin Mobile on Apple App Store](https://apps.apple.com/app/jellyfin-mobile/id1480192618)
   * **Android:** [Jellyfin on Google Play](https://play.google.com/store/apps/details?id=org.jellyfin.mobile)
2. Open the app. When prompted for **Host / Server Address**, enter:
   ```text
   https://mageemedia.tailcc77cc.ts.net
   ```
3. Tap **Connect** (make sure to include `https://`).
4. Enter your username and password, then tap **Sign In**.

> **Tip for iPhone/iPad users:** If you experience video stuttering with specific formats, you can install the **Swiftfin** app from the App Store—it uses the same URL and login, but features native iOS video rendering.

---

### C. Smart TVs & Streaming Sticks (Apple TV, Android TV, Fire TV, Roku)
1. Search your TV's App Store for **Jellyfin** (or **Swiftfin** on Apple TV / Roku).
2. Open the app and select **Add Server**.
3. Type in the server address:
   ```text
   https://mageemedia.tailcc77cc.ts.net
   ```
4. Sign in with your username and password (or use the Quick Connect code displayed on your screen if supported).

---

## 2. Plex (Alternative Streaming)

If you already use Plex or have an older smart TV with a built-in Plex app:

1. Create a free account at [plex.tv](https://www.plex.tv) (if you haven't already).
2. Give your Plex account username or email to Charlie so you can be invited to the **Magee Plex** library.
3. Accept the invite in your email or at [app.plex.tv](https://app.plex.tv).
4. Download the **Plex** app on your TV, phone, or game console and sign into your personal Plex account.
5. In the sidebar, select **Magee Plex** to pin `Films`, `TV`, and `Anime` to your home screen.

---

## 3. Seerr (Requesting New Content — Formerly Jellyseerr)

Want to watch a film or TV series that isn't on the server yet? You can request it directly:

* **Public Web URL:** **[https://mageemedia.tailcc77cc.ts.net:8443](https://mageemedia.tailcc77cc.ts.net:8443)**
* **Home Wi-Fi URL:** `http://192.168.1.237:5055`
* **How to Sign In:**
  * Click **Sign in with Jellyfin** (or **Sign in with Plex** if you use Plex).
  * Use your existing Jellyfin/Plex credentials.
* **How to Request:**
  1. Search for any movie or TV series.
  2. Click **Request**.
  3. Once approved, the server automatically downloads the media and sends an alert when it is ready to stream.

---

## 4. Immich (Photos & Camera Roll Backup)

For family photo sharing and automatic phone camera roll backups:

* **Mobile App:** Download **Immich** from the App Store or Google Play Store:
  * **iOS:** [Immich on Apple App Store](https://apps.apple.com/app/immich/id1613945652)
  * **Android:** [Immich on Google Play](https://play.google.com/store/apps/details?id=app.alextran.immich)
* **Server Endpoint URL:**
  ```text
  https://mageemedia.tailcc77cc.ts.net:10000
  ```
  *(Works anywhere on 5G / cellular data without needing a VPN!)*
* **Home Wi-Fi Alternative:** `http://192.168.1.237:2283`
* **Sign In:** Use your personal Immich email/username and password.

---

## 5. Troubleshooting & FAQ

* **"Cannot connect to server" on Jellyfin:**
  * Double check that you typed `https://` at the start: `https://mageemedia.tailcc77cc.ts.net`
  * Make sure there are no accidental spaces before or after the URL.
* **Buffering or Quality Issues:**
  * In the Jellyfin player settings (the gear icon during playback), set **Quality** to *Auto* or select a specific bitrate (e.g. 1080p - 10 Mbps).
* **Forgot Password?**
  * Contact Charlie to have your password reset or your account permissions updated.
