#!/usr/bin/env python3
"""Window-backed toolbar animation regression. Briefly shows its own test window.
Does not operate AI Dock, fetch accounts, change preferences, or change networking.
Requires macOS WindowServer access. Run: python3 scripts/validate-toolbar.py
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import sys

SWIFT_QA = r'''
let qaApp=NSApplication.shared
qaApp.setActivationPolicy(.prohibited)
var qaRasterChecks=0, qaRasterValid=true
for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
    let appearance=NSAppearance(named:appearanceName)!
    for scale:CGFloat in [1,2] {
        for symbol:String? in [nil,"gearshape","power","checkmark","exclamationmark.circle"] {
            qaRasterChecks+=1
            guard let image=RefreshGlyphButton.raster(symbol:symbol,scale:scale,appearance:appearance),
                  image.width == Int(32*scale),image.height == Int(32*scale),
                  let data=image.dataProvider?.data,let bytes=CFDataGetBytePtr(data) else { qaRasterValid=false;continue }
            var hasInk=false
            for y in 0..<image.height {
                for x in 0..<image.width where bytes[y*image.bytesPerRow+x*4+3] > 0 { hasInk=true }
            }
            if !hasInk { qaRasterValid=false }
        }
    }
}
let qaWindow=NSWindow(contentRect:NSRect(x:40,y:40,width:400,height:260),styleMask:.borderless,backing:.buffered,defer:false)
qaWindow.isReleasedWhenClosed=false
let qaRoot=NSView(frame:NSRect(x:0,y:0,width:400,height:260))
qaRoot.wantsLayer=true
qaWindow.contentView=qaRoot
let qaParentA=NSView(frame:qaRoot.bounds);qaParentA.wantsLayer=true;qaRoot.addSubview(qaParentA)
let qaParentB=NSView(frame:qaRoot.bounds);qaParentB.wantsLayer=true;qaRoot.addSubview(qaParentB)
let qaButton=RefreshGlyphButton(frame:NSRect(x:206,y:178,width:32,height:32))
qaParentA.addSubview(qaButton)
let qaGear=RefreshGlyphButton(frame:NSRect(x:270,y:178,width:32,height:32));qaGear.fixedSymbol="gearshape";qaParentA.addSubview(qaGear)
let qaPower=RefreshGlyphButton(frame:NSRect(x:238,y:178,width:32,height:32));qaPower.fixedSymbol="power";qaParentA.addSubview(qaPower)
var qaFixedIconsStopped=true
qaWindow.orderFront(nil)
qaButton.update(.running)
CATransaction.flush()
var qaFrame=0, qaMissing=0, qaSamples=0
var qaMaxDrift=0.0, qaMaxRadiusError=0.0
var qaLastAngle:Double?, qaDirectionDelta=0.0
var qaMaxStep=0.0, qaMaxPhaseError=0.0, qaLastTime:Double?
var qaReparentStep=0.0
var qaTimer:Timer!
func qaEmit(_ value:[String:Any], code:Int32) -> Never {
    qaWindow.orderOut(nil)
    let data=try! JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
    print("QA_JSON:"+String(data:data,encoding:.utf8)!)
    exit(code)
}
DispatchQueue.main.asyncAfter(deadline:.now()+8) {
    qaEmit(["passed":false,"error":"Window-backed sampling timed out","samples":qaSamples],code:1)
}
qaTimer=Timer.scheduledTimer(withTimeInterval:1.0/60,repeats:true) { _ in
    qaFrame += 1
    qaFixedIconsStopped = qaFixedIconsStopped && !qaGear.isSpinning && !qaPower.isSpinning
    if qaFrame == 55 {
        qaButton.removeFromSuperview()
        qaButton.frame.origin=NSPoint(x:250,y:120)
        qaParentB.addSubview(qaButton)
        qaButton.update(.running)
        CATransaction.flush()
        // Do not clear the previous angle: this checks phase across reparenting.
    }
    if let p=qaButton.animationLayerForValidation.presentation(), let root=qaRoot.layer?.presentation() {
        let center=p.convert(CGPoint(x:16,y:16),to:root)
        let expected=qaButton.convert(NSPoint(x:16,y:16),to:qaRoot)
        qaMaxDrift=max(qaMaxDrift,hypot(Double(center.x-expected.x),Double(center.y-expected.y)))
        let moving=p.convert(CGPoint(x:16+RefreshGlyphButton.renderedArcRadius,y:16),to:root)
        qaMaxRadiusError=max(qaMaxRadiusError,abs(hypot(Double(moving.x-center.x),Double(moving.y-center.y))-Double(RefreshGlyphButton.renderedArcRadius)))
        let angle=atan2(Double(moving.y-center.y),Double(moving.x-center.x))
        let now=CACurrentMediaTime()
        if let last=qaLastAngle,let lastTime=qaLastTime {
            var delta=angle-last
            while delta > Double.pi { delta -= 2*Double.pi }
            while delta < -Double.pi { delta += 2*Double.pi }
            qaDirectionDelta += delta
            let dt=now-lastTime
            if dt < 0.1 {
                qaMaxStep=max(qaMaxStep,abs(delta))
                qaMaxPhaseError=max(qaMaxPhaseError,abs(delta + 2*Double.pi*dt/1.1))
            }
            if qaFrame == 55 { qaReparentStep=abs(delta) }
        }
        qaLastAngle=angle;qaLastTime=now;qaSamples+=1
    } else { qaMissing+=1 }
    if qaFrame == 125 {
        qaTimer.invalidate()
        qaButton.update(.success);CATransaction.flush();let successStopped = !qaButton.isSpinning
        qaButton.update(.failure);let failureStopped = !qaButton.isSpinning
        qaButton.update(.idle);let idleStopped = !qaButton.isSpinning
        let stopped=successStopped && failureStopped && idleStopped
        let passed=qaSamples >= 110 && qaMaxDrift < 0.01 && qaMaxRadiusError < 0.01 && qaDirectionDelta < -1 && qaReparentStep < 0.5 && qaMaxPhaseError < 0.35 && stopped && qaRasterValid && qaFixedIconsStopped
        qaEmit([
            "passed":passed,"rasterChecks":qaRasterChecks,"rastersValid":qaRasterValid,"fixedIconsStopped":qaFixedIconsStopped,"samples":qaSamples,"missingPresentationSamples":qaMissing,
            "maxCenterDriftPt":qaMaxDrift,"maxRadiusErrorPt":qaMaxRadiusError,
            "angularDeltaInUnflippedRootRadians":qaDirectionDelta,"clockwise":qaDirectionDelta < 0,
            "maxFrameStepRadians":qaMaxStep,"reparentStepRadians":qaReparentStep,"maxPhaseTimingErrorRadians":qaMaxPhaseError,
            "successStopped":successStopped,"failureStopped":failureStopped,"idleStopped":idleStopped,
            "buttonIsFlipped":qaButton.isFlipped,"backingLayerIsFlipped":qaButton.layer!.isGeometryFlipped,
            "drawingScale":qaButton.drawingScale,"reduceMotion":NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        ],code:passed ? 0:1)
    }
}
qaApp.run()
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1],help='Project root (defaults to parent of scripts/)')
    parser.add_argument('--output',type=Path,help='Optional JSON report path')
    args=parser.parse_args()
    source=(args.root/'Sources/main.swift').read_text()
    marker='if CommandLine.arguments.contains("--self-test")'
    if source.count(marker)!=1:
        parser.error('Expected one self-test entrypoint marker; inspect source before running this harness')
    result=None
    try:
        with tempfile.TemporaryDirectory(prefix='aidock-toolbar-qa-') as temp:
            temp=Path(temp)
            (temp/'main.swift').write_text(source.split(marker)[0]+SWIFT_QA)
            binary=temp/'toolbar-qa'
            command=['swiftc','-swift-version','5','-O','-module-cache-path',str(temp/'module-cache'),'-framework','AppKit',str(temp/'main.swift'),str(args.root/'Sources/Localization.swift'),'-o',str(binary)]
            compiled=subprocess.run(command,capture_output=True,text=True,timeout=120)
            if compiled.returncode:
                result={'passed':False,'error':'Compilation failed','detail':compiled.stderr[-6000:]}
            else:
                run=subprocess.run([str(binary)],capture_output=True,text=True,timeout=12)
                reports=[line[len('QA_JSON:'):] for line in run.stdout.splitlines() if line.startswith('QA_JSON:')]
                result=json.loads(reports[-1]) if reports else {'passed':False,'error':'No presentation report; WindowServer access may be unavailable','detail':run.stderr[-3000:]}
                if run.returncode != 0:
                    result['passed']=False
    except subprocess.TimeoutExpired as error:
        result={'passed':False,'error':'QA process exceeded timeout','timeoutSeconds':error.timeout}
    rendered=json.dumps(result,indent=2,ensure_ascii=False)+'\n'
    print(rendered,end='')
    if args.output:
        args.output.write_text(rendered)
    return 0 if result.get('passed') else 1

if __name__=='__main__':
    sys.exit(main())
