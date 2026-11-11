# AI Dock：性能、能耗与冲突调研

2026-11-11；代码核查与一次进程采样，不是续航基准测试。以下优化均为提案，尚未实施。

## 当前事实

- 双目标每 30 秒探测：正常持续运行理论上 240 个 HTTPS 请求/小时（不含手动刷新、重定向和重试）。额度每 300 秒读取，12 次 CLI 启动/小时。实际调度可能被系统延迟。
- 每个目标有 busy 门闩，防止同类任务重叠；网络工作在 utility 队列。两个目标可并发，手动刷新仍可增加调用频率。
- 每次请求新建 ephemeral URLSession，再销毁；Cookie/凭据存储禁用，不保存响应体，但 dataTask 仍会先接收响应数据到内存。
- 请求/资源超时为 8/10 秒，信号量最多等待 12 秒。额度子进程 25 秒后发送终止信号，但没有强制退出兜底，管道异常可能使 quotaBusy 长时间不释放。
- 每次结果会重建面板，即使面板隐藏；30 秒定时器未设 tolerance，额度定时器设为 15 秒。
- 未发现阻止休眠、修改代理设置、修改凭据或关闭其他应用的代码。关闭面板不代表停止检测。
- 一次本机采样为 0.0% CPU、RSS 58,704 KiB（约 57.3 MiB），AI Dock 未持有防休眠断言。这仅是瞬时观测，不能推断全天耗电、CLI 峰值或整机休眠行为。

## 推荐分期

| 优先级 | 提案 | 收益及代价 |
| --- | --- | --- |
| P0 | 明确取消、退出与子进程超时回收；睡眠前暂停，唤醒后去重刷新一次并留恢复宽限 | 避免挂起任务、恢复时误报和调用堆积；不能在睡眠通知中阻塞 |
| P1 第一批 | 复用无 Cookie/凭据的 ephemeral 会话；回调或 async 替代信号量等待；限制异常响应体 | 减少对象、线程等待与连接建立机会；需验证代理切换后连接失效，不能声称请求数会减少 |
| P1 第一批 | 隐藏面板只更新数据和必要菜单栏图标；打开时渲染；只对变化状态重绘 | 减少 AppKit 重建与布局，保持手动刷新动画仅可见时运行 |
| P1 第一批 | 合并调度，30 秒探测允许约 3 秒 tolerance；低电量/离线采用事件驱动调整 | 给系统合并唤醒机会；NWPathMonitor 仅判断网络路径，不能替代目标 HTTPS 可达性 |
| P1 第二批 | 面板打开 30 秒、隐藏且稳定时 120 秒；低电量时 300 秒；手动刷新即时 | 隐藏稳定时约 60 请求/小时，较基线请求数减少 75%；低电量约 24 次，减少 90%。这是请求数估算，不是省电比例 |
| P1 第二批 | 失败采用 30→60→120→300 秒退避，网络恢复事件/手动操作可重试 | 减少断网空耗；必须将“五次失败”提醒改为明确的持续时间规则，否则提醒时延会暗中变化 |
| 待评估 | CLI 长连接或降低额度读取频率 | 长连接降低启动次数但增加常驻内存/认证与升级复杂度；先测启动峰值，再决定，不预先重构 |

推荐先做不改变检测时效的第一批，再由体验测试决定是否采用自适应频率。

## 潜在冲突与未验证项

- 代理/PAC 分流及代理切换会影响两个域名和缓存连接；可达不等于 VPN 或 Codex 会话正常。
- ChatGPT 更新可能移动或更换内嵌 CLI；登录失效、并发 CLI 读取的文件锁或服务限流尚未充分验证。
- 网络抖动、睡眠唤醒会导致探测失败；当前提醒冷却在重启后重置。
- 普通 Timer 不是唤醒机器的计划任务；代码无唤醒/防休眠请求，但仍需实测合盖前后子进程、断言与网络活动。

## 验收方案

同机同网络对比基线与每批优化：面板关闭/打开各 30 分钟，正常网络、断网/恢复、代理切换、低电量模式和合盖唤醒（这些会影响用户，安排独立测试）。采集主进程及 CLI 子进程 CPU 时间、RSS 峰值、唤醒次数、网络请求/流量、Energy Impact、断言与子进程残留。比较状态新鲜度和提醒时延，避免仅为减少采样而漏报。长期 8 小时电池测试需控制其他应用；不能用单次 CPU 快照声称“零耗电”。

## 官方依据

- [Apple：减少定时器使用](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html)
- [Apple：减少 I/O](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/MinimizingIO.html)
- [Apple：App Nap](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html)
- [Apple：网络连接复用](https://developer.apple.com/videos/play/wwdc2020/10111/)
- [Apple：睡眠通知](https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification)
