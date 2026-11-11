# AI Dock release review — not published

## Proposed decisions, awaiting confirmation

- Repository name: `ai-dock`; owner/account not selected.
- License: MIT recommended for the project's own code and original icon, subject to owner confirmation. No LICENSE has been applied yet. Copyright attribution also needs confirmation.
- First public milestone: `v0.1.0-rc.1` recommended as a prerelease; version/tag not created. The bundle's numeric version is 0.1.0 (build 4).
- Distribution: start with source and local-build instructions. An optional macOS app ZIP is prepared for review, but it is ad-hoc signed, not Developer ID signed or notarized.

The current candidate uses neutral system icons instead of the unverified brand artwork in the local installed edition. The owner should approve this visible difference or provide suitable licensed brand assets before release.

## Scope

Codex weekly quota and reset countdown; independent ChatGPT/Google HTTPS checks; fixed app launchers; quiet failure reminders; settings, manual refresh and quit confirmation. Multi-AI, multi-account, configurable launchers and Windows migration are deferred without dates; they do not block the Mac release. See PRODUCT.md.

## Build and package

Requirements: macOS 14 or newer, Apple Command Line Tools with a current Swift/AppKit SDK, Python 3. Build architecture follows the host; the current reviewed artifact is Apple silicon only. macOS 14/15 and Intel have not been device-tested.

```sh
bash build.sh
bash scripts/review-package.sh
```

This is a repeatable source build, not a claim of bit-for-bit reproducibility across SDKs, architectures or code signatures. Build scripts regenerate the original app icon; no network downloads or account credentials are required to compile/test. `--diagnose` is optional, sends real requests, and prints account quota data; its output must not be included in public artifacts.

The published default bundle identifier would be `app.aidock.desktop`. Existing local installations may override the bundle ID for private builds to preserve their preference domain. Moving to the public ID requires an explicit settings-migration decision; the candidate does not silently read another preference domain.

## Current verification

See [VALIDATION.md](VALIDATION.md) for completed checks and explicit gaps. The settings placement fix is included; the current screen was tested without covering the quota/probe/launch content.

## Release gates

- [ ] Owner accepts the visual/interaction candidate.
- [ ] Owner confirms repository owner/name, license/copyright attribution and tag/version.
- [ ] Add the confirmed license and repeat staged-file/package scans.
- [ ] Confirm documented dependencies/OS support, and select source-only versus unsigned/notarized binary distribution.
- [ ] Create a reviewed commit; verify no private identity in commit author metadata.
- [ ] Only then create/push the separate repository and create the explicitly approved release.

No remote repository, push, tag or public release is authorized by this review document. Other projects/repositories are outside scope.
