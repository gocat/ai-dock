# AI Dock

[简体中文](README.md) · English

A native macOS menu bar utility for **Codex weekly quota, independent ChatGPT / Google connectivity checks, quick launchers, and quiet failure reminders**.

![AI Dock showcase](docs/images/showcase-dark.jpg)

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
