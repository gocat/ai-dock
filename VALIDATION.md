# Release candidate validation

Status: private development snapshot; no public release. Repository synchronization is authorized; distribution acceptance remains pending.

Completed on the current Apple silicon Mac:
- Default brand-free build, existing self-tests and strict ad-hoc signature verification.
- Clean build and self-tests from the exported allowlisted source ZIP, without local brand assets or generated protocol references.
- Source and both ZIPs scanned for matching private home paths/identifiers, credential-shaped strings and excluded branding; no matches after repackaging. This is a targeted scan, not a guarantee that every possible secret format is detectable.
- 20-point native gauge rendering on light and dark backgrounds, full/partial/zero/unknown quota and colored/monochrome failure indicators. Current geometry is a 270-degree track with a 90-degree bottom gap and 6-point center.
- Earlier installed edition: settings opening, refresh running/completed feedback, quit confirmation, actual quit and Finder relaunch. Name migration preserves settings and rejects duplicate instances.

- Latest installed edition: settings now replace dashboard content inside the same popover, with a working Back button. No separate settings menu can cover quota or probe labels. Existing 3000 ms threshold and sound setting remained intact.
- Automated checks cover settings control bounds, matching arrow/check path topology, and running/success/partial-failure refresh states.
- Native UI check observed refresh running and partial failure (Google unavailable); the partial failure was correctly labeled rather than reported as success. Continuous motion smoothness and live success morph still require owner review; screenshot automation does not measure frame pacing.
- Original application artwork updated to a black tile, optically centered silver glass 270-degree ring and mint status dot, inspected at full resolution.

Pending:
- Fresh public-bundle-identity installation and preference migration: the local UI automation did not resolve the new public identity. The same final executable was subsequently installed and verified under the existing local identity, preserving preferences.
- Real logged-out/expired-login, prolonged sleep/wake and long-running network failure coverage.
- Other macOS versions, Intel, fresh-download Gatekeeper behavior, Developer ID signing and notarization.
- Owner acceptance of neutral icons, repository owner/name, license/copyright attribution, release version and distribution format.

Do not describe the candidate as publicly released or fully cross-platform tested.

- Refresh follow-up: corrected checkmark orientation for AppKit layer coordinates, shifted glyph optical center and added cubic easing (0.55-second morph / 0.40-second settle). Native success-state render verified; subjective live motion remains for owner review.
- README images use synthetic values rendered from actual native view code; no live account screenshots uploaded. Energy review is in PERFORMANCE.md; only one process snapshot measured.

- Follow-up: rotate only an explicitly centered child symbol layer, never the AppKit-owned button layer. Verified native views at 0/90/180/270 degrees and fixed-center assertions after button relocation. Quota heading now reads 本周剩余.

- Rotation follow-up: one circular vector path with a known geometric center replaces SF Symbol bounding-box rotation. Arc radius invariance checked across a full turn. Color follows effective appearance; finish rotation before morph; reverse morph retained. Toolbar top/right and launcher bottom/side control margins are 16 pt.

- Compact quota panel: base content reduced from 352×264 to 320×222 pt. Visible launcher side/bottom spacing adjusted for native bezel insets; quota uses Codex title, right-aligned percentage and remaining progress bar.

- Settings redesign: fixed 320×222 pt matching dashboard, including optional quota metadata. Closure resets settingsOpen; reopening starts on dashboard. Monochrome center is white (hollow white if unknown), persistent failure red. Build and regression assertions passed. Installed build 14 process verified running; native UI automation returned noWindowsAvailable, so click-outside/reopen physical verification remains pending.

- Settings controls are native AppKit NSSwitch/NSSegmentedControl, not custom-painted. NSSwitch now uses small controlSize and sizeToFit rather than a guessed frame; rows vertically center labels and controls. Native rendered settings preview and bounds/self-tests passed; fixed 320×222 size retained. Installed local build 15; no GitHub push.

- Local visual refinement: setting header shares vertical center with back button; update cadence is a separated two-line gray note. Native small switches retained. Codex quota is a subtle rounded module; percent/countdown hierarchy reduced. Idle refresh arrow ends at circle top pointing along clockwise tangent. Native previews and self-tests checked; no GitHub sync.

