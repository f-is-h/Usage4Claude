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
    @Binding var codexUsageData: CodexUsageData?
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

    // Claude 列加载动画类型（可长按圆环切换）
    @State var claudeAnimationType: LoadingAnimationType = .rainbow
    // Codex 列加载动画类型（独立）
    @State var codexAnimationType: LoadingAnimationType = .rainbow

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
        case refreshClaude
        case refreshCodex
    }
    
    // 用于动画的状态（改为从外部传入，避免每次重建视图时重置）
    @State var rotationAngle: Double = 0
    @State var animationTimer: Timer?
    // 显示动画类型切换提示
    @State private var showAnimationTypeHint = false
    @State private var animationTypeHintName = ""
    @State private var animationTypeHintProvider: ProviderType?
    @State private var animationTypeHintDismissWorkItem: DispatchWorkItem?
    // 显示更新通知
    @State private var showUpdateNotification = false
    // 显示模式切换（false: 重置时间, true: 剩余时间）
    @AppStorage("showRemainingMode") private var savedRemainingMode = false
    @State private var showRemainingMode = false
    
    // MARK: - Body

    private var isMultiProviderActive: Bool {
        UserSettings.shared.isMultiProviderActive && codexUsageData != nil
    }

    private var isCodexOnlyActive: Bool {
        !isMultiProviderActive
            && ((!UserSettings.shared.hasValidCredentials && UserSettings.shared.hasValidCodexCredentials)
                || (usageData == nil && codexUsageData != nil))
    }

    private var isClaudeRefreshing: Bool {
        refreshState.isRefreshingProvider(.claude)
    }

    /// 获取当前 Claude 活动的显示类型
    private var activeDisplayTypes: [LimitType] {
        guard let data = usageData else { return [] }
        return UserSettings.shared.getActiveDisplayTypes(usageData: data)
            .filter { $0.provider == .claude }
    }

    /// 获取当前 Codex 活动的显示类型
    private var activeCodexDisplayTypes: [LimitType] {
        guard let codex = codexUsageData else { return [] }
        return UserSettings.shared.getActiveDisplayTypes(usageData: nil, codexUsageData: codex)
            .filter { $0.provider == .codex }
    }

    /// 根据活动类型数量计算动态高度（单 Provider 模式）
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

    /// Codex-only 模式的动态高度
    private var codexOnlyHeight: CGFloat {
        let activeCount = activeCodexDisplayTypes.count
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5
        let rowCount = activeCount == 1 ? 2 : max(activeCount, codexUsageData == nil ? 0 : 1)
        let textHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing

        return baseHeight + textHeight
    }

    /// 双 Provider 模式的动态高度（取两列最大行数）
    private var multiProviderHeight: CGFloat {
        let claudeRowCount: Int
        if let data = usageData {
            let types = UserSettings.shared.getActiveDisplayTypes(usageData: data)
                .filter { $0.provider == .claude }
            claudeRowCount = types.count == 1 ? 2 : max(types.count, 1)
        } else {
            claudeRowCount = 2
        }

        let codexRowCount: Int
        if let codex = codexUsageData {
            let types = UserSettings.shared.getActiveDisplayTypes(usageData: nil, codexUsageData: codex)
                .filter { $0.provider == .codex }
            codexRowCount = max(types.count, 1)
        } else {
            codexRowCount = 1
        }

        let maxRows = max(claudeRowCount, codexRowCount)
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5
        let rowsHeight = CGFloat(maxRows) * rowHeight + CGFloat(max(0, maxRows - 1)) * spacing
        return 190 + rowsHeight
    }

    private var contentSpacing: CGFloat {
        let visibleTypeCount = isCodexOnlyActive ? activeCodexDisplayTypes.count : activeDisplayTypes.count
        return visibleTypeCount >= 2 ? 10 : 16
    }

    private var multiProviderDividerHeight: CGFloat {
        max(35, multiProviderHeight - 28)
    }

    private var contentWidth: CGFloat {
        isMultiProviderActive ? 580 : 290
    }

    private var contentHeight: CGFloat {
        if isMultiProviderActive {
            return multiProviderHeight
        }
        if isCodexOnlyActive {
            return codexOnlyHeight
        }
        return dynamicHeight
    }

    @ViewBuilder
    private var claudeMainContent: some View {
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
            VStack(spacing: 15) {
                // 圆形进度条
                ZStack {
                    let primaryLimitData = getPrimaryLimitData(data: data, activeTypes: activeDisplayTypes)

                    if let primary = primaryLimitData {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 100, height: 100)

                        if isClaudeRefreshing {
                            loadingAnimation()
                        } else {
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

                        if activeDisplayTypes.contains(.fiveHour) &&
                           activeDisplayTypes.contains(.sevenDay) {
                            let sevenDayPercentage = data.sevenDay?.percentage ?? (UserSettings.shared.displayMode == .custom ? 0 : nil)

                            if let percentage = sevenDayPercentage {
                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                    .frame(width: 114, height: 114)

                                if isClaudeRefreshing {
                                    outerLoadingAnimation()
                                } else {
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

                        VStack(spacing: 2) {
                            Text("\(Int(primary.percentage))%")
                                .font(.system(size: 28, weight: .bold))
                            Text(L.Usage.used)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 114)
                .contentShape(Circle())
                .onTapGesture {
                    if refreshState.canRefresh && !refreshState.isRefreshing {
                        onMenuAction?(.refreshClaude)
                    }
                }
                .onLongPressGesture(minimumDuration: 3.0) {
                    let allTypes = LoadingAnimationType.allCases
                    let currentIndex = allTypes.firstIndex(of: claudeAnimationType) ?? 0
                    let nextIndex = (currentIndex + 1) % allTypes.count
                    claudeAnimationType = allTypes[nextIndex]

                    showAnimationHint(claudeAnimationType.name, provider: .claude)
                }

                VStack(spacing: 8) {
                    let activeTypes = activeDisplayTypes

                    if activeTypes.count >= 2 {
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
                            withAnimation(.easeInOut(duration: 0.2)) { showRemainingMode.toggle() }
                            savedRemainingMode = showRemainingMode
                        }
                    } else if activeTypes.count == 1 {
                        let singleType = activeTypes.first!

                        if singleType == .fiveHour, let fiveHour = data.fiveHour {
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
    }

    // MARK: - Header Buttons

    /// 刷新按钮 + 三点菜单按钮（共用于单列和双列头部）
    @ViewBuilder
    private var refreshAndMenuButtons: some View {
        Button(action: { onMenuAction?(.refresh) }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .opacity(refreshState.canRefresh ? 1.0 : 0.3)
                .rotationEffect(.degrees(refreshState.isRefreshing ? rotationAngle : 0))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .disabled(!refreshState.canRefresh || refreshState.isRefreshing)
        .focusable(false)

        ZStack(alignment: .topTrailing) {
            Menu {
                if UserSettings.shared.accounts.count > 1 {
                    Menu {
                        ForEach(UserSettings.shared.accounts) { account in
                            Button(action: { UserSettings.shared.switchToAccount(account) }) {
                                HStack {
                                    Text(account.displayName)
                                    if account.id == UserSettings.shared.currentAccountId {
                                        Spacer(); Image(systemName: "checkmark")
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

                if UserSettings.shared.codexAccounts.count > 1 {
                    Menu {
                        ForEach(UserSettings.shared.codexAccounts) { account in
                            Button(action: { UserSettings.shared.switchToCodexAccount(account) }) {
                                HStack {
                                    Text(account.displayName)
                                    if account.id == UserSettings.shared.currentCodexAccountId {
                                        Spacer(); Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        let name = UserSettings.shared.currentCodexAccount?.displayName ?? "Codex"
                        Label("Codex: \(name)", systemImage: "person.2.fill")
                    }
                    Divider()
                }

                Button(action: { onMenuAction?(.generalSettings) }) {
                    Label(L.Menu.generalSettings, systemImage: "gearshape")
                }
                Button(action: { onMenuAction?(.authSettings) }) {
                    Label(L.Menu.authSettings, systemImage: "key")
                }
                if hasAvailableUpdate {
                    Button(action: { onMenuAction?(.checkForUpdates) }) {
                        Label { Text(createUpdateMenuText()) } icon: {
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

            if shouldShowUpdateBadge {
                Circle().fill(Color.red).frame(width: 6, height: 6).offset(x: 5, y: -5)
            }
        }
    }

    @ViewBuilder
    private func headerView(provider: ProviderType, showsControls: Bool) -> some View {
        let headerIconSize: CGFloat = 18
        let headerRowHeight: CGFloat = 20
        HStack {
            if provider == .claude {
                if let icon = ImageHelper.createAppIcon(size: headerIconSize) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: headerIconSize, height: headerIconSize)
                } else {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.blue)
                }
            } else if let icon = ImageHelper.createCodexIcon(size: headerIconSize) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: headerIconSize, height: headerIconSize)
            }

            Text(provider == .claude ? L.Usage.title : L.Usage.codexTitle)
                .font(.headline)

            Spacer()

            if showsControls {
                refreshAndMenuButtons
            }
        }
        .frame(height: headerRowHeight, alignment: .center)
        .padding(.horizontal)
        .padding(.top)
    }

    @ViewBuilder
    private var updateNotificationView: some View {
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
            .padding(.top, -8)
            .padding(.bottom, 6)
            .transition(.opacity.combined(with: .scale))
        }
    }

    @ViewBuilder
    private func codexOnlyMainContent(codex: CodexUsageData?) -> some View {
        if let codex {
            CodexColumnView(
                codexUsageData: codex,
                showRemainingMode: $showRemainingMode,
                refreshState: refreshState,
                animationType: $codexAnimationType,
                rotationAngle: $rotationAngle,
                onRefresh: { onMenuAction?(.refreshCodex) },
                onAnimationHint: { showAnimationHint($0, provider: .codex) }
            )
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
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

                    Button(action: {
                        onMenuAction?(.authSettings)
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
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(L.Usage.loading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
        }
    }

    private var singleProviderBody: some View {
        VStack(spacing: contentSpacing) {
            VStack(spacing: contentSpacing) {
                headerView(provider: .claude, showsControls: true)
                claudeMainContent
            }
            .offset(y: isAnimationHintVisible(for: .claude) ? -18 : 0)

            animationHintView(for: .claude)
            updateNotificationView
            Spacer()
        }
    }

    private func codexOnlyBody(codex: CodexUsageData?) -> some View {
        VStack(spacing: contentSpacing) {
            VStack(spacing: contentSpacing) {
                headerView(provider: .codex, showsControls: true)
                codexOnlyMainContent(codex: codex)
            }
            .offset(y: isAnimationHintVisible(for: .codex) ? -18 : 0)

            animationHintView(for: .codex)
            updateNotificationView
            Spacer()
        }
    }

    private func multiProviderBody(codex: CodexUsageData) -> some View {
        VStack(spacing: contentSpacing) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: contentSpacing) {
                    ZStack(alignment: .bottom) {
                        VStack(spacing: contentSpacing) {
                            headerView(provider: .claude, showsControls: false)
                            claudeMainContent
                        }
                        .offset(y: isAnimationHintVisible(for: .claude) ? -18 : 0)
                    }
                    .overlay(alignment: .bottom) {
                        animationHintOverlay(for: .claude)
                    }
                }
                .frame(width: 290, alignment: .top)

                VStack(spacing: contentSpacing) {
                    ZStack(alignment: .bottom) {
                        VStack(spacing: contentSpacing) {
                            headerView(provider: .codex, showsControls: true)
                            CodexColumnView(
                                codexUsageData: codex,
                                showRemainingMode: $showRemainingMode,
                                refreshState: refreshState,
                                animationType: $codexAnimationType,
                                rotationAngle: $rotationAngle,
                                onRefresh: { onMenuAction?(.refreshCodex) },
                                onAnimationHint: { showAnimationHint($0, provider: .codex) }
                            )
                        }
                        .offset(y: isAnimationHintVisible(for: .codex) ? -18 : 0)
                    }
                    .overlay(alignment: .bottom) {
                        animationHintOverlay(for: .codex)
                    }
                }
                .frame(width: 290, alignment: .top)
            }
            .overlay(alignment: .center) {
                ProviderDivider(height: multiProviderDividerHeight)
                    .allowsHitTesting(false)
            }

            updateNotificationView
            Spacer()
        }
    }

    private func isAnimationHintVisible(for provider: ProviderType) -> Bool {
        showAnimationTypeHint && animationTypeHintProvider == provider
    }

    @ViewBuilder
    private func animationHintView(for provider: ProviderType) -> some View {
        if isAnimationHintVisible(for: provider) {
            animationHintContent
                .transition(.opacity.combined(with: .scale))
        }
    }

    @ViewBuilder
    private func animationHintOverlay(for provider: ProviderType) -> some View {
        if isAnimationHintVisible(for: provider) {
            animationHintContent
                .offset(y: contentSpacing + 2)
                .transition(.opacity.combined(with: .scale))
        }
    }

    private var animationHintContent: some View {
        AnimationTypeHintView(animationTypeName: animationTypeHintName)
            .padding(.top, -8)
            .padding(.bottom, 6)
            .allowsHitTesting(false)
    }

    var body: some View {
        Group {
            if isMultiProviderActive, let codex = codexUsageData {
                multiProviderBody(codex: codex)
            } else if isCodexOnlyActive {
                codexOnlyBody(codex: codexUsageData)
            } else {
                singleProviderBody
            }
        }
        .frame(width: contentWidth, height: contentHeight)
        .animation(.easeInOut(duration: 0.25), value: isMultiProviderActive)
        .animation(.easeInOut(duration: 0.25), value: isCodexOnlyActive)
        .animation(.easeInOut(duration: 0.25), value: showAnimationTypeHint)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
        .onAppear {
            showRemainingMode = savedRemainingMode
            // 如果打开时已经在刷新，启动旋转动画
            if refreshState.isRefreshing {
                startRotationAnimation()
            }
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
        .onChange(of: refreshState.isRefreshing) { newValue in
            if newValue { startRotationAnimation() } else { stopRotationAnimation() }
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
            animationTypeHintDismissWorkItem?.cancel()
            animationTypeHintProvider = nil
        }
        #if DEBUG
        .background(
            UserSettings.shared.debugKeepDetailWindowOpen ? Color.white : Color.clear
        )
        #endif
    }

    private func showAnimationHint(_ animationTypeName: String, provider: ProviderType) {
        animationTypeHintDismissWorkItem?.cancel()
        animationTypeHintName = animationTypeName
        animationTypeHintProvider = provider

        withAnimation(.easeInOut(duration: 0.25)) {
            showAnimationTypeHint = true
        }

        let dismissWorkItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                showAnimationTypeHint = false
                animationTypeHintProvider = nil
            }
        }
        animationTypeHintDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: dismissWorkItem)
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
    @State static var codexData: CodexUsageData? = nil
    @StateObject static var refreshState = RefreshState()
    @State static var hasUpdate = false
    @State static var shouldShowBadge = false

    static var previews: some View {
        UsageDetailView(
            usageData: $sampleData,
            codexUsageData: $codexData,
            errorMessage: $errorMsg,
            refreshState: refreshState,
            hasAvailableUpdate: $hasUpdate,
            shouldShowUpdateBadge: $shouldShowBadge
        )
    }
}
