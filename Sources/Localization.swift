import Foundation

enum L10n {
    static var override: String?
    static var english: Bool {
        let value = override ?? UserDefaults.standard.string(forKey:"language") ?? "system"
        if value == "en" { return true }
        if value == "zh-Hans" { return false }
        return !(Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
    }
    static let translations: [String:String] = [
        "重置时间未知": "Reset time unavailable",
        "重置时间已到，等待同步": "Reset due · awaiting update",
        "距重置不足 1 小时": "Resets in under 1 hour",
        "周额度": "Weekly quota",
        "5 小时额度": "5-hour quota",
        "额度": "Quota",
        "服务端提示：常规额度暂不可用": "Server: ordinary usage unavailable",
        "当前账户未提供额度数据": "No quota data for this account",
        "未找到 Codex CLI": "Codex CLI not found",
        "额度读取失败，请检查 Codex 登录和网络": "Quota unavailable. Check Codex login and network.",
        "额度读取超时，请检查 Codex 登录和网络": "Quota request timed out. Check Codex login and network.",
        "偏慢": "Slow",
        "正常": "OK",
        "正在刷新": "Refreshing",
        "刷新完成": "Refresh complete",
        "刷新完成，部分数据未获取": "Refresh complete; some data unavailable",
        "刷新额度与连接状态": "Refresh quota and connection status",
        "额度读取中…": "Loading quota…",
        "Codex 周额度未知": "Codex weekly quota unknown",
        "ChatGPT HTTPS 探测失败": "ChatGPT HTTPS probe failed",
        "ChatGPT HTTPS 探测尚未完成": "ChatGPT HTTPS probe pending",
        "（偏慢）": " (slow)",
        "（正常）": " (OK)",
        "返回": "Back",
        "返回首页": "Back to overview",
        "设置": "Settings",
        "单色菜单栏图标": "Monochrome menu icon",
        "异常提示音": "Alert sound",
        "超过多久算偏慢": "Slow if above",
        "1 秒": "1 s",
        "2 秒": "2 s",
        "3 秒": "3 s",
        "5 秒": "5 s",
        "延迟超过所选时间时显示偏慢": "Mark slow when latency exceeds this value",
        "仅改变偏慢状态标识，不触发弹窗提醒": "Changes the slow status only; no pop-up alert",
        "超过所选时间仅标为偏慢，不弹窗": "Marks slow only; no pop-up alert.",
        "自动更新：额度 5 分钟 · 网络状态 30 秒": "Auto-update: quota 5 min · network 30 s",
        "Codex 本周额度不可用": "Codex weekly quota unavailable",
        "Codex 本周剩余额度；不是已用额度": "Codex weekly remaining quota, not used quota",
        "正在读取 Codex 额度…": "Loading Codex quota…",
        "当前账户未提供周额度": "No weekly quota for this account",
        "常规额度暂不可用": "Ordinary usage unavailable",
        "检测中…": "Checking…",
        "等待检测": "Pending",
        "— · 未连通": "— · Offline",
        "独立 HTTPS 请求耗时，沿系统网络和当前代理规则访问；不同域名可能走不同路由。可达不代表 VPN 已连接或 Codex 会话正常。": "Independent HTTPS request time using system routing and proxy rules. Domains may take different routes. Reachability does not establish a VPN connection or Codex session health.",
        "退出 AI Dock": "Quit AI Dock",
        "打开 Codex": "Open Codex",
        "打开 Clash": "Open Clash",
        "ChatGPT HTTPS 探测异常": "ChatGPT HTTPS probe failed",
        "连续 5 次未能连通测试地址，请检查网络或 Clash。\n\n同一轮故障只提醒一次；此结果不代表 Codex 会话已断开。": "The test endpoint could not be reached on 5 consecutive checks. Check your network or Clash.\n\nOne reminder per incident. This does not mean your Codex session is disconnected.",
        "知道了": "OK",
        "无法打开 Codex": "Could not open Codex",
        "无法打开 Clash，请检查安装": "Could not open Clash. Check its installation.",
        "退出 AI Dock？": "Quit AI Dock?",
        "退出后将停止额度和连接状态检测。": "Quota and connection checks will stop.",
        "取消": "Cancel",
        "退出": "Quit",
        "跟随系统": "System",
        "语言": "Language",
        "未连通": "Offline",
        "检测中": "Checking",
    ]
    static func text(_ value: String) -> String {
        let key = translations[value] != nil ? value : (translations.first { $0.value == value }?.key ?? value)
        return english ? (translations[key] ?? value) : key
    }
}
func L(_ value: String) -> String { L10n.text(value) }
func T(_ chinese: String, _ english: String) -> String { L10n.english ? english : chinese }
