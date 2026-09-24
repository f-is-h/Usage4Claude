// 把渲染出来的透明 PNG 合成到指定底色上，供人眼核对。
//
// 渲染产物背景透明、深色版画的是白色内容，图片查看器会把透明合成到白底，
// 于是白字、发丝线、单色图标统统「消失」。小元素同理：950pt 画布里的 20pt 图标
// 在缩略图上根本看不清。核对之前先过一道这个脚本，别直接看原图下结论。
//
// 用法：
//   swift preview_on_background.swift <输入.png> <输出.png> <底色hex> [顶部裁切pt]
//
// 例：
//   swift preview_on_background.swift hero.zh-CN.dark@2x.png /tmp/c.png 0d1117
//   swift preview_on_background.swift hero.zh-CN.dark@2x.png /tmp/c.png 0d1117 50
//
// 底色用 GitHub 的实际值：浅色 ffffff，深色 0d1117。
// 给了「顶部裁切pt」就只取顶部那一条并放大 3 倍，用来看菜单栏图标这类小元素。

import AppKit

let args = CommandLine.arguments
guard args.count >= 4, let source = NSImage(contentsOfFile: args[1]) else {
    print("用法: swift preview_on_background.swift <输入.png> <输出.png> <底色hex> [顶部裁切pt]")
    exit(1)
}

func color(fromHex hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    return NSColor(red: CGFloat((value >> 16) & 0xff) / 255,
                   green: CGFloat((value >> 8) & 0xff) / 255,
                   blue: CGFloat(value & 0xff) / 255,
                   alpha: 1)
}

let background = color(fromHex: args[3])
let cropTop = args.count > 4 ? Double(args[4]) : nil
let zoom: CGFloat = cropTop == nil ? 1 : 3
let sourceSize = source.size
let outputSize = NSSize(width: sourceSize.width * zoom,
                        height: (cropTop.map { CGFloat($0) } ?? sourceSize.height) * zoom)

let output = NSImage(size: outputSize)
output.lockFocus()
background.setFill()
NSRect(origin: .zero, size: outputSize).fill()
// 只裁顶部时把图往下推：AppKit 的原点在左下角
let offsetY = cropTop.map { (CGFloat($0) - sourceSize.height) * zoom } ?? 0
source.draw(in: NSRect(x: 0, y: offsetY,
                       width: sourceSize.width * zoom,
                       height: sourceSize.height * zoom))
output.unlockFocus()

guard let tiff = output.tiffRepresentation,
      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
    print("合成失败")
    exit(1)
}
try png.write(to: URL(fileURLWithPath: args[2]))
print("已写出 \(args[2])  \(Int(outputSize.width))×\(Int(outputSize.height))px")
