//
//  ThresholdSlider.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 提醒阈值滑块行：标题 + 当前阈值文字 + 一条放 1 或 2 个滑钮的轨道
///
/// 两个滑钮不区分身份、可以互相穿过：文字只看位置，数值小的是第一次提醒，
/// 所以不存在"第一次大于第二次"的非法状态，两个滑钮重合即只提醒一次。
/// 两钮之间刻意不填色——它们是两个独立的提醒点，填色会让人读成"用量在这个区间内时提醒"。
/// 拖动过程中只改本地状态（右侧文字实时跟随），松手才通过 onCommit 写回，避免每帧写一次设置。
/// macOS 与 SwiftUI 都没有原生的双滑钮控件，单滑钮也用同一个组件，保证几行外观一致。
struct ThresholdSlider: View {
    let title: String
    /// 当前阈值，1 或 2 个，顺序无关
    let values: [Int]
    let range: ClosedRange<Int>
    let step: Int
    /// 松手或辅助功能调节后回调，传入升序排列的新值
    let onCommit: ([Int]) -> Void

    @Environment(\.isEnabled) private var isEnabled
    /// 拖动中的值，nil 表示没有在拖动
    @State private var draftValues: [Int]?
    /// 本次拖动抓住的滑钮在 draftValues 中的下标
    @State private var activeIndex: Int?

    private let thumbSize: CGFloat = 16
    private let trackHeight: CGFloat = 4

    private var displayedValues: [Int] { draftValues ?? values }

    /// 升序去重后的阈值
    private var distinctValues: [Int] { Array(Set(displayedValues)).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack {
                    track(width: width)
                    ForEach(displayedValues.indices, id: \.self) { index in
                        let value = displayedValues[index]
                        thumb
                            .accessibilityElement()
                            .accessibilityLabel(positionLabel(for: value))
                            .accessibilityValue("\(value)%")
                            .accessibilityAdjustableAction { adjust(index: index, direction: $0) }
                            .position(x: xPosition(for: value, width: width), y: thumbSize / 2)
                    }
                }
                .frame(width: width, height: thumbSize)
                .contentShape(Rectangle())
                .gesture(dragGesture(width: width))
            }
            .frame(height: thumbSize)
        }
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
    }

    // MARK: - Subviews

    private func track(width: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: width, height: trackHeight)
            // 每一档一个刻度，提示滑钮只会停在这些位置
            ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: step)), id: \.self) { value in
                Rectangle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 1, height: trackHeight)
                    .position(x: xPosition(for: value, width: width), y: thumbSize / 2)
            }
        }
        .frame(width: width, height: thumbSize)
        .accessibilityHidden(true)
    }

    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5))
            .overlay(Circle().fill(Color.accentColor).frame(width: 6, height: 6))
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: Color.black.opacity(0.25), radius: 1, y: 0.5)
    }

    // MARK: - Text

    private var summary: String {
        let distinct = distinctValues
        if distinct.count == 2 {
            return L.SettingsNotification.thresholdTwo(distinct[0], distinct[1])
        }
        return L.SettingsNotification.thresholdSingle(distinct.first ?? range.upperBound)
    }

    /// 按位置给滑钮命名：两个值不同时左边是第一次提醒，否则就是唯一的一次提醒
    private func positionLabel(for value: Int) -> String {
        let distinct = distinctValues
        guard distinct.count == 2 else { return L.SettingsNotification.reminder }
        return value == distinct[0] ? L.SettingsNotification.firstReminder : L.SettingsNotification.secondReminder
    }

    // MARK: - Geometry

    /// 滑钮中心的 x 坐标。两端各留半个滑钮宽度，滑钮不会画出轨道
    private func xPosition(for value: Int, width: CGFloat) -> CGFloat {
        let usable = max(width - thumbSize, 1)
        let fraction = CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
        return thumbSize / 2 + usable * fraction
    }

    /// x 坐标换算成吸附到步长、夹在范围内的阈值
    private func value(at x: CGFloat, width: CGFloat) -> Int {
        let usable = max(width - thumbSize, 1)
        let fraction = min(max((x - thumbSize / 2) / usable, 0), 1)
        let raw = Double(range.lowerBound) + Double(fraction) * Double(range.upperBound - range.lowerBound)
        let snapped = Int((raw / Double(step)).rounded()) * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }

    // MARK: - Interaction

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                var draft = draftValues ?? values
                guard !draft.isEmpty else { return }
                let index: Int
                if let activeIndex {
                    index = activeIndex
                } else {
                    // 抓离按下位置最近的滑钮（点击轨道也会让它跳过去）；
                    // 两个滑钮重合时抓哪个都一样，文字只看位置
                    index = draft.indices.min { lhs, rhs in
                        abs(xPosition(for: draft[lhs], width: width) - gesture.startLocation.x)
                            < abs(xPosition(for: draft[rhs], width: width) - gesture.startLocation.x)
                    } ?? 0
                    activeIndex = index
                }
                draft[index] = value(at: gesture.location.x, width: width)
                draftValues = draft
            }
            .onEnded { _ in
                if let draft = draftValues, draft.sorted() != values.sorted() {
                    onCommit(draft.sorted())
                }
                draftValues = nil
                activeIndex = nil
            }
    }

    private func adjust(index: Int, direction: AccessibilityAdjustmentDirection) {
        var newValues = values
        guard newValues.indices.contains(index) else { return }
        switch direction {
        case .increment:
            newValues[index] = min(range.upperBound, newValues[index] + step)
        case .decrement:
            newValues[index] = max(range.lowerBound, newValues[index] - step)
        @unknown default:
            return
        }
        if newValues.sorted() != values.sorted() {
            onCommit(newValues.sorted())
        }
    }
}
