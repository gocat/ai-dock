# November 13 update — build 31 / 1.0.0-rc.10

- Slow connectivity now uses system orange in the menu bar, matching the panel swatch exactly. The icon-legend GIFs were regenerated with the same colour.
- Connectivity failures no longer open a modal alert. The menu-bar lamp, tooltip and panel are the only signal. The optional alert sound (off by default) keeps its five-failure, one-per-incident, 30-minute gate.
- Eleven self-test groups pass locally, including the new orange-lamp assertions.

Both changes modify previously shipped behaviour and were requested directly by the owner; they are not roadmap items. Unchanged: quota reads, probe targets, refresh timing, panel layout and ad-hoc signing.

---

# November 13 update — build 30 / 1.0.0-rc.9

- Wake from sleep refreshes quota and both connectivity checks once per wake burst, about 5 seconds after the notification so Wi-Fi/VPN can reconnect: a 10-second coalescing window merges duplicate notifications, and an in-flight manual refresh is never stacked on.
- The popover view tree is rebuilt only while it is on screen. A closed panel now updates just the menu-bar icon, tooltip and accessibility label instead of rebuilding every 30 seconds.
- The 30-second probe timer carries a 3-second tolerance so the system can coalesce wake-ups.
- `build.sh` clears bundle metadata before ad-hoc signing and retries, so managed or synced folders no longer fail intermittently with codesign's "resource fork … not allowed" error.
- GitHub Actions on `macos-26` now builds the app and runs the self-test on every push and pull request.

Ten self-test groups pass locally, including the new wake-coalescing and closed-panel assertions. Real lid-close/wake testing and the first CI run are still pending. This is not a final tag; the build remains ad-hoc signed.

---

# November 12 final daily update

Local build 29 / 1.0.0-rc.8 is the accepted end-of-day snapshot. The small in-app label is “AI Dock 1.0”; this source synchronization does not create a final release tag or signed installer.

- Left-aligned Settings/Back, balanced spacing, consistent toolbar rendering and stable clockwise refresh motion.
- Configurable local proxy launcher, opt-in launch at login, explicit bilingual language controls.
- Bounded refresh waits and subprocess cleanup; no VPN connection control.
- Current bilingual native-view showcases and eased, lightweight icon-guide GIFs (about 65/75 KB).
- Validation and remaining platform limitations: see VALIDATION.md.

---

# Local 1.0 candidate — 2026-11-12

`1.0.0-rc.8` / build 29. Awaiting owner review; not a final tag or release.

- Bounded quota/process and HTTPS waits; stop refresh feedback after completion or failure, preserve rotation phase across view rebuilds.
- Move quota progress upward; keep the fixed panel size.
- Same-position Settings/Back, explicit Language label, compact native controls and opt-in Launch at login.
- Select and remember a local proxy application; open only, no connection control. Fit long launcher labels on one line with full-name tooltips.
- See VALIDATION.md for tested and pending cases.

---

# AI Dock — 0.1.0 source snapshot

A small macOS menu-bar companion for Codex quota and independent connectivity checks.

- Codex weekly remaining quota and reset countdown.
- Independent ChatGPT / Google HTTPS response-time checks.
- Compact 270-degree gauge, monochrome mode and native panel controls.
- Fixed launchers, native SF Symbols toolbar with eased refresh/check crossfades, contained settings page and quit confirmation.
- Original black application icon with an optically centered silver glass ring and mint status dot.
- Sustained-failure reminders designed to avoid alerts for ordinary latency.

## Known limits

- Requires the installed ChatGPT-bundled Codex CLI at the documented path for quota reads, and the user's existing CLI login.
- Only Codex's reported weekly window is supported. No multi-account or other AI subscription quota support.
- HTTPS reachability does not establish proxy connectivity or a working Codex session.
- Reminder cooldown is in memory and resets on app restart.
- The current app ZIP is Apple silicon, locally ad-hoc signed, not notarized. Gatekeeper handling on a freshly downloaded Mac has not been tested; no security-bypass instructions are supplied.
- Real logged-out/expired-login, long-running sleep/wake and complete OS/appearance coverage remain pending.

Source license: MIT, Copyright (c) 2026 gocat. Source publication is authorized; no notarized binary is provided.

## 2026-11-11 development snapshot

- AI Dock naming, independent app packaging and retained local preferences.
- Codex weekly quota/reset countdown and separate ChatGPT/Google probes.
- Larger rounded launch buttons, compact action icons, quieter failure reminders.
- Settings moved into the same panel to eliminate overlapping menus.
- Native refresh arrow transitions to a check with an eased crossfade on success; partial failures remain distinct.
- Selected black application icon, silver ring, mint point and optical centering.
- Build/self-tests and ad-hoc signature checks passed; runtime and distribution limits remain in VALIDATION.md.
- P1 pool: investigate WorkBuddy and Doubao Work subscription usage integration; no integration claimed.
- Historical snapshot was private at that point; see the subsequent open-source update below.

## 2026-11-11 final private snapshot (local build 20)

- Compact 320×222 pt dashboard/settings, same-size navigation and return to dashboard after dismissal.
- Codex quota card with aligned remaining progress bar, percentage and reset countdown.
- Readable semantic foreground colors on translucent backgrounds and consistent native toolbar symbols.
- Native small settings switches; clear slow-status threshold wording; balanced network/button spacing.
- Updated synthetic-data light/dark previews and validation record.
- End-of-day synchronization requested by the user; repository stays private, no release published.

## Open-source preparation

- MIT license confirmed, copyright gocat.
- Selected dark showcase added with illustration disclosure; original rendered UI previews retained.
- Source-first distribution; no notarized app package or third-party brand assets bundled.

## Bilingual interface

- Added System / Simplified Chinese / English selection in Settings, with immediate updates and persistence.
- Localized status, countdowns, accessibility descriptions, settings and alerts; retained fixed popover dimensions.
- Added an English README and reduced the main README to the selected dark showcase only.

## Source installation

- Added a no-sudo source installer: environment checks, local build/self-test, user Applications installation, update backup and launch.
- Added copy-to-AI and one-line terminal installation at the top of both READMEs, with candid prerequisites and the reason for not offering a DMG yet.
- English README now uses an English localization of the selected dark v5 showcase.
