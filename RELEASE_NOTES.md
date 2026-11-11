# AI Dock — proposed v0.1.0-rc.1

A small macOS menu-bar companion for Codex quota and independent connectivity checks.

- Codex weekly remaining quota and reset countdown.
- Independent ChatGPT / Google HTTPS response-time checks.
- Compact 270-degree gauge, monochrome mode and native panel controls.
- Fixed launchers, rotating refresh arrow with a line-to-check transition, contained settings page and quit confirmation.
- Original black application icon with an optically centered silver glass ring and mint status dot.
- Sustained-failure reminders designed to avoid alerts for ordinary latency.

## Known limits

- Requires the installed ChatGPT-bundled Codex CLI at the documented path for quota reads, and the user's existing CLI login.
- Only Codex's reported weekly window is supported. No multi-account or other AI subscription quota support.
- HTTPS reachability does not establish proxy connectivity or a working Codex session.
- Reminder cooldown is in memory and resets on app restart.
- The current app ZIP is Apple silicon, locally ad-hoc signed, not notarized. Gatekeeper handling on a freshly downloaded Mac has not been tested; no security-bypass instructions are supplied.
- Real logged-out/expired-login, long-running sleep/wake and complete OS/appearance coverage remain pending.

Repository, license and release version are not final. This is a review draft, not a published release.

## 2026-11-11 development snapshot

- AI Dock naming, independent app packaging and retained local preferences.
- Codex weekly quota/reset countdown and separate ChatGPT/Google probes.
- Larger rounded launch buttons, compact action icons, quieter failure reminders.
- Settings moved into the same panel to eliminate overlapping menus.
- Rotating refresh arrow morphs into a check on success; partial failures remain distinct.
- Selected black application icon, silver ring, mint point and optical centering.
- Build/self-tests and ad-hoc signature checks passed; runtime and distribution limits remain in VALIDATION.md.
- P1 pool: investigate WorkBuddy and Doubao Work subscription usage integration; no integration claimed.
- Private repository synchronization authorized; no public release or license selection implied.