- Local build 17: shared appearance-aware secondary text (light 0.42 / dark 0.72), increased progress/countdown spacing, balanced network/separator/launcher spacing. Network lamps shifted 3 pt right without moving values. Setting label now “超过多久算偏慢”; explanatory note explicitly distinguishes slow status from alerts. AppKit light/dark dashboard and settings renders inspected with synthetic data; build/self-tests and installed signature verification passed. Preserved installed bundle identity and preference keys. Attachment records were accessible but original screenshot downloads failed; no direct screenshot comparison or physical light/dark OS-switch test claimed. No GitHub sync.

- Build 18 contrast correction: user screenshot showed custom secondary gray disappearing against the real translucent popover, which opaque preview rendering had missed. Replaced the custom gray provider with semantic NSColor.labelColor; secondary hierarchy remains through font size/weight. Built/self-tests passed, installed preserving bundle identity/preferences, signature verified. CUA captured actual running dashboard and settings: percentage, countdown, service names and update notes visibly legible in the current light appearance. Returned to dashboard. Dark appearance not physically retested this round. No GitHub sync.

- Build 19: inset progress track to x18/width272 to match NSTextField's 2 pt visible text inset (including right-aligned percentage). Replaced overlapping open arrowhead with a compact filled triangle tangent to the circular arc; retained fixed circle center and bidirectional check-path animation. Build/self-tests and installed signature passed. Actual CUA screenshots checked dashboard alignment, idle arrow, running arrow, success check on opening, and return to idle after a manual refresh. Screenshots verify sampled states, not frame-by-frame animation smoothness. No GitHub sync.

- Build 20: replaced hand-drawn refresh arc/head with native SF Symbols arrow.clockwise; all toolbar symbols now use 14 pt regular and labelColor. Checkmark/failure are native symbols too; eased 0.28 s crossfades replace path morphing in both directions. Running rotation stays on an isolated image view; Reduce Motion respected. Build/self-tests and installed signature passed. Actual popover screenshots inspected during loading and idle for consistent contours/tint. No claim of frame-by-frame motion validation. No GitHub sync.

- Open-source preparation: MIT / 2026 gocat explicitly confirmed. Selected showcase v5 included as a JPEG export with AI-assisted illustration disclosure. Default source/app review packages rebuilt successfully; 25 allowlisted files scanned for private home paths, private-key headers, common credential formats and personal mail domains, no matches. Existing 10-commit history contained 34 unique text blobs; same targeted scan found no content matches. Historical commit metadata contained a personal email; owner subsequently authorized a local backup and anonymization before public visibility. These are targeted checks, not a guarantee against all secret formats.

- Build 21 bilingual UI: System / Simplified Chinese / English selection persists in UserDefaults and immediately re-renders labels, status, countdowns, tooltips and accessibility text. Cached quota errors re-localize without waiting for the next request. Both-language fixed-size layout and text-fit assertions pass without mutating saved preferences. English light/dark native previews inspected. Installed app tested through actual Settings selection to English, English overview and Quit/Cancel dialog, then restored System (Chinese) and overview. Main README now shows only the selected dark v5 showcase, with a brief light/dark statement; English README added.

- Publication preparation: full remote history backed up locally as a verified Git bundle. Main history rewritten with gocat GitHub noreply author/committer addresses. Bilingual source and English README are included; the Chinese README contains only the user-selected dark v5 illustration.

- Source installer: bash syntax and preflight passed. Actual local-source install and public-archive pipeline install completed in isolated temporary folders with --no-open; built app self-tests/signatures passed. Update test with a non-running fixture preserved the previous app backup; existing-running-app and missing-compiler branches refused safely with instructions. No real installed app was replaced or started during these tests. Intel and genuinely fresh Macs without developer tools remain untested.
- English showcase: imagegen text-localization edit of the exact approved dark v5 image; inspected English text, app glyphs, status dots, menu spacing and notch alignment. Original Chinese image retained. Each README displays one image in its corresponding language.

- Showcase state legend: color-mode quota examples 100%/50%/0% hold the green dot constant; connectivity examples hold the full arc constant and vary green/yellow/red. Compared the illustrated meanings against statusIcon/LampStyle. Unknown quota is described as dashed, distinct from zero; HTTPS probe boundaries retained. Chinese and English versions visually reviewed; no application behavior changed.
