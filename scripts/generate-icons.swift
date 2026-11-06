import AppKit
import Foundation
let root = URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1]:FileManager.default.currentDirectoryPath)
func icon(_ size:Int)->Data {
 let c=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
 c.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
 let ink = NSColor(srgbRed:23/255,green:35/255,blue:69/255,alpha:1)
 let yellow = NSColor(srgbRed:1,green:227/255,blue:76/255,alpha:1)
 NSColor(srgbRed:36/255,green:70/255,blue:216/255,alpha:1).setFill();NSBezierPath(rect:NSRect(x:0,y:0,width:1024,height:1024)).fill()
 c.saveGState();c.translateBy(x:425,y:535);c.rotate(by:-0.18)
 ink.setFill();NSBezierPath(roundedRect:NSRect(x:-225,y:-311,width:450,height:570),xRadius:56,yRadius:56).fill()
 let back = NSBezierPath(roundedRect:NSRect(x:-225,y:-285,width:450,height:570),xRadius:56,yRadius:56)
 NSColor(srgbRed:1,green:89/255,blue:59/255,alpha:1).setFill();back.fill();ink.setStroke();back.lineWidth=24;back.stroke();c.restoreGState()
 c.saveGState();c.translateBy(x:600,y:475);c.rotate(by:0.14)
 ink.setFill();NSBezierPath(roundedRect:NSRect(x:-225,y:-311,width:450,height:570),xRadius:56,yRadius:56).fill()
 let front = NSBezierPath(roundedRect:NSRect(x:-225,y:-285,width:450,height:570),xRadius:56,yRadius:56)
 yellow.setFill();front.fill();ink.setStroke();front.lineWidth=24;front.stroke()
 for x in [-65.0,65.0] {let ring=NSBezierPath(ovalIn:NSRect(x:x-82,y:-82,width:164,height:164));ring.lineWidth=24;ring.stroke()}
 c.restoreGState()
 NSGraphicsContext.restoreGraphicsState();let rep=NSBitmapImageRep(cgImage:c.makeImage()!);return rep.representation(using:.png,properties:[:])!
}
func save(_ path:String,_ size:Int)throws {let u=root.appendingPathComponent(path);try FileManager.default.createDirectory(at:u.deletingLastPathComponent(),withIntermediateDirectories:true);try icon(size).write(to:u)}
try save("app/assets/icon.png",1024)
for (suffix,size) in [("",120),("@2x",240),("@3x",360)] {try save("app/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage\(suffix).png",size)}
let dir="app/ios/Runner/Assets.xcassets/AppIcon.appiconset/"
let j=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent(dir+"Contents.json"))) as! [String:Any]
for im in j["images"] as! [[String:Any]] {if let f=im["filename"] as? String,let s=im["size"] as? String,let scale=im["scale"] as? String {try save(dir+f,Int(Double(s.components(separatedBy:"x")[0])! * Double(scale.replacingOccurrences(of:"x",with:""))!))}}
for (d,n) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {try save("app/android/app/src/main/res/mipmap-\(d)/ic_launcher.png",n)}
for n in [192,512] {try save("app/web/icons/Icon-\(n).png",n);try save("app/web/icons/Icon-maskable-\(n).png",n)}
try save("app/web/favicon.png",64)
print("Generated native and web icons")
