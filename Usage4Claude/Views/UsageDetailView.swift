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
    @ObservedObject var refreshState: RefreshState
    /// 菜单操作回调
    var onMenuAction: ((MenuAction) -> Void)? = nil
    @StateObject private var localization = LocalizationManager.shared
    /// 🆕 是否有可用更新（用于显示文字和徽章）
    var hasAvailableUpdate: Bool = false
    /// 🆕 是否应显示更新徽章（用户未确认时才显示徽章）
    var shouldShowUpdateBadge: Bool = false
    
    /// 加载动画效果类型
    enum LoadingAnimationType: Int, CaseIterable {
        case rainbow = 0   // 彩虹渐变旋转
        case dashed = 1    // 虚线旋转
        case pulse = 2     // 脉冲效果

        var name: String {
            switch self {
            case .rainbow: return "彩虹渐变"
            case .dashed: return "虚线旋转"
            case .pulse: return "脉冲效果"
            }
        }
    }

    // 当前使用的加载动画类型（可长按圆环切换）
    @State private var animationType: LoadingAnimationType = .rainbow
    
    /// 菜单操作类型
    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        case about
        case webUsage
        case coffee
        case quit
        case refresh      // 🆕 手动刷新
    }
    
    // 用于动画的状态（改为从外部传入，避免每次重建视图时重置）
    @State private var rotationAngle: Double = 0
    @State private var animationTimer: Timer?
    // 🆕 显示动画类型切换提示
    @State private var showAnimationTypeHint = false
    // 🆕 显示更新通知
    @State private var showUpdateNotification = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                // 应用图标（不使用template模式）
                if let icon = ImageHelper.createAppIcon(size: 20) {
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
                
                // 🆕 刷新按钮（左侧）
                Button(action: {
                    onMenuAction?(.refresh)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .opacity(refreshState.canRefresh ? 1.0 : 0.3)
                        .rotationEffect(.degrees(refreshState.isRefreshing ? rotationAngle : 0))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(!refreshState.canRefresh || refreshState.isRefreshing)
                .focusable(false)  // 🆕 禁用Focus状态
                .onAppear {
                    // 如果打开时已经在刷新，启动动画
                    if refreshState.isRefreshing {
                        startRotationAnimation()
                    }
                }
                .onChange(of: refreshState.isRefreshing) { newValue in
                    if newValue {
                        startRotationAnimation()
                    } else {
                        stopRotationAnimation()
                    }
                }
                
                // 🆕 三点菜单按钮（右侧） + 徽章
                ZStack(alignment: .topTrailing) {
                    Menu {
                        Button(action: { onMenuAction?(.generalSettings) }) {
                            Label(L.Menu.generalSettings, systemImage: "gearshape")
                        }
                        Button(action: { onMenuAction?(.authSettings) }) {
                            Label(L.Menu.authSettings, systemImage: "key")
                        }

                        // 🆕 检查更新菜单项（根据是否有更新显示不同样式）
                        if hasAvailableUpdate {
                            Button(action: { onMenuAction?(.checkForUpdates) }) {
                                Label {
                                    Text(createUpdateMenuText())
                                } icon: {
                                    Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                                }
                            }
                        } else {
                            Button(action: { onMenuAction?(.checkForUpdates) }) {
                                Label(L.Menu.checkUpdates, systemImage: "arrow.triangle.2.circlepath")
                            }
                        }

                        Button(action: { onMenuAction?(.about) }) {
                            Label(L.Menu.about, systemImage: "info.circle")
                        }
                        Divider()
                        Button(action: { onMenuAction?(.webUsage) }) {
                            Label(L.Menu.webUsage, systemImage: "safari")
                        }
                        Button(action: { onMenuAction?(.coffee) }) {
                            Label(L.Menu.coffee, systemImage: "cup.and.saucer")
                        }
                        Divider()
                        Button(action: { onMenuAction?(.quit) }) {
                            Label(L.Menu.quit, systemImage: "power")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(90))
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .buttonStyle(.plain)
                    .focusable(false)

                    // 🆕 徽章（小红点）- 仅在用户未确认时显示
                    if shouldShowUpdateBadge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 5, y: -5)
                    }
                }
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

                    // 操作按钮组
                    HStack(spacing: 12) {
                        // 如果是认证信息错误，显示设置按钮
                        if error.contains("认证") || error.contains("配置") || error.contains("Authentication") || error.contains("configured") {
                            Button(action: {
                                onMenuAction?(.authSettings)
                            }) {
                                Label(L.Usage.goToSettings, systemImage: "key.fill")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        // 诊断连接按钮（所有错误都显示）
                        Button(action: {
                            onMenuAction?(.authSettings)
                            // 注意：实际会打开认证设置标签页，诊断功能在该页面底部
                        }) {
                            Label(L.Usage.runDiagnostic, systemImage: "stethoscope")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange)
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
                        // 背景圆环
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 100, height: 100)

                        if refreshState.isRefreshing {
                            // 🆕 加载动画
                            loadingAnimation()
                        } else {
                            // 正常进度条
                            Circle()
                                .trim(from: 0, to: CGFloat(data.percentage) / 100.0)
                                .stroke(
                                    colorForPercentage(data.percentage),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: data.percentage)
                        }

                        // 🆕 中间显示区域：正常百分比（不再在这里显示通知）
                        VStack(spacing: 2) {
                            Text("\(Int(data.percentage))%")
                                .font(.system(size: 28, weight: .bold))
                            Text(L.Usage.used)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Circle())  // 🆕 定义可点击区域为整个圆形
                    .onTapGesture {
                        // 🆕 点击圆环刷新数据
                        if refreshState.canRefresh && !refreshState.isRefreshing {
                            onMenuAction?(.refresh)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 3.0) {
                        // 🆕 长按圆环切换动画类型
                        let allTypes = LoadingAnimationType.allCases
                        let currentIndex = allTypes.firstIndex(of: animationType) ?? 0
                        let nextIndex = (currentIndex + 1) % allTypes.count
                        animationType = allTypes[nextIndex]

                        // 显示提示
                        withAnimation {
                            showAnimationTypeHint = true
                        }
                        // 2秒后隐藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showAnimationTypeHint = false
                            }
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

            // 🆕 动画类型提示（长按圆环切换）
            if showAnimationTypeHint {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("加载动画: \(animationType.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.horizontal, 12)
                .padding(.top, -8)  // 向上移动，与更新通知一致
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .scale))
            }

            // 🆕 更新通知提示（在圆环下方显示）
            if showUpdateNotification {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    rainbowText(L.Update.Notification.available)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.top, -8)  // 向上移动
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()
        }
        .frame(width: 280, height: 240)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
        .onAppear {
            // 🆕 如果有更新通知消息，显示通知
            if refreshState.notificationMessage != nil {
                withAnimation {
                    showUpdateNotification = true
                }
                // 3秒后隐藏通知
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showUpdateNotification = false
                    }
                }
            }
        }
        .onChange(of: refreshState.notificationMessage) { message in
            // 🆕 监听通知消息变化
            if message != nil {
                withAnimation {
                    showUpdateNotification = true
                }
                // 3秒后隐藏通知
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showUpdateNotification = false
                    }
                }
            } else {
                withAnimation {
                    showUpdateNotification = false
                }
            }
        }
        .onDisappear {
            // 视图消失时清理定时器
            stopRotationAnimation()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 启动旋转动画
    private func startRotationAnimation() {
        // 清除旧的定时器
        stopRotationAnimation()

        // 重置角度
        rotationAngle = 0

        // 创建新的定时器，每 0.016 秒更新一次（约 60fps）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                rotationAngle += 6  // 每帧旋转 6 度，1秒完成一圈
                if rotationAngle >= 360 {
                    rotationAngle -= 360
                }
            }
        }
    }

    /// 停止旋转动画
    private func stopRotationAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.default) {
            rotationAngle = 0
        }
    }
    
    /// 加载动画视图
    /// 根据animationType返回不同的加载效果
    @ViewBuilder
    private func loadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            rainbowLoadingAnimation()
        case .dashed:
            dashedLoadingAnimation()
        case .pulse:
            pulseLoadingAnimation()
        }
    }
    
    /// 效果1：彩虹渐变旋转（推荐）
    private func rainbowLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .blue]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(rotationAngle))
    }
    
    /// 效果2：虚线旋转
    private func dashedLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 1)
            .stroke(
                Color.blue,
                style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8])
            )
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(rotationAngle))
    }
    
    /// 效果3：脉冲效果
    private func pulseLoadingAnimation() -> some View {
        ZStack {
            // 内圈 - 快速脉冲
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    Color.blue.opacity(0.8),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(rotationAngle))
            
            // 外圈 - 慢速脉冲
            Circle()
                .trim(from: 0, to: 0.4)
                .stroke(
                    Color.blue.opacity(0.4),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
        }
    }
    
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

    /// 🆕 创建彩虹文字
    /// - Parameter text: 要显示的文本
    /// - Returns: 带彩虹效果的文本视图
    @ViewBuilder
    private func rainbowText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    /// 🆕 创建菜单更新文本（部分文字带颜色）
    /// - Returns: 带颜色的AttributedString
    private func createUpdateMenuText() -> AttributedString {
        let baseText = L.Menu.checkUpdates
        let badgeText = L.Update.Notification.badgeShort
        let fullText = baseText + "   " + badgeText

        var attributedString = AttributedString(fullText)

        // 找到徽章文本的范围并设置颜色
        if let range = attributedString.range(of: badgeText) {
            attributedString[range].foregroundColor = .orange
        }

        return attributedString
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
    @StateObject static var refreshState = RefreshState()

    static var previews: some View {
        UsageDetailView(
            usageData: $sampleData,
            errorMessage: $errorMsg,
            refreshState: refreshState
        )
    }
}
