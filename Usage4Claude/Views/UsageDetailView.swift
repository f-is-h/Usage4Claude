//
//  UsageDetailView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 用量详情视图
/// 显示 Claude 的当前使用情况，包括百分比进度条、倒计时和重置时间
struct UsageDetailView: View {
    @Binding var usageData: UsageData?
    @Binding var errorMessage: String?
    /// 菜单操作回调
    var onMenuAction: ((MenuAction) -> Void)? = nil
    @StateObject private var localization = LocalizationManager.shared
    
    /// 菜单操作类型
    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        case about
        case webUsage
        case coffee
        case quit
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                // 应用图标（不使用template模式）
                if let icon = createAppIcon(size: 20) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.blue)
                }
                
                Text(L.Usage.title)
                    .font(.headline)
                
                Spacer()
                
                // 三点菜单按钮
                Menu {
                    Button(L.Menu.generalSettings) {
                        onMenuAction?(.generalSettings)
                    }
                    Button(L.Menu.authSettings) {
                        onMenuAction?(.authSettings)
                    }
                    Button(L.Menu.checkUpdates) {
                        onMenuAction?(.checkForUpdates)
                    }
                    Button(L.Menu.about) {
                        onMenuAction?(.about)
                    }
                    Divider()
                    Button(L.Menu.webUsage) {
                        onMenuAction?(.webUsage)
                    }
                    Button(L.Menu.coffee) {
                        onMenuAction?(.coffee)
                    }
                    Divider()
                    Button(L.Menu.quit) {
                        onMenuAction?(.quit)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal)
            .padding(.top)
            
            if let error = errorMessage {
                // 错误信息
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    // 如果是认证信息错误，显示设置按钮
                    if error.contains("认证") || error.contains("配置") || error.contains("Authentication") || error.contains("configured") {
                        Button(action: {
                            onMenuAction?(.authSettings)
                        }) {
                            Text(L.Usage.goToSettings)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            } else if let data = usageData {
                // 使用数据
                VStack(spacing: 20) {
                    // 圆形进度条
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(data.percentage) / 100.0)
                            .stroke(
                                colorForPercentage(data.percentage),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: data.percentage)
                        
                        VStack(spacing: 2) {
                            Text("\(Int(data.percentage))%")
                                .font(.system(size: 28, weight: .bold))
                            Text(L.Usage.used)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 详细信息
                    VStack(spacing: 8) {
                        InfoRow(
                            icon: "clock.fill",
                            title: L.Usage.fiveHourLimit,
                            value: data.formattedResetsIn
                        )
                        
                        InfoRow(
                            icon: "arrow.clockwise",
                            title: L.Usage.resetTime,
                            value: data.formattedResetTime
                        )
                    }
                    .padding(.horizontal)
                }
            } else {
                // 加载中
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(L.Usage.loading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            }
            
            Spacer()
        }
        .frame(width: 280, height: 240)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
    }
    
    // MARK: - Helper Methods
    
    /// 根据使用百分比返回对应的颜色
    /// - 0-70%: 绿色（安全）
    /// - 70-90%: 橙色（警告）
    /// - 90-100%: 红色（危险）
    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage < 70 {
            return .green
        } else if percentage < 90 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// 创建应用图标（非模板模式）
    private func createAppIcon(size: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        let iconCopy = appIcon.copy() as! NSImage
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: size, height: size)
        return iconCopy
    }
}

// MARK: - Supporting Views

/// 信息行组件
/// 显示一行信息，包含图标、标题和值
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// 预览
struct UsageDetailView_Previews: PreviewProvider {
    @State static var sampleData: UsageData? = UsageData(
        percentage: 45,
        resetsAt: Date().addingTimeInterval(3600 * 2.5)
    )
    
    @State static var errorMsg: String? = nil
    
    static var previews: some View {
        UsageDetailView(usageData: $sampleData, errorMessage: $errorMsg)
    }
}
