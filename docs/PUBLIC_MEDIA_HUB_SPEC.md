# Public Media Hub Specification (Handoff for magrizzly.github.io)

This document contains pre-sanitized, public-safe content, structure, and design recommendations for creating the **Media Server Hub** (`media.html`) on [magrizzly.github.io](https://magrizzly.github.io) (`www.magrizzly.co.uk`).

---

## 1. Page Metadata & Navigation
* **Page Title:** Media Hub — Charlie's Personal Media Server
* **Filename:** `media.html`
* **Nav Label:** `Media` (positioned between `Projects` / `Tools` and `Resources`)
* **URL:** `https://www.magrizzly.co.uk/media.html` (or `/media`)
* **Design Language:** Matches existing `components.css` and `style.css` (dark/light mode support, bento cards, responsive mobile menu, zero external dependencies).

---

## 2. Hero Section
* **Badge / Eyebrow:** `Private Cloud & Streaming`
* **Headline:** Welcome to the MageeMedia Hub
* **Subtitle:** Stream movies, TV series, anime, and access family photo backups across all your devices. Powered by Jellyfin, Plex, and Immich.
* **Call-to-Action (CTA) Buttons:**
  * **Primary Button:** `Launch Jellyfin Web` → Link: `https://mageemedia.tailcc77cc.ts.net` (`target="_blank" rel="noopener noreferrer"`)
  * **Secondary Button:** `Request Content (Seerr)` → Link: `http://mageemedia.tailcc77cc.ts.net:5055` (`target="_blank" rel="noopener noreferrer"`)

---

## 3. Core Services (Bento Grid)

### Card 1: Jellyfin (Primary Streaming)
* **Tag:** `Primary Streaming`
* **Description:** Open-source, ad-free streaming for films, TV series, and anime in up to 4K HDR.
* **Server Address for Apps:** `https://mageemedia.tailcc77cc.ts.net`
* **Client App Download Badges / Links:**
  * **Web:** [Open in Browser](https://mageemedia.tailcc77cc.ts.net)
  * **iOS / iPadOS:** [Jellyfin Mobile (App Store)](https://apps.apple.com/app/jellyfin-mobile/id1480192618)
  * **Android / Google TV:** [Jellyfin (Google Play)](https://play.google.com/store/apps/details?id=org.jellyfin.mobile)
  * **Apple TV / iOS Alternative:** [Swiftfin (App Store)](https://apps.apple.com/app/swiftfin/id1601048596) *(Native player, recommended for smoother playback on Apple devices)*
  * **Smart TVs:** Search for **Jellyfin** on Roku, Fire TV, or Android TV.

### Card 2: Plex (Alternative Streaming)
* **Tag:** `Alternative Streaming`
* **Description:** Access the library using your existing personal Plex account. Best for older Smart TVs and gaming consoles (PlayStation / Xbox).
* **Setup Steps:**
  1. Create a free account at [plex.tv](https://www.plex.tv).
  2. Send your Plex username/email to Charlie to receive an invitation to the **Magee Plex** library.
  3. Accept the invite in your email or at [app.plex.tv](https://app.plex.tv).
  4. Launch the Plex app on any TV or device and pin `Films`, `TV`, and `Anime`.

### Card 3: Seerr (Media Requests — Formerly Jellyseerr)
* **Tag:** `Request Portal`
* **Description:** Browse trending titles, view trailers, and request new movies or TV shows to be automatically added to the server.
* **How to Use:**
  1. Open the [Seerr Portal](http://mageemedia.tailcc77cc.ts.net:5055).
  2. Sign in with your existing **Jellyfin** or **Plex** credentials.
  3. Search for any movie or series and tap **Request**. You will receive an alert when it is downloaded and ready to watch.

### Card 4: Immich (Photos & Camera Roll Backup)
* **Tag:** `Private Photos`
* **Description:** High-performance self-hosted photo & video backup for family members. Replaces Google Photos and Apple iCloud.
* **Setup Steps:**
  * Install the **Immich** app from the App Store or Google Play.
  * Server Endpoint: `http://mageemedia.tailcc77cc.ts.net:2283`
  * Sign in with your assigned user account to enable automatic background camera roll backup.

---

## 4. Connection & Setup Guide (Tabbed or Accordion)

### Connection Checklist
1. **Remote Access:** When outside the home network, make sure you enter the full secure URL including `https://`:
   `https://mageemedia.tailcc77cc.ts.net`
2. **Video Playback Quality:**
   * In Jellyfin, tap the **Gear** icon during video playback.
   * If on a slower mobile connection, adjust **Quality** from `Auto` to `1080p - 10 Mbps` or `720p - 4 Mbps`.
3. **Audio / Subtitles:**
   * Jellyfin supports full subtitle selection (including forced subtitles for foreign dialogue) and multiple audio tracks (e.g. Japanese audio + English subtitles for Anime).

---

## 5. FAQ & Troubleshooting Accordion

* **Q: I see a "Cannot connect to server" error. What should I check?**
  * **A:** Verify the server URL has no spaces: `https://mageemedia.tailcc77cc.ts.net`. If accessing over mobile data or external Wi-Fi, ensure your device can reach the server endpoint or Tailscale connection.
* **Q: How do I get an account?**
  * **A:** Contact Charlie directly with your preferred username. An account will be created with access to Jellyfin, Seerr, and Immich.
* **Q: Video is buffering or stuttering on iPhone or Apple TV?**
  * **A:** Download **Swiftfin** from the App Store instead of the standard Jellyfin app. Swiftfin uses Apple's native AVPlayer and VLC rendering engines for seamless hardware-accelerated playback.
* **Q: Can I download movies to watch offline during flights or road trips?**
  * **A:** Yes! The Jellyfin mobile app supports offline syncing for movies and TV episodes directly to your device storage.

---

## 6. Prompt to Give the `magrizzly.github.io` Agent

When opening the `magrizzly.github.io` workspace in Antigravity, paste the following prompt to have the website agent build the page:

```text
Please build a new "Media Server Hub" page at `media.html` for magrizzly.github.io, following the site's zero-dependency design system (style.css, components.css, and dark/light mode toggle).

Content & Structure:
- Reference the specifications in `PUBLIC_MEDIA_HUB_SPEC.md`.
- Include a hero section with quick-launch buttons for Jellyfin Web and Seerr.
- Include a responsive bento grid showcasing Jellyfin, Plex, Seerr, and Immich with app store download badges.
- Include an interactive FAQ accordion for common questions (troubleshooting, Swiftfin tip, quality settings).
- Update the site navigation in `index.html`, `projects.html`, `tools.html`, `notes.html`, `resources.html`, `about.html`, and `404.html` to include the new "Media" link.
- Add a feature card on `index.html`'s bento grid directing users to the new Media Hub.
```
