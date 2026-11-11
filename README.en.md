# AI Dock

[简体中文](README.md) · English

A native macOS menu bar utility for **Codex weekly quota, independent ChatGPT / Google connectivity checks, quick launchers, and quiet failure reminders**.

**Outer arc for quota. Center dot for connectivity.** A glance at the menu bar shows your remaining Codex weekly quota and the independent ChatGPT connectivity result, without opening the panel. Inspired by **iPhone duo**, the design packs the most useful information into one small icon.

## Quick install

### Ask your AI assistant

Copy this prompt to an AI assistant that can use a terminal on your Mac. A chat-only assistant can instead walk you through the commands:

> Help me install AI Dock on this Mac: https://github.com/gocat/ai-dock. Read README.en.md and install.sh first. Check macOS, Apple Command Line Tools, and the quota-reading dependency, then build from source, run self-tests, install, and open the app. Do not change my network settings, accounts, or credentials. If system tools or terminal access are missing, explain the required steps first.

### Or paste into Terminal

```sh
curl -fsSL https://raw.githubusercontent.com/gocat/ai-dock/main/install.sh | bash
```

The script downloads source from this repository, builds and tests it locally, then installs and opens the app. First installs go to `~/Applications/AI Dock.app`; rerunning updates an existing installation while retaining preferences and a backup of the old app. Quit AI Dock before updating. No `sudo` or paid developer membership is needed. You can [inspect the script](install.sh) first.

**Requires macOS 14+, Apple Command Line Tools, and Python 3.** If the compiler tools are missing, run `xcode-select --install`, finish Apple's installer, and rerun the command. The initial tool download can be large; build time depends on your Mac and network. Tested on Apple silicon; Intel is not device-tested.

Quota reads currently use the Codex CLI inside `/Applications/ChatGPT.app` and its existing login. A web account or a separately installed Codex CLI alone does not guarantee compatibility with this fixed path. Without it, quota is unavailable but network checks still work. The installer never requests credentials or changes proxy settings. The Clash launcher currently expects Clash Verge.

**Why no DMG yet?** Honestly, I don't want to pay Apple's developer membership fee for this little utility right now. Making a DMG is free; developer signing and notarization are what make distribution smoother. For now, asking your AI assistant or pasting one command to build locally is convenient enough. A chat-only AI cannot install it for you, but can guide you.

![AI Dock showcase](docs/images/showcase-dark-en.jpg)

The outer-arc examples show 100%, 50%, and 0% remaining quota. Green, amber, and red center dots mean OK, slow, and unreachable. Zero quota does not mean a network failure; unknown quota uses a dashed arc. Examples show color mode, and connectivity does not establish VPN or Codex session health.

Supports light and dark appearances. This AI-assisted showcase uses sample data and includes redrawn visual details. Application brand marks identify the launch targets; the default source build uses neutral system symbols. The showcase predates the language selector.

## Language

Open Settings and use the language menu at the top right: **System**, **简体中文**, or **English**. Changes apply immediately and are saved locally. System mode uses Chinese when the system's preferred language is Chinese, and English otherwise.

## What it does

- Shows remaining Codex weekly quota, a progress bar, and the reset countdown.
- Independently measures HTTPS response times to ChatGPT and Google.
- Opens Codex and Clash Verge; it does not change proxy settings or connect a VPN.
- Provides manual refresh, monochrome menu bar mode, an optional alert sound, and quit confirmation.
- Keeps the overview and settings at the same compact size. Reopening the popover returns to the overview.

Quota refreshes every 5 minutes; network checks run every 30 seconds. A slow result changes the status only. ChatGPT failures trigger at most one reminder per incident after 5 consecutive failures, with a 30-minute minimum interval between reminders; 3 successful checks rearm reminders. Google does not trigger pop-up alerts. Reminder state resets when the app restarts.

## Build and run

Requires macOS 14+, Apple Command Line Tools, and Python 3. Only the current Apple silicon development Mac has been device-tested.

```sh
bash build.sh
'build/AI Dock.app/Contents/MacOS/CodexCompanion' --self-test
open 'build/AI Dock.app'
```

The build is locally ad-hoc signed, not Developer ID signed or notarized. No notarized installer is provided. Build scripts regenerate the original application icon; no account credentials or network downloads are needed to compile and run self-tests.

Quota reads currently require the Codex CLI bundled at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex` and its existing authenticated account. The app invokes `app-server --stdio` and `account/rateLimits/read`; it does not read authentication files directly. The CLI account may differ from the account selected in a desktop UI. Only the reported Codex weekly window is supported. Missing or failed quota data is shown as unavailable.

The Clash launcher currently expects `/Applications/Clash Verge.app`. These fixed dependencies are not automatically installed.

## Network and privacy

| Target | Endpoint | Successful response |
| --- | --- | --- |
| ChatGPT | `https://chatgpt.com/cdn-cgi/trace` | HTTPS 200 from the same host |
| Google | `https://www.google.com/generate_204` | HTTPS 204 from the same host |

Probes use ephemeral URLSession instances without app-supplied credentials or cookies. Response bodies are discarded, not logged. Requests follow system networking and proxy rules; different hosts may take different routes. Reachability does not establish VPN connectivity or Codex session health.

Only language, latency threshold, monochrome mode, and sound preferences are stored locally. The app does not change login credentials, network settings, or startup items. This describes the app's code, not a complete traffic audit of the Codex CLI or system dependencies.

## Performance and limitations

The current schedule implies up to 240 HTTPS checks and 12 CLI launches per hour. A single idle sample showed about 57 MiB of memory and 0.0% CPU; this is not a battery-life measurement. See [performance research](PERFORMANCE.md) for proposed optimizations and the remaining validation plan.

Real expired-login cases, extended sleep/wake testing, and broader OS/architecture coverage remain pending. Multi-account, other AI providers, WorkBuddy, Doubao Work, and Windows support are future research, not shipped features. See [product scope](PRODUCT.md) and [validation](VALIDATION.md).

## License

Original project code: [MIT](LICENSE), Copyright (c) 2026 gocat. Third-party trademarks, artwork, and system symbols do not gain additional permissions through this project's license. See [third-party notes](THIRD_PARTY.md).
