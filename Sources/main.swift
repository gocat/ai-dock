import AppKit
import Foundation
import QuartzCore

// Semantic foreground stays legible in the popover's vibrant material.
// Secondary hierarchy comes from type size and weight, not a low-contrast gray.
extension NSColor {
    static var aidockSecondary: NSColor { .labelColor }
}

struct QuotaSnapshot {
    var lines: [String]
    var weeklyRemaining: Double? = nil
    var resetsAt: Date? = nil
    var resetCredits: Int? = nil
    var ordinaryUsageAllowed: Bool? = nil
}
struct Quota {
    // Only the Codex weekly window belongs in this icon, never another model's bucket.
    static func weeklyWindow(_ result: [String: Any]) -> [String: Any]? {
        let buckets = result["rateLimitsByLimitId"] as? [String: [String: Any]]
        let legacy = result["rateLimits"] as? [String: Any]
        let legacyIsCodex = (legacy?["limitId"] as? String).map { $0 == "codex" } ?? true
        let bucket = buckets?["codex"] ?? (legacyIsCodex ? legacy : nil)
        for kind in ["primary", "secondary"] {
            if let w = bucket?[kind] as? [String: Any], w["windowDurationMins"] as? Int == 10080 { return w }
        }
        return nil
    }
    static func weeklyRemaining(_ result: [String: Any]) -> Double? {
        guard let used = weeklyWindow(result)?["usedPercent"] as? Double, used.isFinite else { return nil }
        return max(0, min(1, (100 - used) / 100))
    }
    static func snapshot(_ result: [String: Any]) -> QuotaSnapshot {
        let reset = weeklyWindow(result)?["resetsAt"] as? Double
        let credits = (result["rateLimitResetCredits"] as? [String: Any])?["availableCount"] as? Int
        return QuotaSnapshot(lines: lines(result), weeklyRemaining: weeklyRemaining(result),
            resetsAt: reset.flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0) : nil },
            resetCredits: credits.flatMap { $0 > 0 ? $0 : nil },
            ordinaryUsageAllowed: result["ordinaryUsageAllowed"] as? Bool)
    }
    static func countdown(_ reset: Date?, now: Date = Date()) -> String {
        guard let reset = reset else { return "重置时间未知" }
        let seconds = reset.timeIntervalSince(now)
        guard seconds > 0 else { return "重置时间已到，等待同步" }
        if seconds < 3600 { return "距重置不足 1 小时" }
        let hours = Int(seconds / 3600)
        return "距重置 \(hours / 24) 天 \(hours % 24) 小时"
    }
    static func lines(_ result: [String: Any]) -> [String] {
        let buckets = result["rateLimitsByLimitId"] as? [String: [String: Any]] ?? ["codex": result["rateLimits"] as? [String: Any] ?? [:]]
        var lines: [String] = []
        for key in buckets.keys.sorted() {
            for kind in ["primary", "secondary"] {
                guard let w = buckets[key]?[kind] as? [String: Any], let used = w["usedPercent"] as? Double, used.isFinite else { continue }
                let mins = w["windowDurationMins"] as? Int
                let label = mins == 10080 ? "周额度" : mins == 300 ? "5 小时额度" : mins.map { "\($0) 分钟额度" } ?? "额度"
                lines.append("\(key) \(label)：剩余 \(Int(max(0, min(100, 100-used))))%")
                if let reset = w["resetsAt"] as? Double {
                    let f = DateFormatter(); f.dateFormat = "M/d HH:mm"; lines.append("重置：\(f.string(from: Date(timeIntervalSince1970: reset)))（本地时间）")
                }
            }
        }
        if result["ordinaryUsageAllowed"] as? Bool == false { lines.append("服务端提示：常规额度暂不可用") }
        return lines.isEmpty ? ["当前账户未提供额度数据"] : lines
    }
}
func run(_ path: String, _ args: [String], timeout: Double = 10) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return (-1, "") }
    let timer = DispatchWorkItem { if p.isRunning { p.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now()+timeout, execute: timer)
    let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit(); timer.cancel()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}
