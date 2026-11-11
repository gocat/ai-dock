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
