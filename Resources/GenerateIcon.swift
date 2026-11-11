import AppKit
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/Companion.iconset", isDirectory: true)
let theme = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "black"
let dark = theme == "black"
let neutral = theme != "white"
try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
 let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let context = NSGraphicsContext(bitmapImageRep: rep)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
 let scale = CGFloat(pixels)/1024
 let transform=NSAffineTransform();transform.scale(by:scale);transform.concat()
 // Original artwork: a black tile, silver glass ring and mint status point.
 func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat,_ a:CGFloat = 1)->NSColor {
  NSColor(calibratedRed:r,green:g,blue:b,alpha:a)
 }
 let tile=NSBezierPath(roundedRect:NSRect(x:80,y:80,width:864,height:864),xRadius:194,yRadius:194)
 NSGraphicsContext.saveGraphicsState()
 let shadow=NSShadow();shadow.shadowColor=color(0.12,0.18,0.26,0.24);shadow.shadowBlurRadius=26;shadow.shadowOffset=NSSize(width:0,height:-14);shadow.set()
 color(0.9,0.92,0.95).setFill();tile.fill()
 NSGraphicsContext.restoreGraphicsState()
 NSGradient(colors:dark ? [color(0.025,0.027,0.03),color(0.065,0.068,0.074),color(0.14,0.145,0.15)] : theme == "gray" ? [color(0.48,0.49,0.50),color(0.65,0.66,0.67),color(0.79,0.80,0.81)] : [color(0.95,0.96,0.98),color(0.995,0.998,1),.white])!.draw(in:tile,angle:90)
 let rim=NSBezierPath(roundedRect:NSRect(x:83,y:83,width:858,height:858),xRadius:191,yRadius:191)
 color(1,1,1,dark ? 0.23 : 0.85).setStroke();rim.lineWidth=3;rim.stroke()
 // Optical centering: compensate for the open lower arc as one symbol group.
 NSGraphicsContext.saveGraphicsState()
 let opticalOffset=NSAffineTransform();opticalOffset.translateX(by:0,yBy:-48);opticalOffset.concat()
 let center=NSPoint(x:512,y:522)
 func ring(_ end:CGFloat)->NSBezierPath {
  let p=NSBezierPath();p.appendArc(withCenter:center,radius:292,startAngle:225,endAngle:end,clockwise:true);p.lineWidth=98;p.lineCapStyle = .round;return p
 }
 let track=ring(-45)
 (neutral ? color(0.15,0.17,0.19,dark ? 0.9 : 0.3) : color(0.68,0.83,0.94,0.36)).setStroke();track.stroke()
 let arc=ring(-12)
 NSGraphicsContext.saveGraphicsState()
 let ringShadow=NSShadow();ringShadow.shadowColor=neutral ? color(0,0,0,0.30) : color(0.08,0.30,0.62,0.18);ringShadow.shadowBlurRadius=18;ringShadow.shadowOffset=NSSize(width:0,height:-10);ringShadow.set()
 color(0.10,0.46,0.91).setStroke();arc.stroke()
 NSGraphicsContext.restoreGraphicsState()
 // Stroke outline clipping keeps the gradient and highlight inside the symbol.
 let cg=CGMutablePath();cg.addArc(center:center,radius:292,startAngle:225 * .pi/180,endAngle:-12 * .pi/180,clockwise:true)
 context.cgContext.saveGState()
 context.cgContext.addPath(cg.copy(strokingWithWidth:98,lineCap:.round,lineJoin:.round,miterLimit:10));context.cgContext.clip()
 NSGradient(colors:neutral ? [color(0.48,0.53,0.59),color(0.78,0.82,0.87),color(0.97,0.98,1)] : [color(0.02,0.31,0.91),color(0.0,0.60,1),color(0.10,0.83,1)])!.draw(in:NSRect(x:160,y:160,width:704,height:704),angle:90)
 // Broad soft reflection plus narrow refractive edges give the ring a glass surface.
 let reflection=NSBezierPath(ovalIn:NSRect(x:150,y:610,width:720,height:310))
 NSGradient(starting:color(1,1,1,0.36),ending:color(1,1,1,0))!.draw(in:reflection,relativeCenterPosition:NSPoint(x:0,y:0.25))
 context.cgContext.restoreGState()
 let outerGlint=NSBezierPath()
 outerGlint.appendArc(withCenter:center,radius:338,startAngle:169,endAngle:20,clockwise:true)
 outerGlint.lineWidth=3;outerGlint.lineCapStyle = .round
 (neutral ? color(1,1,1,0.85) : color(0.82,0.98,1,0.65)).setStroke();outerGlint.stroke()
 let innerGlint=NSBezierPath()
 innerGlint.appendArc(withCenter:center,radius:245,startAngle:218,endAngle:45,clockwise:true)
 innerGlint.lineWidth=3;innerGlint.lineCapStyle = .round
 (neutral ? color(1,1,1,0.6) : color(0.76,0.96,1,0.45)).setStroke();innerGlint.stroke()
 let dot=NSBezierPath(ovalIn:NSRect(x:441,y:451,width:142,height:142))
 NSGraphicsContext.saveGraphicsState()
 let dotShadow=NSShadow();dotShadow.shadowColor=color(0.04,0.42,0.40,0.2);dotShadow.shadowBlurRadius=12;dotShadow.shadowOffset=NSSize(width:0,height:-7);dotShadow.set()
 color(0.10,0.71,0.58).setFill();dot.fill()
 NSGraphicsContext.restoreGraphicsState()
 NSGradient(starting:color(0.06,0.65,0.53),ending:color(0.42,0.91,0.75))!.draw(in:dot,angle:90)
 NSGraphicsContext.saveGraphicsState()
 dot.addClip()
 let dotReflection=NSBezierPath(ovalIn:NSRect(x:451,y:532,width:122,height:72))
 NSGradient(starting:color(1,1,1,0.5),ending:color(1,1,1,0))!.draw(in:dotReflection,relativeCenterPosition:NSPoint(x:0,y:0.1))
 NSGraphicsContext.restoreGraphicsState()
 NSGraphicsContext.restoreGraphicsState()
 NSGraphicsContext.restoreGraphicsState()
 try! rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
}
