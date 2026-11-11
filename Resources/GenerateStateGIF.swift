import AppKit
import ImageIO
import UniformTypeIdentifiers
let _ = NSApplication.shared
struct Frame { let quota:Double; let state:Int; let delay:Double }
var frames=[Frame(quota:1,state:0,delay:1.2)]
for i in 1...5 { frames.append(Frame(quota:1-Double(i)/10,state:0,delay:i == 5 ? 1.2 : 0.08)) }
for i in 1...5 { frames.append(Frame(quota:0.5-Double(i)/10,state:0,delay:i == 5 ? 1.4 : 0.08)) }
frames += [Frame(quota:1,state:0,delay:1.2),Frame(quota:1,state:1,delay:1.5),Frame(quota:1,state:2,delay:1.5)]
let width=720,height=230
let outputDirectory=CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images"
try! FileManager.default.createDirectory(atPath:outputDirectory,withIntermediateDirectories:true)
func render(_ f:Frame,english:Bool)->CGImage {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let context=NSGraphicsContext(bitmapImageRep:rep)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
 NSColor(calibratedRed:0.055,green:0.085,blue:0.14,alpha:1).setFill();NSRect(x:0,y:0,width:width,height:height).fill()
 func text(_ value:String,center:CGFloat,y:CGFloat,size:CGFloat,color:NSColor = .white,weight:NSFont.Weight = .regular){
  let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color]
  let string=NSString(string:value);let size=string.size(withAttributes:attrs)
  string.draw(at:NSPoint(x:center-size.width/2,y:y),withAttributes:attrs)
 }
 func icon(x:CGFloat,remaining:Double,state:Int){
  let base=NSBezierPath();base.appendArc(withCenter:NSPoint(x:x,y:128),radius:29,startAngle:225,endAngle:-45,clockwise:true);base.lineWidth=5;base.lineCapStyle = .round
  NSColor(calibratedWhite:0.30,alpha:1).setStroke();base.stroke()
  if remaining > 0 {let arc=NSBezierPath();arc.appendArc(withCenter:NSPoint(x:x,y:128),radius:29,startAngle:225,endAngle:225-CGFloat(remaining*270),clockwise:true);arc.lineWidth=5;arc.lineCapStyle = .round;NSColor.white.setStroke();arc.stroke()}
  [NSColor(calibratedRed:0.12,green:0.85,blue:0.43,alpha:1),NSColor(calibratedRed:1,green:0.74,blue:0.05,alpha:1),NSColor(calibratedRed:1,green:0.23,blue:0.23,alpha:1)][state].setFill()
  NSBezierPath(ovalIn:NSRect(x:x-7,y:121,width:14,height:14)).fill()
 }
 text(english ? "Outer arc · Weekly quota" : "外圈 · 本周剩余额度",center:180,y:194,size:17,weight:.semibold)
 text(english ? "Center dot · Connectivity" : "中心点 · ChatGPT 连通性",center:540,y:194,size:17,weight:.semibold)
 icon(x:180,remaining:f.quota,state:0);icon(x:540,remaining:1,state:f.state)
 let percent=Int((f.quota*100).rounded())
 text(english ? "\(percent)% remaining" : "剩余 \(percent)%",center:180,y:65,size:17,weight:.medium)
 text((english ? ["OK","Slow","Unreachable"] : ["正常","偏慢","未连通"])[f.state],center:540,y:65,size:17,weight:.medium)
 NSColor(calibratedWhite:0.28,alpha:1).setFill();NSRect(x:359,y:55,width:1,height:120).fill()
 text(english ? "Color mode · Independent HTTPS probe · Not VPN or session status" : "彩色模式示例 · 独立 HTTPS 探测，不代表 VPN 或会话状态",center:360,y:19,size:12,color:NSColor(calibratedWhite:0.78,alpha:1))
 NSGraphicsContext.restoreGraphicsState()
 return rep.cgImage!
}
for english in [false,true] {
 let suffix=english ? "en" : "zh"
 let url=URL(fileURLWithPath:"\(outputDirectory)/icon-states-\(suffix).gif")
 let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,frames.count,nil)!
 CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
 for frame in frames {CGImageDestinationAddImage(dest,render(frame,english:english),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:frame.delay,kCGImagePropertyGIFUnclampedDelayTime:frame.delay]] as CFDictionary)}
 precondition(CGImageDestinationFinalize(dest))
 let source=CGImageSourceCreateWithURL(url as CFURL,nil)!
 precondition(CGImageSourceGetCount(source)==frames.count)
 print("\(suffix): \(frames.count) frames, \((try! Data(contentsOf:url)).count) bytes")
}
