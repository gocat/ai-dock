let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
let appearance=NSAppearance(named:.darkAqua)!
app.appearance=appearance
for english in [false,true] {
 L10n.override=english ? "en" : "zh-Hans"
 let fixture=App();fixture.status=NSStatusBar.system.statusItem(withLength:20)
 fixture.popover.contentViewController=NSViewController()
 fixture.weeklyRemaining=0.68
 fixture.snapshot=QuotaSnapshot(lines:[],weeklyRemaining:0.68,resetsAt:Date().addingTimeInterval(5*86400+18*3600+120))
 fixture.checked=true;fixture.googleChecked=true;fixture.latency=426;fixture.googleLatency=185
 appearance.performAsCurrentDrawingAppearance { fixture.refreshMenu() }
 let view=fixture.popover.contentViewController!.view;view.appearance=appearance
 let window=NSWindow(contentRect:view.bounds,styleMask:.borderless,backing:.buffered,defer:false)
 window.appearance=appearance;window.contentView=view
 view.wantsLayer=true;view.layer?.backgroundColor=NSColor(calibratedWhite:0.13,alpha:1).cgColor
 view.layoutSubtreeIfNeeded();RunLoop.current.run(until:Date().addingTimeInterval(0.4))
 let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
 view.cacheDisplay(in:view.bounds,to:rep)
 let panel=NSImage(cgImage:rep.cgImage!,size:view.bounds.size)
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1200,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
 let bg=NSGradient(starting:NSColor(calibratedRed:0.035,green:0.05,blue:0.09,alpha:1),ending:NSColor(calibratedRed:0.10,green:0.12,blue:0.19,alpha:1))!
 bg.draw(in:NSRect(x:0,y:0,width:1200,height:720),angle:20)
 func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ alpha:CGFloat=1,_ weight:NSFont.Weight = .regular) {
  (value as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:NSColor.white.withAlphaComponent(alpha)])
 }
 text("AI Dock",64,500,48,1,.semibold)
 text("1.0",68,465,18,0.5,.medium)
 text(english ? "Quota. Connection." : "额度与连接，",64,375,28,0.95,.medium)
 text(english ? "One glance." : "一眼看懂。",64,332,28,0.95,.medium)
 text(english ? "A quieter place for Codex." : "轻巧的 Codex 菜单栏伴侣",66,265,17,0.55)
 text(english ? "Native macOS · Light & dark" : "原生 macOS · 支持浅色和深色",66,220,14,0.5)
 let rect=NSRect(x:500,y:138,width:640,height:444)
 NSGraphicsContext.saveGraphicsState()
 let shadow=NSShadow();shadow.shadowColor=NSColor.black.withAlphaComponent(0.4);shadow.shadowBlurRadius=35;shadow.shadowOffset=NSSize(width:0,height:-12);shadow.set()
 NSColor(calibratedWhite:0.13,alpha:1).setFill();NSBezierPath(roundedRect:rect,xRadius:32,yRadius:32).fill()
 NSGraphicsContext.restoreGraphicsState()
 NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:rect,xRadius:32,yRadius:32).addClip();panel.draw(in:rect);NSGraphicsContext.restoreGraphicsState()
 NSColor.white.withAlphaComponent(0.15).setStroke();let outline=NSBezierPath(roundedRect:rect.insetBy(dx:0.5,dy:0.5),xRadius:32,yRadius:32);outline.lineWidth=1;outline.stroke()
 let gauge=statusIcon(remaining:0.68,state:.normal,monochrome:false,persistentFailure:false)
 gauge.draw(in:NSRect(x:808,y:620,width:28,height:28))
 text(english ? "Sample data · Rendered from the current app interface" : "示例数据 · 使用当前应用界面代码渲染",500,82,13,0.42)
 NSGraphicsContext.restoreGraphicsState()
 let suffix=english ? "-en" : ""
 try! bitmap.representation(using:.jpeg,properties:[.compressionFactor:0.9])!.write(to:URL(fileURLWithPath:"docs/images/showcase-dark\(suffix).jpg"))
 NSStatusBar.system.removeStatusItem(fixture.status)
 print("Rendered showcase \(english ? "en" : "zh")")
}
