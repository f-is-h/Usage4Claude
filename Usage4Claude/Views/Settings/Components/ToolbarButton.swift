//
//  ToolbarButton.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// Toolbar 风格的按钮组件
struct ToolbarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isSelected ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())  // 扩大点击区域到整个背景
        }
        .buttonStyle(.plain)
        .focusable(false)  // 移除Focus效果
    }
}
