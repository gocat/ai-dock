import AppKit
import Foundation
import QuartzCore
import ServiceManagement
import UniformTypeIdentifiers

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
    var rawResult: [String: Any]? = nil
    var displayLines: [String] { rawResult.map { Quota.lines($0) } ?? lines.map(L) }
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
            ordinaryUsageAllowed: result["ordinaryUsageAllowed"] as? Bool, rawResult: result)
    }
    static func countdown(_ reset: Date?, now: Date = Date()) -> String {
        guard let reset = reset else { return L("重置时间未知") }
        let seconds = reset.timeIntervalSince(now)
        guard seconds > 0 else { return L("重置时间已到，等待同步") }
        if seconds < 3600 { return L("距重置不足 1 小时") }
        let hours = Int(seconds / 3600)
        return T("距重置 \(hours / 24) 天 \(hours % 24) 小时", "Resets in \(hours / 24)d \(hours % 24)h")
    }
    static func lines(_ result: [String: Any]) -> [String] {
        let buckets = result["rateLimitsByLimitId"] as? [String: [String: Any]] ?? ["codex": result["rateLimits"] as? [String: Any] ?? [:]]
        var lines: [String] = []
        for key in buckets.keys.sorted() {
            for kind in ["primary", "secondary"] {
                guard let w = buckets[key]?[kind] as? [String: Any], let used = w["usedPercent"] as? Double, used.isFinite else { continue }
                let mins = w["windowDurationMins"] as? Int
                let label = mins == 10080 ? L("周额度") : mins == 300 ? L("5 小时额度") : mins.map { T("\($0) 分钟额度", "\($0)-minute quota") } ?? L("额度")
                lines.append(T("\(key) \(label)：剩余 \(Int(max(0, min(100, 100-used))))%", "\(key) \(label): \(Int(max(0, min(100, 100-used))))% remaining"))
                if let reset = w["resetsAt"] as? Double {
                    let f = DateFormatter(); f.dateFormat = "M/d HH:mm"; lines.append(T("重置：\(f.string(from: Date(timeIntervalSince1970: reset)))（本地时间）", "Resets: \(f.string(from: Date(timeIntervalSince1970: reset))) (local time)"))
                }
            }
        }
        if result["ordinaryUsageAllowed"] as? Bool == false { lines.append(L("服务端提示：常规额度暂不可用")) }
        return lines.isEmpty ? [L("当前账户未提供额度数据")] : lines
    }
}
func fetchQuota(path: String = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex", arguments: [String] = ["app-server", "--stdio"], timeout: Double = 8) -> QuotaSnapshot {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path)
    p.arguments = arguments
    let input = Pipe(), output = Pipe(); p.standardInput = input; p.standardOutput = output; p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return QuotaSnapshot(lines: [L("未找到 Codex CLI")]) }
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    defer {
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        p.waitUntilExit()
        try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close()
    }
    func send(_ value: [String: Any]) { if let data = try? JSONSerialization.data(withJSONObject: value) { try? input.fileHandleForWriting.write(contentsOf: data + Data([10])) } }
    send(["id":1,"method":"initialize","params":["clientInfo":["name":"codex_companion","version":"0.1.0"],"capabilities":NSNull()]])
    var pending = Data()
    while p.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
        var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 100) > 0 else { continue }
        let data = output.fileHandleForReading.availableData
        if data.isEmpty { break }; pending.append(data)
        if pending.count > 2_000_000 { break }
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline); pending.removeSubrange(...newline)
            guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any], let id = obj["id"] as? Int else { continue }
            if obj["error"] != nil { return QuotaSnapshot(lines: [L("额度读取失败，请检查 Codex 登录和网络")]) }
            if id == 1 { send(["method":"initialized"]); send(["id":2,"method":"account/rateLimits/read","params":["excludeResetCreditDetails":true]]) }
            if id == 2, let result = obj["result"] as? [String: Any] { return Quota.snapshot(result) }
        }
    }
    return QuotaSnapshot(lines: [L("额度读取超时，请检查 Codex 登录和网络")])
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
    config.timeoutIntervalForRequest = 6; config.timeoutIntervalForResource = 8
    config.httpCookieStorage = nil; config.urlCredentialStorage = nil
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: target.url)
    request.httpMethod = "GET"; request.cachePolicy = .reloadIgnoringLocalCacheData
    let semaphore = DispatchSemaphore(value: 0)
    let start = Date(); var milliseconds: Int?
    let lock=NSLock()
    session.dataTask(with: request) { _, response, error in
        if error == nil, let response = response as? HTTPURLResponse,
           target.accepts(response) {
            // Validate the target response. Discard the body; never log or save it.
            lock.lock();milliseconds = Int(Date().timeIntervalSince(start) * 1000);lock.unlock()
        }
        semaphore.signal()
    }.resume()
    guard semaphore.wait(timeout: .now()+9) == .success else { return nil }
    lock.lock();defer { lock.unlock() };return milliseconds
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
    guard checked else { return "●  \(name)  — · \(L("检测中"))" }
    guard let latency = latency else { return "●  \(name)  — · \(L("未连通"))" }
    return "●  \(name)  \(latency) ms · \(latency > threshold ? L("偏慢") : L("正常"))"
}
final class RefreshGlyphButton: NSButton {
    enum Phase { case idle, running, success, failure }
    private let glyph = CALayer()
    private var phase: Phase = .idle
    private var rotationStarted: CFTimeInterval?
    private var renderedAppearance: NSAppearance.Name?
    private var renderedScale: CGFloat = 0
    var fixedSymbol: String? { didSet { renderedAppearance=nil; update(.idle) } }
    // Read-only geometry used by the window-backed animation regression harness.
    var animationLayerForValidation: CALayer { glyph }
    var drawingScale: CGFloat { window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); update(phase) }
    override init(frame:NSRect) {
        super.init(frame:frame)
        title="";isBordered=false;wantsLayer=true
        // Animate an owned child layer, never an AppKit-managed view backing layer.
        glyph.bounds = CGRect(x:0,y:0,width:32,height:32)
        glyph.anchorPoint = CGPoint(x:0.5,y:0.5)
        glyph.position = CGPoint(x:16,y:16)
        glyph.contentsGravity = .resizeAspect
        layer?.addSublayer(glyph)
        update(.idle)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unsupported") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { glyph.removeAllAnimations() }
        else { update(phase) }
    }
    var isSpinning: Bool { glyph.animation(forKey:"rotation") != nil }
    func hasFixedRotationCenter()->Bool {
        glyph.bounds == CGRect(x:0,y:0,width:32,height:32) && glyph.position == CGPoint(x:16,y:16) && glyph.anchorPoint == CGPoint(x:0.5,y:0.5) && CATransform3DIsIdentity(layer!.transform)
    }
    // The visible arc, not the symbol's asymmetric ink bounds, defines the pivot.
    static let arcCenter = NSPoint(x:16,y:16)
    static let arcRadius: CGFloat = 6.5
    static let refreshOpticalScale: CGFloat = 0.9375
    static var renderedArcRadius: CGFloat { arcRadius * refreshOpticalScale }
    static func drawRefreshArrow() {
        let path=NSBezierPath()
        path.appendArc(withCenter:arcCenter,radius:arcRadius,startAngle:-45,endAngle:45,clockwise:true)
        let q=CGFloat(1 / sqrt(2.0))
        let tip=NSPoint(x:arcCenter.x+arcRadius*q,y:arcCenter.y+arcRadius*q)
        // A balanced 90-degree arrowhead, tangent to the circle. Stroke both
        // subpaths in ONE pass: no double alpha/round-cap overpainting at the tip.
        path.move(to:NSPoint(x:tip.x,y:tip.y+4.6*q))
        path.line(to:tip)
        path.line(to:NSPoint(x:tip.x-4.6*q,y:tip.y))
        path.lineWidth=1.2;path.lineCapStyle = .round;path.lineJoinStyle = .round
        NSColor.labelColor.setStroke();path.stroke()
    }
    static func raster(symbol: String?, scale: CGFloat, appearance: NSAppearance) -> CGImage? {
        let pixels=Int(32*scale)
        guard let context=CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x:scale,y:scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
        appearance.performAsCurrentDrawingAppearance {
            if let name=symbol,
               let image=NSImage(systemSymbolName:name,accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:14,weight:.regular)) {
                context.saveGState()
                let size=image.size
                image.draw(in:NSRect(x:(32-size.width)/2,y:(32-size.height)/2,width:size.width,height:size.height))
                NSColor.labelColor.setFill()
                NSRect(x:0,y:0,width:32,height:32).fill(using:.sourceIn)
                context.restoreGState()
            } else {
                context.saveGState()
                context.translateBy(x:16,y:16)
                context.scaleBy(x:refreshOpticalScale,y:refreshOpticalScale)
                context.translateBy(x:-16,y:-16)
                drawRefreshArrow()
                context.restoreGState()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        if symbol == "power", let native=context.makeImage() {
            // Scale the resolved image: re-drawing SF Symbols at fractional font
            // sizes can hint to a smaller rather than larger optical outline.
            context.clear(CGRect(x:0,y:0,width:32,height:32))
            context.interpolationQuality = .high
            context.translateBy(x:16,y:16)
            context.scaleBy(x:1.0345,y:1.0345)
            context.draw(native,in:CGRect(x:-16,y:-16,width:32,height:32))
        }
        return context.makeImage()
    }
    func update(_ next:Phase) {
        let symbol = fixedSymbol ?? (next == .success ? "checkmark" : next == .failure ? "exclamationmark.circle" : nil)
        let scale=drawingScale
        isEnabled = next != .running
        // Keep the same semantic tint as the other toolbar symbols while disabled.
        glyph.opacity = 1
        let text = next == .running ? L("正在刷新") : next == .success ? L("刷新完成") : next == .failure ? L("刷新完成，部分数据未获取") : L("刷新额度与连接状态")
        if fixedSymbol == nil { toolTip=text;setAccessibilityLabel(text) }
        guard next != phase || glyph.contents == nil || renderedAppearance != effectiveAppearance.name || renderedScale != scale || (next == .running && !isSpinning) else { return }
        renderedAppearance = effectiveAppearance.name
        renderedScale=scale
        if next == .running && phase != .running { rotationStarted = CACurrentMediaTime() }
        if next != .running { rotationStarted = nil }
        let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        glyph.removeAllAnimations()
        CATransaction.begin();CATransaction.setDisableActions(true)
        glyph.transform=CATransform3DIdentity
        glyph.contentsScale=scale
        glyph.contents=Self.raster(symbol:symbol,scale:scale,appearance:effectiveAppearance)
        CATransaction.commit()
        // Completion symbols crossfade; the refresh arc keeps a geometric pivot.
        if !reduce && next != .running && fixedSymbol == nil {
            let transition=CATransition()
            transition.type = .fade;transition.duration=0.28
            transition.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut)
            glyph.add(transition,forKey:"symbolTransition")
        }
        if !reduce && next == .running {
            let spin=CABasicAnimation(keyPath:"transform.rotation.z")
            let angle = 2 * Double.pi * ((CACurrentMediaTime() - (rotationStarted ?? CACurrentMediaTime())) / 1.1).truncatingRemainder(dividingBy:1)
            spin.fromValue=angle;spin.toValue = angle + 2*Double.pi
            spin.duration=1.1;spin.repeatCount = .infinity
            spin.timingFunction=CAMediaTimingFunction(name:.linear)
            glyph.add(spin,forKey:"rotation")
        }
        phase=next
    }
}
struct ProxyAppChoice {
    static let key = "proxyApplicationBookmark"
    static func resolve(defaults: UserDefaults = .standard) -> URL? {
        if let data = defaults.data(forKey:key) {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData:data, options:[.withoutUI, .withoutMounting], relativeTo:nil, bookmarkDataIsStale:&stale), valid(url) else { return nil }
            if stale, let renewed = try? url.bookmarkData(options:[], includingResourceValuesForKeys:nil, relativeTo:nil) { defaults.set(renewed, forKey:key) }
            return url
        }
        let fallback = URL(fileURLWithPath:"/Applications/Clash Verge.app")
        return valid(fallback) ? fallback : nil
    }
    static func valid(_ url:URL) -> Bool {
        url.pathExtension.lowercased() == "app" && Bundle(url:url)?.executableURL.map { FileManager.default.isExecutableFile(atPath:$0.path) } == true
    }
    static func name(_ url:URL) -> String { FileManager.default.displayName(atPath:url.path).replacingOccurrences(of:".app",with:"") }
}
// Wake can post more than one notification for a single lid/screen burst.
// Refresh once per burst instead of once per notification.
struct RefreshCoalescer {
    let minimumInterval: TimeInterval
    // Explicit initializer: the synthesized memberwise one would inherit the
    // private access of `last` and become uncallable from other files/builds.
    init(minimumInterval: TimeInterval) { self.minimumInterval = minimumInterval }
    private var last: Date = .distantPast
    mutating func allows(now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(last) >= minimumInterval else { return false }
        last = now
        return true
    }
}
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {
    var status: NSStatusItem!; var timer: Timer?
    // Test instrumentation: how many popover view builds actually happened.
    var panelBuildCount = 0
    var wakeCoalescer = RefreshCoalescer(minimumInterval: 10)
    let popover = NSPopover()
    var manualRefresh = false
    var refreshFinished: Date?
    var refreshHadFailure = false
    var settingsOpen = false
    var loginError: String?
    let refreshGlyph = RefreshGlyphButton(frame:NSRect(x:0,y:0,width:32,height:32))
    var snapshot = QuotaSnapshot(lines: [L("额度读取中…")]); var weeklyRemaining: Double?; var appearanceObserver: NSKeyValueObservation?
    var quota = [L("额度读取中…")], latency: Int?, checked = false, quotaBusy = false, probeBusy = false
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
            self?.refreshMenu(forceSettings:true)
        }
        status.button?.target = self
        status.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSViewController()
        refreshMenu(); refresh()
        DispatchQueue.main.async { if !self.popover.isShown { self.togglePanel() } }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.checkProxy(); self?.checkGoogle() }
        // Let the system coalesce the periodic wake-ups instead of pinning them.
        timer?.tolerance = 3
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.checkQuota() }.tolerance = 15
        // Timers do not fire while asleep, so results are stale right after wake.
        // Refresh once per wake burst; nothing here blocks the sleep notification.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePanel() }
        return true
    }
    func item(_ title: String, _ action: Selector? = nil) -> NSMenuItem { let i = NSMenuItem(title:title,action:action,keyEquivalent:"");i.target=self;return i }
    func updateStatusItem(state: ProbeState) {
        guard let button = status?.button else { return }
        let weeklyText = weeklyRemaining.map { T("Codex 周额度剩余 \(Int(($0 * 100).rounded()))%", "Codex weekly remaining: \(Int(($0 * 100).rounded()))%") } ?? L("Codex 周额度未知")
        let probeText = checked ? latency.map { "ChatGPT HTTPS: \($0) ms\($0 > threshold ? L("（偏慢）") : L("（正常）"))" } ?? L("ChatGPT HTTPS 探测失败") : L("ChatGPT HTTPS 探测尚未完成")
        button.title = ""
        button.image = statusIcon(remaining: weeklyRemaining, state: state, monochrome: monochrome, persistentFailure: persistentProbeFailure(recentFailures))
        button.imagePosition = .imageOnly
        let description = "\(weeklyText); \(probeText); \(probeLabel("Google", checked: googleChecked, latency: googleLatency, threshold: threshold)). " + T("HTTPS 请求耗时，不代表 Codex 会话或 VPN 连接状态。", "HTTPS latency does not establish Codex session health or a VPN connection.")
        button.toolTip = description
        button.setAccessibilityLabel(description)
    }
    func finishPendingManualRefresh() {
        guard manualRefresh, !quotaBusy, !probeBusy, !googleBusy else { return }
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
    func refreshMenu(forceSettings: Bool = false, forcePanel: Bool = false) {
        let state = ProbeState.state(checked: checked, latency: latency, threshold: threshold)
        updateStatusItem(state: state)
        finishPendingManualRefresh()
        refreshGlyph.update(manualRefresh ? .running : refreshFinished != nil ? (refreshHadFailure ? .failure : .success) : .idle)
        // A closed popover is not visible: only the menu-bar item has to stay
        // current. Rebuilding its view tree on every 30 s result was pure churn.
        guard forcePanel || popover.isShown || settingsOpen else { return }
        if settingsOpen {
            if !forceSettings, popover.contentViewController?.view.identifier == NSUserInterfaceItemIdentifier("settings") { return }
            panelBuildCount += 1
            let view = settingsView()
            popover.contentViewController?.view = view
            popover.contentSize = view.frame.size
            return
        }
        panelBuildCount += 1
        let dashboard = dashboardView(state: state)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: dashboard.frame.height + 56))
        dashboard.setFrameOrigin(NSPoint(x: 6, y: 56))
        root.addSubview(dashboard)
        let line = NSBox(frame: NSRect(x: 12, y: 58, width: 296, height: 1))
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
        // The popover is still closed at this point, so ask for the build explicitly.
        refreshMenu(forcePanel: true)
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
        refreshMenu(forceSettings:true)
    }
    @objc func setLanguage(_ sender: NSPopUpButton) {
        let values = ["system", "zh-Hans", "en"]
        guard values.indices.contains(sender.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(values[sender.indexOfSelectedItem], forKey: "language")
        refreshMenu(forceSettings:true)
    }
    @objc func toggleLogin(_ sender: NSSwitch) {
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = T("未能更改，请检查系统登录项", "Could not change login item") }
        refreshMenu(forceSettings:true)
    }
    func settingsView() -> NSView {
        let view = NSView(frame:NSRect(x:0,y:0,width:320,height:222))
        view.identifier=NSUserInterfaceItemIdentifier("settings")
        func text(_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ size:CGFloat = 12)->NSTextField {
            let label=NSTextField(labelWithString:title)
            label.font = .systemFont(ofSize:size)
            label.frame=NSRect(x:x,y:y,width:width,height:18)
            view.addSubview(label);return label
        }
        let title=text(L("设置"),48,187,190,14)
        title.font = .systemFont(ofSize:14,weight:.semibold)
        let back = RefreshGlyphButton(frame:NSRect(x:12,y:180,width:32,height:32))
        back.fixedSymbol="chevron.left";back.target=self;back.action = #selector(closeSettings)
        back.toolTip=L("返回首页");back.setAccessibilityLabel(L("返回首页"));view.addSubview(back)
        _ = text(L("语言"),16,157,136,11)
        let language = NSPopUpButton(frame:NSRect(x:16,y:134,width:136,height:22),pullsDown:false)
        language.controlSize = .small
        language.addItems(withTitles:[L("跟随系统"), "简体中文", "English"])
        language.selectItem(at:["system", "zh-Hans", "en"].firstIndex(of:UserDefaults.standard.string(forKey:"language") ?? "system") ?? 0)
        language.target=self;language.action = #selector(setLanguage(_:))
        language.setAccessibilityLabel(L("语言"));language.toolTip=L("语言")
        view.addSubview(language)
        func toggleRow(_ title:String,_ centerY:CGFloat,_ state:NSControl.StateValue,_ action:Selector) {
            let label=text(title,16,centerY-9,224)
            label.toolTip=title
            let toggle=NSSwitch();toggle.controlSize = .small;toggle.sizeToFit()
            toggle.setFrameOrigin(NSPoint(x:304-toggle.frame.width,y:centerY-toggle.frame.height/2))
            toggle.target=self;toggle.action=action;toggle.state=state
            toggle.setAccessibilityLabel(title);view.addSubview(toggle)
        }
        let loginStatus = SMAppService.mainApp.status
        toggleRow(T("开机启动", "Launch at login"),112,loginStatus == .enabled ? .on : .off,#selector(toggleLogin(_:)))
        toggleRow(L("单色菜单栏图标"),85,monochrome ? .on : .off,#selector(toggleMonochrome))
        toggleRow(L("异常提示音"),58,UserDefaults.standard.bool(forKey:"sound") ? .on : .off,#selector(toggleSound))
        _ = text(L("超过多久算偏慢"),16,25,108)
        let choices=NSSegmentedControl(labels:[L("1 秒"),L("2 秒"),L("3 秒"),L("5 秒")],trackingMode:.selectOne,target:self,action:#selector(setThresholdChoice(_:)))
        choices.controlSize = .small;choices.font = .systemFont(ofSize:11)
        choices.frame=NSRect(x:128,y:25,width:176,height:20)
        choices.selectedSegment=[1000,2000,3000,5000].firstIndex(of:threshold) ?? 2
        choices.setAccessibilityLabel(L("延迟超过所选时间时显示偏慢"))
        choices.toolTip=L("仅改变偏慢状态标识，不触发弹窗提醒");view.addSubview(choices)
        let proxy = NSButton(title:ProxyAppChoice.resolve().map { ProxyAppChoice.name($0) } ?? T("选择应用…", "Choose app…"),target:self,action:#selector(chooseProxy))
        proxy.bezelStyle = .rounded;proxy.controlSize = .small;proxy.font = .systemFont(ofSize:11)
        proxy.frame=NSRect(x:168,y:134,width:136,height:22)
        proxy.cell?.lineBreakMode = .byTruncatingTail
        proxy.toolTip=T("选择要打开的代理应用（不控制连接）", "Choose a proxy app to open; does not control connections")
        proxy.setAccessibilityLabel(T("选择代理应用", "Choose proxy app"));view.addSubview(proxy)
        _ = text(T("代理应用", "Proxy app"),168,157,136,11)
        let note = loginError ?? (loginStatus == .requiresApproval ? T("请在系统设置的登录项中允许启动", "Allow AI Dock in System Settings > Login Items") : L("自动更新：额度 5 分钟 · 网络状态 30 秒"))
        let footer=text(note,16,3,216,9);footer.textColor = .aidockSecondary
        footer.lineBreakMode = .byTruncatingTail;footer.toolTip=note
        let branding=text("AI Dock 1.0",240,3,64,9)
        branding.alignment = .right;branding.textColor = .secondaryLabelColor
        branding.toolTip = "AI Dock " + (Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0")
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
        let quotaCard=NSView(frame:NSRect(x:6,y:54,width:296,height:66))
        quotaCard.wantsLayer=true;quotaCard.layer?.cornerRadius=10
        quotaCard.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.045).cgColor
        view.addSubview(quotaCard)
        _ = label("Codex", 16, height - 78, 180, 13, .labelColor, .semibold)
        let percentage = label(weeklyRemaining.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", 214, height - 78, 78, 12, .aidockSecondary)
        percentage.alignment = .right
        percentage.setAccessibilityLabel(weeklyRemaining.map { T("Codex 本周剩余额度 \(Int(($0 * 100).rounded()))%", "Codex weekly remaining: \(Int(($0 * 100).rounded()))%") } ?? L("Codex 本周额度不可用"))
        let track = NSView(frame:NSRect(x:18,y:85,width:272,height:6))
        track.wantsLayer = true
        track.layer?.cornerRadius = 3
        track.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        track.layer?.masksToBounds = true
        track.toolTip = L("Codex 本周剩余额度；不是已用额度")
        if let remaining = weeklyRemaining {
            let fill = NSView(frame:NSRect(x:0,y:0,width:272 * min(1,max(0,remaining)),height:6))
            fill.wantsLayer = true
            fill.layer?.cornerRadius = 3
            fill.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            track.addSubview(fill)
        }
        view.addSubview(track)
        let quotaDetail = weeklyRemaining == nil
            ? (quotaBusy ? L("正在读取 Codex 额度…") : (snapshot.displayLines.first ?? L("当前账户未提供周额度")))
            : Quota.countdown(snapshot.resetsAt)
        var details = [quotaDetail]
        if let credits=snapshot.resetCredits { details.append(T("可用重置 \(credits) 次", "Available resets: \(credits)")) }
        if snapshot.ordinaryUsageAllowed == false { details.insert(L("常规额度暂不可用"),at:0) }
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
            let value = target.3 ? L("检测中…") : !target.1 ? L("等待检测") : target.2.map { "\($0) ms · \($0 > threshold ? L("偏慢") : L("正常"))" } ?? L("— · 未连通")
            let result = label(value, x + 15, 9, 129, 12)
            result.toolTip = L("独立 HTTPS 请求耗时，沿系统网络和当前代理规则访问；不同域名可能走不同路由。可达不代表 VPN 已连接或 Codex 会话正常。")
        }

        let actions: [(String, String, Selector)] = [
            ("arrow.clockwise", L("刷新额度与连接状态"), #selector(refresh)),
            ("power", L("退出 AI Dock"), #selector(quit)),
            ("gearshape", L("设置"), #selector(openSettings(_:)))
        ]
        for (index, action) in actions.enumerated() {
            if index == 0 {
                refreshGlyph.target = self; refreshGlyph.action = action.2
                refreshGlyph.frame = NSRect(x:238,y:Int(height)-42,width:32,height:32)
                let phase: RefreshGlyphButton.Phase = manualRefresh ? .running : refreshFinished != nil ? (refreshHadFailure ? .failure : .success) : .idle
                refreshGlyph.update(phase)
                view.addSubview(refreshGlyph)
                continue
            }
            let button = RefreshGlyphButton(frame:NSRect(x:index == 1 ? 270 : 6,y:Int(height)-42,width:32,height:32))
            button.fixedSymbol=action.0
            button.target=self;button.action=action.2
            button.toolTip = action.1; button.setAccessibilityLabel(action.1)
            view.addSubview(button)
        }
        return view
    }
    func launcherView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 308, height: 52))
        let entries: [(String, String, Selector)] = [
            (L("打开 Codex"), "terminal", #selector(openCodex)),
            (ProxyAppChoice.resolve().map { T("打开 \(ProxyAppChoice.name($0))", "Open \(ProxyAppChoice.name($0))") } ?? T("选择应用", "Choose app"), "lock.shield", #selector(openClash))
        ]
        for (index, entry) in entries.enumerated() {
            let button = NSButton(title: entry.0, target: self, action: entry.2)
            button.bezelStyle = .push
            if #available(macOS 26.0, *) { button.controlSize = .extraLarge }
            else { button.controlSize = .large }
            button.isBordered = true
            button.font = .systemFont(ofSize: 13, weight: .medium)
            // AppKit's large push bezel may wrap titles despite NSCell.wraps.
            // Fit the visible title explicitly; preserve the full name in AX and tooltip.
            let font = button.font!
            var shortTitle = entry.0
            while (shortTitle as NSString).size(withAttributes:[.font:font]).width > 82 && shortTitle.count > 1 {
                shortTitle.removeLast()
            }
            if shortTitle != entry.0 {
                while ((shortTitle + "…") as NSString).size(withAttributes:[.font:font]).width > 82 && shortTitle.count > 1 { shortTitle.removeLast() }
                button.title = shortTitle.trimmingCharacters(in:.whitespaces) + "…"
            }
            let resource = index == 0 ? "CodexMono" : "ProxyNeutral"
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
            button.cell?.wraps = false
            button.cell?.isScrollable = true
            button.cell?.lineBreakMode = .byTruncatingTail
            button.toolTip = entry.0
            button.setAccessibilityLabel(entry.0)
            view.addSubview(button)
        }
        return view
    }
    @objc func setThreshold(_ sender: NSMenuItem) { UserDefaults.standard.set(sender.tag,forKey:"threshold");refreshMenu(forceSettings:true) }
    @objc func toggleMonochrome() { UserDefaults.standard.set(!monochrome, forKey: "monochromeIcon"); refreshMenu(forceSettings:true) }
    @objc func toggleSound() { UserDefaults.standard.set(!UserDefaults.standard.bool(forKey:"sound"),forKey:"sound");refreshMenu(forceSettings:true) }
    // Timers are silent while the Mac sleeps, so wake is the only hint that the
    // menu-bar reading is stale. Wi-Fi and VPN usually need a moment to come back,
    // so the refresh waits out a short grace period instead of probing immediately.
    static let wakeGraceSeconds: TimeInterval = 5
    @objc func handleWake() {
        if Thread.isMainThread { armWakeRefresh() }
        else { DispatchQueue.main.async { [weak self] in self?.armWakeRefresh() } }
    }
    func armWakeRefresh() {
        guard wakeCoalescer.allows() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.wakeGraceSeconds) { [weak self] in
            guard let self = self, !self.manualRefresh else { return }
            self.checkQuota(); self.checkProxy(); self.checkGoogle()
        }
    }
    @objc func refresh() {
        guard !manualRefresh else { return }
        refreshFinished = nil
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
            self.refreshMenu()
            if self.reminder.record(reachable: value != nil) {
                if UserDefaults.standard.bool(forKey:"sound") { NSSound.beep() }
                let alert=NSAlert();alert.messageText=L("ChatGPT HTTPS 探测异常");alert.informativeText=L("连续 5 次未能连通测试地址，请检查网络或代理应用。\n\n同一轮故障只提醒一次；此结果不代表 Codex 会话已断开。")
                alert.addButton(withTitle:L("知道了"));alert.alertStyle = .warning;alert.window.level = .floating
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
        launcherError = NSWorkspace.shared.open(URL(string: "codex://")!) ? nil : L("无法打开 Codex")
        refreshMenu()
    }
    @objc func chooseProxy() {
        popover.performClose(nil)
        let panel=NSOpenPanel()
        panel.title=T("选择代理应用", "Choose proxy app")
        panel.message=T("只打开应用，不会更改代理连接。", "Opens the app only; does not change your connection.")
        panel.canChooseFiles=true;panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        panel.directoryURL=URL(fileURLWithPath:"/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        NSApp.activate(ignoringOtherApps:true)
        if panel.runModal() == .OK, let url=panel.url {
            do {
                guard ProxyAppChoice.valid(url) else { throw CocoaError(.fileReadUnsupportedScheme) }
                let data=try url.bookmarkData(options:[],includingResourceValuesForKeys:nil,relativeTo:nil)
                UserDefaults.standard.set(data,forKey:ProxyAppChoice.key)
            } catch { showLauncherError(T("无法使用这个应用，请重新选择。", "Cannot use this app. Please choose another.")) }
        }
        togglePanel();settingsOpen=true;refreshMenu()
    }
    func showLauncherError(_ message:String) {
        let alert=NSAlert();alert.messageText=message;alert.addButton(withTitle:L("知道了"));alert.runModal()
    }
    @objc func openClash() {
        guard let url=ProxyAppChoice.resolve() else { chooseProxy();return }
        popover.performClose(nil)
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at:url, configuration:config) { _, error in
            DispatchQueue.main.async {
                if error != nil { self.showLauncherError(T("无法打开所选代理应用，请在设置中重新选择。", "Could not open the proxy app. Choose it again in Settings.")) }
            }
        }
    }
    @objc func quit() {
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = L("退出 AI Dock？")
        alert.informativeText = L("退出后将停止额度和连接状态检测。")
        alert.addButton(withTitle: L("取消"))
        alert.addButton(withTitle: L("退出"))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { NSApp.terminate(nil) }
        else { togglePanel() }
    }
}
if CommandLine.arguments.contains("--self-test") {
    L10n.override = "zh-Hans"
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
    precondition(RefreshGlyphButton.arcCenter == NSPoint(x:16,y:16))
    precondition(!fixture.refreshGlyph.isSpinning)
    fixture.refreshGlyph.update(.idle)
    precondition(!fixture.refreshGlyph.isSpinning)
    let dashboard=fixture.dashboardView(state:.normal)
    let gear=dashboard.subviews.compactMap { $0 as? NSButton }.first { $0.toolTip == L("设置") }!
    let back=settings.subviews.compactMap { $0 as? NSButton }.first { $0.toolTip == L("返回首页") }!
    precondition(back.frame == gear.frame.offsetBy(dx:6,dy:56), "Back must share Settings hit target")
    let timedStart=ProcessInfo.processInfo.systemUptime
    let timed=fetchQuota(path:"/bin/sh",arguments:["-c", "trap '' TERM; while :; do read line || :; done"],timeout:0.3)
    precondition(timed.weeklyRemaining == nil && timed.lines.first!.contains("超时"))
    precondition(ProcessInfo.processInfo.systemUptime-timedStart < 1.5, "Quota timeout must reap unresponsive child")
    let missing=fetchQuota(path:"/nonexistent/aidock-test-cli",timeout:0.1)
    precondition(missing.lines == [L("未找到 Codex CLI")])
    var gate = RefreshCoalescer(minimumInterval: 10)
    let wakeTime = Date(timeIntervalSince1970: 60000)
    precondition(gate.allows(now: wakeTime), "First wake must refresh")
    precondition(!gate.allows(now: wakeTime.addingTimeInterval(1)), "Duplicate wake must be coalesced")
    precondition(!gate.allows(now: wakeTime.addingTimeInterval(9.9)))
    precondition(gate.allows(now: wakeTime.addingTimeInterval(10.1)), "A later wake must refresh again")
    fixture.settingsOpen = false
    let buildsBefore = fixture.panelBuildCount
    fixture.refreshMenu()
    precondition(fixture.panelBuildCount == buildsBefore, "Closed popover must not rebuild its view tree")
    fixture.refreshMenu(forcePanel: true)
    precondition(fixture.panelBuildCount == buildsBefore + 1, "Opening the popover must build it exactly once")
    fixture.settingsOpen = true
    fixture.refreshMenu()
    precondition(fixture.panelBuildCount == buildsBefore + 2, "Settings must still build while on screen")
    fixture.settingsOpen = false
    let suite="app.aidock.selftest."+UUID().uuidString
    let defaults=UserDefaults(suiteName:suite)!
    defaults.set(Data([0,1,2]),forKey:ProxyAppChoice.key)
    precondition(ProxyAppChoice.resolve(defaults:defaults) == nil, "Invalid saved choice must not silently fall back")
    defaults.removePersistentDomain(forName:suite)
    precondition(!ProxyAppChoice.valid(URL(fileURLWithPath:"/tmp")))
    print("PASS: bounded unresponsive CLI cleanup, missing CLI, stopped animations, same-position Back, invalid app selection")
    print("PASS: duplicate wake coalescing, closed popover never rebuilt, on-screen settings still rebuilt")
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
    let cachedError = QuotaSnapshot(lines:[L("未找到 Codex CLI")])
    let savedLanguage = UserDefaults.standard.string(forKey:"language")
    L10n.override = "en"
    precondition(cachedError.displayLines == ["Codex CLI not found"])
    precondition(Quota.countdown(now.addingTimeInterval(49 * 3600), now:now) == "Resets in 2d 1h")
    precondition(probeLabel("Google",checked:true,latency:nil,threshold:3000).contains("Offline"))
    fixture.refreshGlyph.update(.idle)
    precondition(fixture.refreshGlyph.toolTip == "Refresh quota and connection status")
    for language in ["en", "zh-Hans"] {
        L10n.override = language
        let settings = fixture.settingsView()
        precondition(settings.frame.size == NSSize(width:320,height:222))
        precondition(settings.subviews.allSatisfy { settings.bounds.contains($0.frame) })
        for field in settings.subviews.compactMap({ $0 as? NSTextField }) {
            precondition(field.attributedStringValue.size().width <= field.frame.width + 1, "Settings text overflow: " + field.stringValue)
        }
        precondition(fixture.dashboardView(state:.normal).frame.height+56 == settings.frame.height)
    }
    precondition(UserDefaults.standard.string(forKey:"language") == savedLanguage)
    L10n.override = nil
    print("PASS: cached error localization, English countdown/status, bilingual settings fit, unchanged user language preference")

} else if CommandLine.arguments.contains("--diagnose") {
    print(fetchQuota().lines.joined(separator:"\n"))
    for target in ProbeTarget.allCases {
        print(probe(target).map { "\(target.name) HTTPS latency: \($0) ms" } ?? "\(target.name) HTTPS probe unavailable")
    }
} else {
    let app=NSApplication.shared;let delegate=App();app.delegate=delegate;app.setActivationPolicy(.accessory);app.run()
}