func fetchQuota() -> QuotaSnapshot {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex")
    p.arguments = ["app-server", "--stdio"]
    let input = Pipe(), output = Pipe(); p.standardInput = input; p.standardOutput = output; p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return QuotaSnapshot(lines: ["未找到 Codex CLI"]) }
    let timer = DispatchWorkItem { if p.isRunning { p.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now()+25, execute: timer)
    defer { timer.cancel(); if p.isRunning { p.terminate() }; try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close() }
    func send(_ value: [String: Any]) { if let data = try? JSONSerialization.data(withJSONObject: value) { try? input.fileHandleForWriting.write(contentsOf: data + Data([10])) } }
    send(["id":1,"method":"initialize","params":["clientInfo":["name":"codex_companion","version":"0.1.0"],"capabilities":NSNull()]])
    var pending = Data()
    while p.isRunning {
        let data = output.fileHandleForReading.availableData
        if data.isEmpty { break }; pending.append(data)
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline); pending.removeSubrange(...newline)
            guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any], let id = obj["id"] as? Int else { continue }
            if obj["error"] != nil { return QuotaSnapshot(lines: ["额度读取失败，请检查 Codex 登录和网络"]) }
            if id == 1 { send(["method":"initialized"]); send(["id":2,"method":"account/rateLimits/read","params":["excludeResetCreditDetails":true]]) }
            if id == 2, let result = obj["result"] as? [String: Any] { return Quota.snapshot(result) }
        }
    }
    return QuotaSnapshot(lines: ["额度读取超时，请检查 Codex 登录和网络"])
}
// No auth, cookies, local proxy config or session data are used for this probe.
// URLSession follows the system networking configuration; no proxy settings are changed.
enum ProbeTarget: CaseIterable {
    case chatGPT, google
    var name: String { self == .chatGPT ? "ChatGPT" : "Google" }
    var url: URL { URL(string: self == .chatGPT ? "https://chatgpt.com/cdn-cgi/trace" : "https://www.google.com/generate_204")! }
    var expectedStatus: Int { self == .chatGPT ? 200 : 204 }
    func accepts(_ response: HTTPURLResponse) -> Bool {
        response.statusCode == expectedStatus && response.url?.scheme == "https" && response.url?.host == url.host
    }
}
func probe(_ target: ProbeTarget = .chatGPT) -> Int? {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 8; config.timeoutIntervalForResource = 10
    config.httpCookieStorage = nil; config.urlCredentialStorage = nil
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: target.url)
    request.httpMethod = "GET"; request.cachePolicy = .reloadIgnoringLocalCacheData
    let semaphore = DispatchSemaphore(value: 0)
    let start = Date(); var milliseconds: Int?
    session.dataTask(with: request) { _, response, error in
        if error == nil, let response = response as? HTTPURLResponse,
           target.accepts(response) {
            // Validate the target response. Discard the body; never log or save it.
            milliseconds = Int(Date().timeIntervalSince(start) * 1000)
        }
        semaphore.signal()
    }.resume()
    guard semaphore.wait(timeout: .now()+12) == .success else { return nil }
    return milliseconds
}
struct FailureReminder {
    var failures = 0
    var successes = 0
    var notified = false
    var lastAlert = Date.distantPast
    mutating func record(reachable: Bool, now: Date = Date()) -> Bool {
        if reachable {
            failures = 0
            successes += 1
            if successes >= 3 { notified = false }
            return false
        }
        successes = 0
        failures += 1
        guard failures >= 5, !notified, now.timeIntervalSince(lastAlert) >= 1800 else { return false }
        notified = true
        lastAlert = now
        return true
    }
}
enum ProbeState: Equatable {
    case unknown, normal, slow, failed
    static func state(checked: Bool, latency: Int?, threshold: Int) -> ProbeState {
        guard checked else { return .unknown }
        guard let latency = latency else { return .failed }
        return latency > threshold ? .slow : .normal
    }
    var color: NSColor {
        switch self {
        case .unknown: return .aidockSecondary
        case .normal: return .systemGreen
        case .slow: return .systemYellow
        case .failed: return .systemRed
        }
    }
}
enum LampStyle: Equatable {
    case hollow, white, neutral, green, yellow, red
    static func resolve(state: ProbeState, monochrome: Bool, persistentFailure: Bool) -> LampStyle {
        if monochrome {
            if state == .unknown { return .hollow }
            return state == .failed && persistentFailure ? .red : .white
        }
        switch state {
        case .unknown: return .neutral
        case .normal: return .green
        case .slow: return .yellow
        case .failed: return .red
        }
    }
    var color: NSColor {
        switch self {
        case .hollow, .white: return .white
        case .neutral: return .aidockSecondary
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .red: return .systemRed
        }
    }
}
func persistentProbeFailure(_ failures: [Bool]) -> Bool {
    failures.count >= 2 && failures.suffix(2).allSatisfy { $0 }
}
func statusIcon(remaining: Double?, state: ProbeState, monochrome: Bool = false, persistentFailure: Bool = false) -> NSImage {
    let lamp = LampStyle.resolve(state: state, monochrome: monochrome, persistentFailure: persistentFailure)
    let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
        let ring = NSBezierPath()
        ring.appendArc(withCenter: NSPoint(x: 10, y: 10), radius: 8, startAngle: 225, endAngle: -45, clockwise: true)
        ring.lineWidth = 2; ring.lineCapStyle = .round
        NSColor.labelColor.withAlphaComponent(remaining == nil ? 0.5 : 0.2).setStroke()
        if remaining == nil { ring.setLineDash([1.5, 2], count: 2, phase: 0) }
        ring.stroke()
        if let remaining = remaining, remaining > 0 {
            NSColor.labelColor.withAlphaComponent(0.95).setStroke()
            let arc = NSBezierPath(); arc.lineWidth = 2; arc.lineCapStyle = .round
            arc.appendArc(withCenter: NSPoint(x: 10, y: 10), radius: 8,
                          startAngle: 225, endAngle: 225 - CGFloat(min(1, remaining) * 270), clockwise: true)
            arc.stroke()
        }
        let light = NSBezierPath(ovalIn: NSRect(x: 7, y: 7, width: 6, height: 6))
        if lamp == .hollow {
            lamp.color.setStroke(); light.lineWidth = 1; light.stroke()
        } else {
            lamp.color.setFill(); light.fill()
            NSColor.labelColor.withAlphaComponent(0.3).setStroke(); light.lineWidth = 0.5; light.stroke()
        }
        return true
    }
    image.isTemplate = false // Preserve the green/yellow/red lamp.
    return image
}
func probeLabel(_ name: String, checked: Bool, latency: Int?, threshold: Int) -> String {
    guard checked else { return "●  \(name)  — · 检测中" }
    guard let latency = latency else { return "●  \(name)  — · 未连通" }
    return "●  \(name)  \(latency) ms · \(latency > threshold ? "偏慢" : "正常")"
}
final class RefreshGlyphButton: NSButton {
    enum Phase { case idle, running, success, failure }
    private let glyph = NSImageView(frame:NSRect(x:0,y:0,width:32,height:32))
    private var phase: Phase = .idle
    override init(frame:NSRect) {
        super.init(frame:frame)
        title="";isBordered=false;wantsLayer=true
        glyph.imageScaling = .scaleNone
        glyph.wantsLayer=true
        addSubview(glyph)
        update(.idle)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unsupported") }
    func hasFixedRotationCenter()->Bool {
        glyph.frame.size == NSSize(width:32,height:32) && CATransform3DIsIdentity(layer!.transform)
    }
    func update(_ next:Phase) {
        let name = next == .success ? "checkmark" : next == .failure ? "exclamationmark.circle" : "arrow.clockwise"
        let symbol=NSImage(systemSymbolName:name,accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:14,weight:.regular))
        glyph.contentTintColor = .labelColor
        isEnabled = next != .running
        let text = next == .running ? "正在刷新" : next == .success ? "刷新完成" : next == .failure ? "刷新完成，部分数据未获取" : "刷新额度与连接状态"
        toolTip=text;setAccessibilityLabel(text)
        guard next != phase || glyph.image == nil else { return }
        let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        glyph.layer?.removeAllAnimations()
        CATransaction.begin();CATransaction.setDisableActions(true)
        glyph.layer?.transform=CATransform3DIdentity
        glyph.image=symbol
        CATransaction.commit()
        // Native symbols retain their exact contours in both directions.
        if !reduce && next != .running {
            let transition=CATransition()
            transition.type = .fade;transition.duration=0.28
            transition.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut)
            glyph.layer?.add(transition,forKey:"symbolTransition")
        }
        if !reduce && next == .running {
            let spin=CABasicAnimation(keyPath:"transform.rotation.z")
            spin.fromValue=0;spin.toValue=2*Double.pi
            spin.duration=1.1;spin.repeatCount = .infinity
            spin.timingFunction=CAMediaTimingFunction(name:.linear)
            glyph.layer?.add(spin,forKey:"rotation")
        }
        phase=next
    }
}
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {
    var status: NSStatusItem!; var timer: Timer?
    let popover = NSPopover()
    var manualRefresh = false
    var refreshFinished: Date?
    var refreshHadFailure = false
    var settingsOpen = false
    let refreshGlyph = RefreshGlyphButton(frame:NSRect(x:0,y:0,width:32,height:32))
    var snapshot = QuotaSnapshot(lines: ["额度读取中…"]); var weeklyRemaining: Double?; var appearanceObserver: NSKeyValueObservation?
    var quota = ["额度读取中…"], latency: Int?, checked = false, quotaBusy = false, probeBusy = false
    var googleLatency: Int?, googleChecked = false, googleBusy = false
    var recentFailures: [Bool] = []; var reminder = FailureReminder(); var launcherError: String?
    var monochrome: Bool { UserDefaults.standard.bool(forKey: "monochromeIcon") }
    var threshold: Int { let n = UserDefaults.standard.integer(forKey: "threshold"); return n == 0 ? 3000 : n }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the existing bundle ID and preference domain across the display-name migration.
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSWorkspace.shared.runningApplications.first(where: { ($0.bundleIdentifier == bundleID || $0.executableURL?.lastPathComponent == "CodexCompanion") && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appearanceObserver = status.button?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.refreshMenu()
        }
        status.button?.target = self
        status.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSViewController()
        refreshMenu(); refresh()
        DispatchQueue.main.async { if !self.popover.isShown { self.togglePanel() } }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.checkProxy(); self?.checkGoogle() }
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.checkQuota() }.tolerance = 15
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePanel() }
        return true
    }
    func item(_ title: String, _ action: Selector? = nil) -> NSMenuItem { let i = NSMenuItem(title:title,action:action,keyEquivalent:"");i.target=self;return i }
    func refreshMenu() {
        let state = ProbeState.state(checked: checked, latency: latency, threshold: threshold)
        let weeklyText = weeklyRemaining.map { "Codex 周额度剩余 \(Int(($0 * 100).rounded()))%" } ?? "Codex 周额度未知"
        let probeText = checked ? latency.map { "ChatGPT HTTPS 探测：\($0) ms\($0 > threshold ? "（偏慢）" : "（正常）")" } ?? "ChatGPT HTTPS 探测失败" : "ChatGPT HTTPS 探测尚未完成"
        status.button?.title = ""
        status.button?.image = statusIcon(remaining: weeklyRemaining, state: state, monochrome: monochrome, persistentFailure: persistentProbeFailure(recentFailures))
        status.button?.imagePosition = .imageOnly
        let description = "\(weeklyText)；\(probeText)；\(probeLabel("Google", checked: googleChecked, latency: googleLatency, threshold: threshold))。HTTPS 请求耗时，不代表 Codex 会话或 VPN 连接状态。"
        status.button?.toolTip = description
        status.button?.setAccessibilityLabel(description)
        if manualRefresh && !quotaBusy && !probeBusy && !googleBusy {
            manualRefresh = false
            refreshFinished = Date()
            refreshHadFailure = weeklyRemaining == nil || latency == nil || googleLatency == nil
            let completion = refreshFinished
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, !self.manualRefresh, self.refreshFinished == completion else { return }
                self.refreshFinished = nil
                self.refreshMenu()
            }
        }
        if settingsOpen {
            let view = settingsView()
            popover.contentViewController?.view = view
            popover.contentSize = view.frame.size
            return
        }
        let dashboard = dashboardView(state: state)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: dashboard.frame.height + 56))
        dashboard.setFrameOrigin(NSPoint(x: 6, y: 56))
        root.addSubview(dashboard)
        let line = NSBox(frame: NSRect(x: 12, y: 62, width: 296, height: 1))
        line.boxType = .separator
        root.addSubview(line)
        let launchers = launcherView()
        launchers.setFrameOrigin(NSPoint(x: 6, y: 4))
        root.addSubview(launchers)
        popover.contentViewController?.view = root
        popover.contentSize = root.frame.size
    }
    @objc func togglePanel() {
        if popover.isShown { popover.performClose(nil); return }
        settingsOpen = false
        refreshMenu()
        if let button = status.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    func popoverDidClose(_ notification: Notification) { settingsOpen = false }
    @objc func openSettings(_ sender: NSButton) { settingsOpen = true; refreshMenu() }
    @objc func closeSettings() { settingsOpen = false; refreshMenu() }
    @objc func setThresholdChoice(_ sender: NSSegmentedControl) {
        let choices = [1000,2000,3000,5000]
        guard choices.indices.contains(sender.selectedSegment) else { return }
        UserDefaults.standard.set(choices[sender.selectedSegment],forKey:"threshold")
        refreshMenu()
    }
    func settingsView() -> NSView {
        let view = NSView(frame:NSRect(x:0,y:0,width:320,height:222))
        let back = NSButton(image:NSImage(systemSymbolName:"chevron.left",accessibilityDescription:"返回")!,target:self,action:#selector(closeSettings))
        back.isBordered=false;back.contentTintColor = .aidockSecondary
        back.frame=NSRect(x:8,y:178,width:32,height:32)
        back.toolTip="返回首页";back.setAccessibilityLabel("返回首页");view.addSubview(back)
        func text(_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ size:CGFloat = 12)->NSTextField {
            let label=NSTextField(labelWithString:title)
            label.font = .systemFont(ofSize:size)
            label.frame=NSRect(x:x,y:y,width:width,height:22)
            view.addSubview(label);return label
        }
        let title=text("设置",44,182,220,14);title.font = .systemFont(ofSize:14,weight:.semibold)
        title.sizeToFit();title.setFrameOrigin(NSPoint(x:44,y:194-title.frame.height/2))
        func toggleRow(_ title:String,_ centerY:CGFloat,_ state:NSControl.StateValue,_ action:Selector) {
            let label=text(title,16,0,224)
            label.sizeToFit();label.setFrameOrigin(NSPoint(x:16,y:centerY-label.frame.height/2))
            let toggle=NSSwitch()
            toggle.controlSize = .small
            toggle.sizeToFit()
            toggle.setFrameOrigin(NSPoint(x:304-toggle.frame.width,y:centerY-toggle.frame.height/2))
            toggle.target=self;toggle.action=action;toggle.state=state
            toggle.setAccessibilityLabel(title)
            view.addSubview(toggle)
        }
        toggleRow("单色菜单栏图标",153,monochrome ? .on : .off,#selector(toggleMonochrome))
        toggleRow("异常提示音",117,UserDefaults.standard.bool(forKey:"sound") ? .on : .off,#selector(toggleSound))
        let separator=NSBox(frame:NSRect(x:16,y:96,width:288,height:1));separator.boxType = .separator;view.addSubview(separator)
        let thresholdLabel = text("超过多久算偏慢",16,66,108)
        thresholdLabel.sizeToFit();thresholdLabel.setFrameOrigin(NSPoint(x:16,y:76-thresholdLabel.frame.height/2))
        let choices=NSSegmentedControl(labels:["1 秒","2 秒","3 秒","5 秒"],trackingMode:.selectOne,target:self,action:#selector(setThresholdChoice(_:)))
        choices.controlSize = .small
        choices.font = .systemFont(ofSize:11)
        choices.frame=NSRect(x:128,y:66,width:176,height:20)
        choices.selectedSegment=[1000,2000,3000,5000].firstIndex(of:threshold) ?? 2
        choices.setAccessibilityLabel("延迟超过所选时间时显示偏慢")
        choices.toolTip="仅改变偏慢状态标识，不触发弹窗提醒";view.addSubview(choices)
        let noteTitle=text("超过所选时间仅标为偏慢，不弹窗",16,37,288,10)
        noteTitle.textColor = .aidockSecondary
        let note=text("自动更新：额度 5 分钟 · 网络状态 30 秒",16,13,288,10)
        note.textColor = .aidockSecondary
        return view
    }
    func dashboardView(state: ProbeState) -> NSView {
        let height:CGFloat = 166
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 308, height: height))
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ size: CGFloat, _ color: NSColor = .labelColor, _ weight: NSFont.Weight = .regular) -> NSTextField {
            let field = NSTextField(labelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = color
            field.frame = NSRect(x: x, y: y, width: width, height: 24)
            view.addSubview(field)
            return field
        }
        _ = label("AI Dock", 6, height - 46, 198, 10, .aidockSecondary)
        let quotaCard=NSView(frame:NSRect(x:6,y:54,width:296,height:70))
        quotaCard.wantsLayer=true;quotaCard.layer?.cornerRadius=10
        quotaCard.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.045).cgColor
        view.addSubview(quotaCard)
        _ = label("Codex", 16, height - 74, 180, 13, .labelColor, .semibold)
        let percentage = label(weeklyRemaining.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", 214, height - 74, 78, 12, .aidockSecondary)
        percentage.alignment = .right
        percentage.setAccessibilityLabel(weeklyRemaining.map { "Codex 本周剩余额度 \(Int(($0 * 100).rounded()))%" } ?? "Codex 本周额度不可用")
        let track = NSView(frame:NSRect(x:18,y:82,width:272,height:6))
        track.wantsLayer = true
        track.layer?.cornerRadius = 3
        track.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        track.layer?.masksToBounds = true
        track.toolTip = "Codex 本周剩余额度；不是已用额度"
        if let remaining = weeklyRemaining {
            let fill = NSView(frame:NSRect(x:0,y:0,width:272 * min(1,max(0,remaining)),height:6))
            fill.wantsLayer = true
            fill.layer?.cornerRadius = 3
            fill.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            track.addSubview(fill)
        }
        view.addSubview(track)
        let quotaDetail = weeklyRemaining == nil
            ? (quotaBusy ? "正在读取 Codex 额度…" : (snapshot.lines.first ?? "当前账户未提供周额度"))
            : Quota.countdown(snapshot.resetsAt)
        var details = [quotaDetail]
        if let credits=snapshot.resetCredits { details.append("可用重置 \(credits) 次") }
        if snapshot.ordinaryUsageAllowed == false { details.insert("常规额度暂不可用",at:0) }
        let detail = label(details.joined(separator:" · "),16,54,276,10,.aidockSecondary)
        detail.lineBreakMode = .byTruncatingTail
        detail.toolTip = details.joined(separator:"\n")
        detail.setAccessibilityLabel(details.joined(separator:"；"))
        let targets: [(String, Bool, Int?, Bool)] = [("ChatGPT", checked, latency, probeBusy), ("Google", googleChecked, googleLatency, googleBusy)]
        for (index, target) in targets.enumerated() {
            let x = CGFloat(6 + index * 152)
            let current = ProbeState.state(checked: target.1, latency: target.2, threshold: threshold)
            _ = label(target.0, x, 24, 144, 11, .aidockSecondary, .medium)
            let swatch = NSView(frame: NSRect(x: x + 3, y: 19, width: 7, height: 14))
            swatch.wantsLayer = true
            swatch.layer?.cornerRadius = 3.5
            swatch.layer?.backgroundColor = (current == .slow ? NSColor.systemOrange : current.color).cgColor
            view.addSubview(swatch)
            let value = target.3 ? "检测中…" : !target.1 ? "等待检测" : target.2.map { "\($0) ms · \($0 > threshold ? "偏慢" : "正常")" } ?? "— · 未连通"
            let result = label(value, x + 15, 9, 129, 12)
            result.toolTip = "独立 HTTPS 请求耗时，沿系统网络和当前代理规则访问；不同域名可能走不同路由。可达不代表 VPN 已连接或 Codex 会话正常。"
        }

        let actions: [(String, String, Selector)] = [
            ("arrow.clockwise", "刷新额度与连接状态", #selector(refresh)),
            ("gearshape", "设置", #selector(openSettings(_:))),
            ("power", "退出 AI Dock", #selector(quit))
        ]
        for (index, action) in actions.enumerated() {
            if index == 0 {
                refreshGlyph.target = self; refreshGlyph.action = action.2
                refreshGlyph.frame = NSRect(x:206,y:Int(height)-44,width:32,height:32)
                let phase: RefreshGlyphButton.Phase = manualRefresh ? .running : refreshFinished != nil ? (refreshHadFailure ? .failure : .success) : .idle
                refreshGlyph.update(phase)
                view.addSubview(refreshGlyph)
                continue
            }
            let button = NSButton(image:NSImage(systemSymbolName:action.0,accessibilityDescription:action.1)!,target:self,action:action.2)
            button.isBordered = false; button.contentTintColor = .aidockSecondary
            button.image = button.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:14,weight:.regular))
            button.imagePosition = .imageOnly; button.imageScaling = .scaleNone
            button.frame = NSRect(x:206+index*32,y:Int(height)-44,width:32,height:32)
            button.toolTip = action.1; button.setAccessibilityLabel(action.1)
            view.addSubview(button)
        }
        return view
    }
    func launcherView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 308, height: 52))
        let entries: [(String, String, Selector)] = [
            ("打开 Codex", "terminal", #selector(openCodex)),
            ("打开 Clash", "lock.shield", #selector(openClash))
        ]
        for (index, entry) in entries.enumerated() {
            let button = NSButton(title: entry.0, target: self, action: entry.2)
            button.bezelStyle = .push
            if #available(macOS 26.0, *) { button.controlSize = .extraLarge }
            else { button.controlSize = .large }
            button.isBordered = true
            button.font = .systemFont(ofSize: 13, weight: .medium)
            let resource = index == 0 ? "CodexMono" : "ClashMono"
            if let iconURL = Bundle.main.url(forResource: resource, withExtension: "svg"), let icon = NSImage(contentsOf: iconURL) {
                icon.size = NSSize(width: 20, height: 20)
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: index == 0 ? "terminal" : "lock.shield", accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular))
            }
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.frame = NSRect(x: 6 + index * 152, y: 6, width: 144, height: 40)
            button.setAccessibilityLabel(entry.0)
            view.addSubview(button)
        }
        return view
    }
    @objc func setThreshold(_ sender: NSMenuItem) { UserDefaults.standard.set(sender.tag,forKey:"threshold");refreshMenu() }
    @objc func toggleMonochrome() { UserDefaults.standard.set(!monochrome, forKey: "monochromeIcon"); refreshMenu() }
    @objc func toggleSound() { UserDefaults.standard.set(!UserDefaults.standard.bool(forKey:"sound"),forKey:"sound");refreshMenu() }
    @objc func refresh() {
        manualRefresh = true
        checkQuota(); checkProxy(); checkGoogle()
        refreshMenu()
    }
    func checkQuota() { guard !quotaBusy else{return};quotaBusy=true
        DispatchQueue.global(qos:.utility).async { let result=fetchQuota();DispatchQueue.main.async { self.snapshot=result;self.quota=result.lines;self.weeklyRemaining=result.weeklyRemaining;self.quotaBusy=false;self.refreshMenu() } }
    }
    func checkProxy() { guard !probeBusy else{return};probeBusy=true
        DispatchQueue.global(qos:.utility).async { let value=probe();DispatchQueue.main.async {
            self.latency=value;self.checked=true;self.probeBusy=false
            self.recentFailures.append(value == nil);self.recentFailures=Array(self.recentFailures.suffix(10))
            if self.reminder.record(reachable: value != nil) {
                if UserDefaults.standard.bool(forKey:"sound") { NSSound.beep() }
                let alert=NSAlert();alert.messageText="ChatGPT HTTPS 探测异常";alert.informativeText="连续 5 次未能连通测试地址，请检查网络或 Clash。\n\n同一轮故障只提醒一次；此结果不代表 Codex 会话已断开。"
                alert.addButton(withTitle:"知道了");alert.alertStyle = .warning;alert.window.level = .floating
                alert.runModal()
            };self.refreshMenu()
        } }
    }
    func checkGoogle() {
        guard !googleBusy else { return }
        googleBusy = true
        DispatchQueue.global(qos: .utility).async {
            let value = probe(.google)
            DispatchQueue.main.async {
                self.googleLatency = value
                self.googleChecked = true
                self.googleBusy = false
                self.refreshMenu()
            }
        }
    }
    @objc func openCodex() {
        popover.performClose(nil)
        launcherError = NSWorkspace.shared.open(URL(string: "codex://")!) ? nil : "无法打开 Codex"
        refreshMenu()
    }
    @objc func openClash() {
        popover.performClose(nil)
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Clash Verge.app"), configuration: config) { _, error in
            DispatchQueue.main.async { self.launcherError = error == nil ? nil : "无法打开 Clash，请检查安装"; self.refreshMenu() }
        }
    }
    @objc func quit() {
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = "退出 AI Dock？"
        alert.informativeText = "退出后将停止额度和连接状态检测。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "退出")
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { NSApp.terminate(nil) }
        else { togglePanel() }
    }
}
if CommandLine.arguments.contains("--self-test") {
    let _ = NSApplication.shared
    let fixture = App()
    let settings = fixture.settingsView()
    precondition(settings.subviews.allSatisfy { settings.bounds.contains($0.frame) })
    precondition(settings.frame.size == NSSize(width:320,height:222))
    precondition(fixture.dashboardView(state:.normal).frame.height+56 == settings.frame.height)
    fixture.snapshot.resetCredits=2;fixture.snapshot.ordinaryUsageAllowed=false
    precondition(fixture.dashboardView(state:.normal).frame.height+56 == settings.frame.height)
    fixture.settingsOpen=true
    fixture.popoverDidClose(Notification(name:NSPopover.didCloseNotification))
    precondition(!fixture.settingsOpen)
    fixture.refreshGlyph.update(.running)
    precondition(!fixture.refreshGlyph.isEnabled && fixture.refreshGlyph.hasFixedRotationCenter())
    fixture.refreshGlyph.frame.origin = NSPoint(x:220,y:118)
    fixture.refreshGlyph.update(.running)
    precondition(fixture.refreshGlyph.hasFixedRotationCenter())
    fixture.refreshGlyph.update(.success)
    precondition(fixture.refreshGlyph.isEnabled && fixture.refreshGlyph.toolTip == "刷新完成")
    fixture.refreshGlyph.update(.failure)
    precondition(fixture.refreshGlyph.toolTip!.contains("部分数据"))
    print("PASS: native symbols, contained settings controls, refresh running/success/failure states")
    for target in ProbeTarget.allCases {
        precondition(target.accepts(HTTPURLResponse(url: target.url, statusCode: target.expectedStatus, httpVersion: nil, headerFields: nil)!))
        precondition(!target.accepts(HTTPURLResponse(url: target.url, statusCode: 403, httpVersion: nil, headerFields: nil)!))
        precondition(!target.accepts(HTTPURLResponse(url: URL(string: "https://example.com/")!, statusCode: target.expectedStatus, httpVersion: nil, headerFields: nil)!))
    }
    precondition(probeLabel("ChatGPT", checked: true, latency: 5000, threshold: 3000).contains("偏慢"))
    precondition(probeLabel("Google", checked: true, latency: 100, threshold: 3000).contains("正常"))
    precondition(probeLabel("Google", checked: true, latency: nil, threshold: 3000).contains("未连通"))
    precondition(probeLabel("Google", checked: false, latency: nil, threshold: 3000).contains("检测中"))
    print("PASS: independent target response validation and compact per-target status labels")
    let w:[String:Any] = ["usedPercent":19.0,"windowDurationMins":10080,"resetsAt":1794882500.0]
    precondition(Quota.lines(["rateLimits":["primary":w]])[0].contains("81%"))
    precondition(Quota.lines([:]) == ["当前账户未提供额度数据"])
    precondition(Quota.lines(["rateLimits":["primary":["usedPercent":140.0]]])[0].contains("0%"))
    precondition(Quota.lines(["ordinaryUsageAllowed":false]).contains("服务端提示：常规额度暂不可用"))
    var reminder = FailureReminder()
    let testTime = Date(timeIntervalSince1970: 10000)
    for _ in 0..<20 { precondition(!reminder.record(reachable: true, now: testTime)) }
    for _ in 0..<4 { precondition(!reminder.record(reachable: false, now: testTime)) }
    precondition(reminder.record(reachable: false, now: testTime))
    precondition(!reminder.record(reachable: false, now: testTime.addingTimeInterval(3600)))
    for _ in 0..<2 { precondition(!reminder.record(reachable: true, now: testTime)) }
    for _ in 0..<5 { precondition(!reminder.record(reachable: false, now: testTime.addingTimeInterval(3600))) }
    for _ in 0..<3 { precondition(!reminder.record(reachable: true, now: testTime)) }
    for _ in 0..<5 { precondition(!reminder.record(reachable: false, now: testTime.addingTimeInterval(100))) }
    precondition(reminder.record(reachable: false, now: testTime.addingTimeInterval(1800)))
    print("PASS: reachable/slow never alerts; five failures, one reminder per incident, three-success recovery, 30-minute cooldown")
    precondition(Quota.weeklyRemaining(["rateLimits": ["secondary": w]]) == 0.81)
    precondition(Quota.weeklyRemaining([:]) == nil)
    precondition(Quota.weeklyRemaining(["rateLimits": ["primary": ["usedPercent": 20.0, "windowDurationMins": 300]]]) == nil)
    precondition(Quota.weeklyRemaining(["rateLimitsByLimitId": ["other": ["secondary": w]]]) == nil)
    precondition(Quota.weeklyRemaining(["rateLimits": ["limitId": "other", "secondary": w]]) == nil)
    for (used, expected) in [(100.0, 0.0), (140.0, 0.0), (-10.0, 1.0), (0.0, 1.0)] {
        precondition(Quota.weeklyRemaining(["rateLimits": ["primary": ["usedPercent": used, "windowDurationMins": 10080] as [String: Any]]]) == expected)
    }
    precondition(Quota.weeklyRemaining(["rateLimits": ["primary": ["usedPercent": Double.nan, "windowDurationMins": 10080]]]) == nil)
    precondition(ProbeState.state(checked: false, latency: nil, threshold: 3000) == .unknown)
    precondition(ProbeState.state(checked: true, latency: nil, threshold: 3000) == .failed)
    precondition(ProbeState.state(checked: true, latency: 3000, threshold: 3000) == .normal)
    precondition(ProbeState.state(checked: true, latency: 3001, threshold: 3000) == .slow)
    let now = Date(timeIntervalSince1970: 1000)
    precondition(Quota.countdown(now.addingTimeInterval(49 * 3600), now: now) == "距重置 2 天 1 小时")
    precondition(Quota.countdown(now.addingTimeInterval(60), now: now) == "距重置不足 1 小时")
    precondition(Quota.countdown(now, now: now).contains("等待同步"))
    precondition(Quota.snapshot([:]).resetCredits == nil)
    precondition(Quota.snapshot(["rateLimitResetCredits": ["availableCount": 0]]).resetCredits == nil)
    precondition(Quota.snapshot(["rateLimitResetCredits": ["availableCount": 2]]).resetCredits == 2)
    precondition(!persistentProbeFailure([]))
    precondition(!persistentProbeFailure([true]))
    precondition(!persistentProbeFailure([true, false, true]))
    precondition(persistentProbeFailure([false, true, true]))
    precondition(!persistentProbeFailure([true, true, false]))
    precondition(LampStyle.resolve(state: .unknown, monochrome: true, persistentFailure: false) == .hollow)
    precondition(LampStyle.resolve(state: .normal, monochrome: true, persistentFailure: true) == .white)
    precondition(LampStyle.resolve(state: .slow, monochrome: true, persistentFailure: true) == .white)
    precondition(LampStyle.resolve(state: .failed, monochrome: true, persistentFailure: false) == .white)
    precondition(LampStyle.resolve(state: .failed, monochrome: true, persistentFailure: true) == .red)
    precondition(LampStyle.resolve(state: .failed, monochrome: false, persistentFailure: false) == .red)
    print("PASS: optional monochrome lamp, hollow unknown, consecutive failure gate and recovery")
    print("PASS: countdown and authoritative optional reset credits")
    print("PASS: weekly selection, unknown/nonweekly/other buckets, quota bounds, nonfinite data, all lamp states")
    print("PASS: quota parsing, missing data, clamping, backend denial; failure reminder policy")
} else if CommandLine.arguments.contains("--diagnose") {
    print(fetchQuota().lines.joined(separator:"\n"))
    for target in ProbeTarget.allCases {
        print(probe(target).map { "\(target.name) HTTPS latency: \($0) ms" } ?? "\(target.name) HTTPS probe unavailable")
    }
} else {
    let app=NSApplication.shared;let delegate=App();app.delegate=delegate;app.setActivationPolicy(.accessory);app.run()
}
