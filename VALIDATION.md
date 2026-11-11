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
