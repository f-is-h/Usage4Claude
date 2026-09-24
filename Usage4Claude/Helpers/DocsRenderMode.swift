//
//  DocsRenderMode.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-20.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// 文档配图渲染模式
///
/// `scripts/render_docs_images.sh` 把整个 app 的源码编译成一个命令行渲染器，
/// 用 `ImageRenderer` 把真实视图离屏画成 PNG，替代截屏工具。
///
/// `ImageRenderer` 画不了由 AppKit 支撑的控件，SwiftUI 的 `Menu` 就是一个——
/// 渲染出来是一个黄底的「不支持」占位方块。置位后，这类控件会换成视觉等价、
/// 但不可交互的静态替身。配图只需要长得对，能不能点无所谓。
///
/// 应用正常运行时永远是 false，没有任何人会去改它。
enum DocsRenderMode {
    static var isActive = false
}

/// 出图时退化成静态样子的分段选择器。
///
/// `.pickerStyle(.segmented)` 底层是 AppKit 的 `NSSegmentedControl`，
/// `ImageRenderer` 画不了，会渲染成一个黄底的「不支持」方块。
/// 这里按同样的尺寸和配色画一个不可交互的替身
struct DocsSegmentedPicker<Value: Hashable>: View {
    let selection: Value
    let options: [(value: Value, label: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Text(option.label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(option.value == selection
                                  ? Color(NSColor.controlColor)
                                  : Color.clear)
                            .shadow(color: option.value == selection
                                    ? .black.opacity(0.12) : .clear, radius: 1, y: 0.5)
                            .padding(1)
                    )

                if index < options.count - 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1, height: 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
        // 真实的 NSSegmentedControl 按内容宽度收紧，不会撑满整行
        .fixedSize()
    }
}

/// 出图时退化成普通竖排的 `ScrollView`。
///
/// `ImageRenderer` 不给 `ScrollView` 做布局，里面的内容会整个渲染成空白——
/// 不报错，就是一片白。出图时直接把内容铺开，由外层的固定尺寸裁到窗口高度，
/// 效果和真实窗口里滚动到顶端一致。
struct DocsScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if DocsRenderMode.isActive {
            content
        } else {
            ScrollView {
                content
            }
        }
    }
}
