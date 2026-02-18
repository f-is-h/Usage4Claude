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
    /// 是否有可用更新（用于显示文字和徽章）
    @Binding var hasAvailableUpdate: Bool
    /// 是否应显示更新徽章（用户未确认时才显示徽章）
    @Binding var shouldShowUpdateBadge: Bool
    
    /// 加载动画效果类型
    enum LoadingAnimationType: Int, CaseIterable {
        case rainbow = 0   // 彩虹渐变旋转
        case dashed = 1    // 虚线旋转
        case pulse = 2     // 脉冲效果

        var name: String {
            switch self {
            case .rainbow: return L.LoadingAnimation.rainbow
            case .dashed: return L.LoadingAnimation.dashed
            case .pulse: return L.LoadingAnimation.pulse
            }
        }
    }

    // 当前使用的加载动画类型（可长按圆环切换）
    @State var animationType: LoadingAnimationType = .rainbow
    
    /// 菜单操作类型
    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        case about
        case webUsage
        case coffee
        case githubSponsor
        case quit
        case refresh
    }
    
    // 用于动画的状态（改为从外部传入，避免每次重建视图时重置）
    @State var rotationAngle: Double = 0
    @State var animationTimer: Timer?
    // 显示动画类型切换提示
    @State private var showAnimationTypeHint = false
    // 显示更新通知
    @State private var showUpdateNotification = false
    // 显示模式切换（false: 重置时间, true: 剩余时间）
    @AppStorage("showRemainingMode") private var savedRemainingMode = false
    @State private var showRemainingMode = false
    
    // MARK: - Body

    /// 获取当前活动的显示类型
    private var activeDisplayTypes: [LimitType] {
        guard let data = usageData else { return [] }
        return UserSettings.shared.getActiveDisplayTypes(usageData: data)
    }

    /// 根据活动类型数量计算动态高度
    private var dynamicHeight: CGFloat {
        let activeCount = activeDisplayTypes.count

        // 统一使用动态计算，确保底部边距一致
        // 基础高度：圆环、标题、上下边距等固定内容的总高度
        // 每行实际高度：文字(12pt) + vertical padding(12pt) + 背景高度 ≈ 26pt
        // 行间距：5pt
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5

        // 单限制固定显示2行，双限制和3+限制显示对应行数
        let rowCount = activeCount == 1 ? 2 : activeCount
        let textHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing

        return baseHeight + textHeight
    }

    var body: some View {
        VStack(spacing: activeDisplayTypes.count >= 2 ? 10 : 16) {  // 多限制时减小间距
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
                
                // 刷新按钮（左侧）
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
                .focusable(false)  // 禁用Focus状态
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
                
                // 三点菜单按钮（右侧） + 徽章
                ZStack(alignment: .topTrailing) {
                    Menu {
                        // 账户切换子菜单（仅当有多个账户时显示）
                        if UserSettings.shared.accounts.count > 1 {
                            Menu {
                                ForEach(UserSettings.shared.accounts) { account in
                                    Button(action: {
                                        UserSettings.shared.switchToAccount(account)
                                    }) {
                                        HStack {
                                            Text(account.displayName)
                                            if account.id == UserSettings.shared.currentAccountId {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                let name = UserSettings.shared.currentAccountName ?? L.Menu.account
                                Label("\(L.Menu.accountPrefix) \(name)", systemImage: "person.2")
                            }
                            Divider()
                        }

                        Button(action: { onMenuAction?(.generalSettings) }) {
                            Label(L.Menu.generalSettings, systemImage: "gearshape")
                        }
                        Button(action: { onMenuAction?(.authSettings) }) {
                            Label(L.Menu.authSettings, systemImage: "key")
                        }

                        // 检查更新菜单项（根据是否有更新显示不同样式）
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
                        Button(action: { onMenuAction?(.githubSponsor) }) {
                            Label(L.Menu.githubSponsor, systemImage: "heart")
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

                    // 徽章（小红点）- 仅在用户未确认时显示
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
                VStack(spacing: 15) {  // 双模式时两行文字的上间距
                    // 圆形进度条
                    ZStack {
                        // 根据用户选择的显示类型确定主要限制
                        let primaryLimitData = getPrimaryLimitData(data: data, activeTypes: activeDisplayTypes)

                        if let primary = primaryLimitData {
                            // 1. 主圆环背景（灰色）
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)

                            if refreshState.isRefreshing {
                                // 加载动画
                                loadingAnimation()
                            } else {
                                // 2. 主进度条（根据用户选择的限制类型）
                                Circle()
                                    .trim(from: 0, to: CGFloat(primary.percentage) / 100.0)
                                    .stroke(
                                        colorForPrimaryByActiveTypes(data: data, activeTypes: activeDisplayTypes),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut, value: primary.percentage)
                            }

                            // 3. 外层细圆环（仅在用户同时选择了5h和7d限制时显示）
                            if activeDisplayTypes.contains(.fiveHour) &&
                               activeDisplayTypes.contains(.sevenDay) {
                                // 在自定义模式下，即使数据为 nil 也显示占位圆环
                                let sevenDayPercentage = data.sevenDay?.percentage ?? (UserSettings.shared.displayMode == .custom ? 0 : nil)

                                if let percentage = sevenDayPercentage {
                                    // 7天背景圆环（灰色）
                                    Circle()
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                        .frame(width: 114, height: 114)

                                    if refreshState.isRefreshing {
                                        // 刷新时显示对应类型的外侧圆环动画（逆时针旋转）
                                        outerLoadingAnimation()
                                    } else {
                                        // 7天进度条（紫色系）
                                        Circle()
                                            .trim(from: 0, to: CGFloat(percentage) / 100.0)
                                            .stroke(
                                                colorForSevenDay(percentage),
                                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                            )
                                            .frame(width: 114, height: 114)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.easeInOut, value: percentage)
                                    }
                                }
                            }

                            // 4. 中间显示区域：百分比（显示主要限制的百分比）
                            VStack(spacing: 2) {
                                Text("\(Int(primary.percentage))%")
                                    .font(.system(size: 28, weight: .bold))
                                Text(L.Usage.used)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 114)  // 固定高度，确保有无双圆环时高度一致
                    .contentShape(Circle())  // 定义可点击区域为整个圆形
                    .onTapGesture {
                        // 点击圆环刷新数据
                        if refreshState.canRefresh && !refreshState.isRefreshing {
                            onMenuAction?(.refresh)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 3.0) {
                        // 长按圆环切换动画类型
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

                    // 详细信息 - 根据用户选择的显示类型数量使用不同的显示方式
                    VStack(spacing: 8) {
                        let activeTypes = activeDisplayTypes

                        if activeTypes.count >= 3 {
                            // 场景3: 3种及以上限制，使用统一行显示
                            VStack(spacing: 5) {
                                ForEach(activeTypes, id: \.self) { type in
                                    UnifiedLimitRow(
                                        type: type,
                                        data: data,
                                        showRemainingMode: showRemainingMode
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRemainingMode.toggle()
                                }
                                savedRemainingMode = showRemainingMode
                            }
                        } else if activeTypes.count == 2 {
                            // 场景2：用户选择了2种限制，使用统一行显示
                            VStack(spacing: 5) {
                                ForEach(activeTypes, id: \.self) { type in
                                    UnifiedLimitRow(
                                        type: type,
                                        data: data,
                                        showRemainingMode: showRemainingMode
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRemainingMode.toggle()
                                }
                                savedRemainingMode = showRemainingMode
                            }
                        } else if activeTypes.count == 1 {
                            // 场景1：用户只选择了1种限制，使用大圆环+2行信息显示
                            let singleType = activeTypes.first!

                            if singleType == .fiveHour, let fiveHour = data.fiveHour {
                                // 场景1a：只显示5小时限制
                                VStack(spacing: 5) {
                                    InfoRow(
                                        icon: "clock.fill",
                                        title: L.Usage.fiveHourLimit,
                                        value: fiveHour.formattedResetsInHours
                                    )

                                    InfoRow(
                                        icon: "arrow.clockwise",
                                        title: L.Usage.resetTime,
                                        value: fiveHour.formattedResetTimeShort
                                    )
                                }
                            } else if singleType == .sevenDay, let sevenDay = data.sevenDay {
                                // 场景1b：只显示7天限制（使用紫色）
                                VStack(spacing: 5) {
                                    InfoRow(
                                        icon: "calendar",
                                        title: L.Usage.sevenDayLimit,
                                        value: sevenDay.formattedResetsInDays,
                                        tintColor: .purple
                                    )

                                    InfoRow(
                                        icon: "calendar.badge.clock",
                                        title: L.Usage.resetDate,
                                        value: sevenDay.formattedResetDateLong,
                                        tintColor: .purple
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
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

            // 动画类型提示（长按圆环切换）
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
                    Text(L.LoadingAnimation.current(animationType.name))
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

            // 更新通知提示（在圆环下方显示）
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
        .frame(width: 290, height: dynamicHeight)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
        .onAppear {
            // 恢复上次保存的显示模式
            showRemainingMode = savedRemainingMode
            // 如果有更新通知消息，显示通知
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
            // 监听通知消息变化
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
            // 视图消失时清理定时器和重置状态
            stopRotationAnimation()
        }
        #if DEBUG
        .background(
            UserSettings.shared.debugKeepDetailWindowOpen ? Color.white : Color.clear
        )
        #endif
    }
}

// 预览
struct UsageDetailView_Previews: PreviewProvider {
    @State static var sampleData: UsageData? = UsageData(
        fiveHour: UsageData.LimitData(
            percentage: 45,
            resetsAt: Date().addingTimeInterval(3600 * 2.5)
        ),
        sevenDay: nil,
        opus: nil,
        sonnet: nil,
        extraUsage: nil
    )

    @State static var errorMsg: String? = nil
    @StateObject static var refreshState = RefreshState()
    @State static var hasUpdate = false
    @State static var shouldShowBadge = false

    static var previews: some View {
        UsageDetailView(
            usageData: $sampleData,
            errorMessage: $errorMsg,
            refreshState: refreshState,
            hasAvailableUpdate: $hasUpdate,
            shouldShowUpdateBadge: $shouldShowBadge
        )
    }
}
