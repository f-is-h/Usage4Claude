//
//  UsageDetailView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// Displays current provider usage, including progress, countdowns, and reset times.
struct UsageDetailView: View {
    @Binding var usageData: UsageData?
    @Binding var codexUsageData: CodexUsageData?
    @Binding var accountUsageSnapshots: [AccountUsageSnapshot]
    @Binding var errorMessage: String?
    @Binding var codexErrorMessage: String?
    /// All Codex refresh layers failed and the user must sign in again.
    @Binding var codexNeedsRelogin: Bool
    @ObservedObject var refreshState: RefreshState
    /// Callback for menu actions.
    var onMenuAction: ((MenuAction) -> Void)? = nil
    @StateObject private var localization = LocalizationManager.shared
    /// Whether an update is available for the text and badge.
    @Binding var hasAvailableUpdate: Bool
    /// Whether to show the update badge until the user acknowledges it.
    @Binding var shouldShowUpdateBadge: Bool

    /// Loading animation style.
    enum LoadingAnimationType: Int, CaseIterable {
        case rainbow = 0   // Rotating rainbow gradient.
        case dashed = 1    // Rotating dashed ring.
        case pulse = 2     // Pulsing ring.

        var name: String {
            switch self {
            case .rainbow: return L.LoadingAnimation.rainbow
            case .dashed: return L.LoadingAnimation.dashed
            case .pulse: return L.LoadingAnimation.pulse
            }
        }
    }

    // Claude column loading animation style, changed by long-pressing the ring.
    @State var claudeAnimationType: LoadingAnimationType = .rainbow
    // Independent Codex column loading animation style.
    @State var codexAnimationType: LoadingAnimationType = .rainbow

    /// Menu actions.
    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        case about
        case claudeStatus
        case codexStatus
        case coffee
        case githubSponsor
        case quit
        case refresh
        case refreshClaude
        case refreshCodex
        case codexRelogin
    }
    
    // Animation state is kept outside the view body so rebuilding does not reset it.
    @State var rotationAngle: Double = 0
    @State var animationTimer: Timer?
    // Animation style change hint.
    @State private var showAnimationTypeHint = false
    @State private var animationTypeHintName = ""
    @State private var animationTypeHintProvider: ProviderType?
    @State private var animationTypeHintDismissWorkItem: DispatchWorkItem?
    // Update notification.
    @State private var showUpdateNotification = false
    // Display mode toggle (false: reset time, true: remaining time).
    @AppStorage("showRemainingMode") private var savedRemainingMode = false
    @State private var showRemainingMode = UserDefaults.standard.bool(forKey: "showRemainingMode")
    @State private var remainingModeAnimationTrigger = 0
    
    // MARK: - Body

    private var isMultiProviderActive: Bool {
        UserSettings.shared.isMultiProviderActive
            && (codexUsageData != nil || codexErrorMessage != nil || UserSettings.shared.hasValidCodexCredentials)
    }

    private var orderedAccountUsageSnapshots: [AccountUsageSnapshot] {
        accountUsageSnapshots.filter { $0.provider == .claude }
            + accountUsageSnapshots.filter { $0.provider == .codex }
    }

    private var showsAllAccounts: Bool {
        let claudeCount = orderedAccountUsageSnapshots.filter { $0.provider == .claude }.count
        let codexCount = orderedAccountUsageSnapshots.filter { $0.provider == .codex }.count
        // Keep the original compact/split-provider presentation for one account
        // per provider. Use the account grid only when it is needed to compare
        // multiple accounts of the same provider.
        return claudeCount > 1 || codexCount > 1
    }

    private var isCodexOnlyActive: Bool {
        !isMultiProviderActive
            && ((!UserSettings.shared.hasValidCredentials && UserSettings.shared.hasValidCodexCredentials)
                || (usageData == nil && (codexUsageData != nil || codexErrorMessage != nil)))
    }

    private var isClaudeRefreshing: Bool {
        refreshState.isRefreshingProvider(.claude)
    }

    /// Returns the active Claude display types.
    private var activeDisplayTypes: [LimitType] {
        guard let data = usageData else { return [] }
        return UserSettings.shared.getActiveDisplayTypes(usageData: data)
            .filter { $0.provider == .claude }
    }

    /// Returns the active Codex display types.
    private var activeCodexDisplayTypes: [LimitType] {
        guard let codex = codexUsageData else { return [] }
        return UserSettings.shared.getActiveDisplayTypes(usageData: nil, codexUsageData: codex)
            .filter { $0.provider == .codex }
    }

    /// Calculates the dynamic height for a single-provider layout.
    private var dynamicHeight: CGFloat {
        let activeCount = activeDisplayTypes.count

        // Use one calculation so the bottom margin stays consistent.
        // Base height includes the ring, header, and fixed vertical spacing.
        // Each row is approximately 26pt including text, padding, and background.
        // Rows are separated by 5pt.
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5

        // A single limit reserves two rows; otherwise use the active count.
        let rowCount = activeCount == 1 ? 2 : activeCount
        let textHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing

        return baseHeight + textHeight
    }

    /// Dynamic height for the Codex-only layout.
    private var codexOnlyHeight: CGFloat {
        let activeCount = activeCodexDisplayTypes.count
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5
        let rowCount = activeCount == 1 ? 2 : max(activeCount, codexUsageData == nil ? 0 : 1)
        let textHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing

        return baseHeight + textHeight
    }

    /// Dynamic height for the dual-provider layout, based on the taller column.
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
            codexRowCount = 2
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
        if showsAllAccounts {
            return 620
        }
        return isMultiProviderActive ? 580 : 290
    }

    private var contentHeight: CGFloat {
        if showsAllAccounts {
            let rowCount = CGFloat((orderedAccountUsageSnapshots.count + 1) / 2)
            return min(560, max(380, 115 + rowCount * 250))
        }
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
            // Error message.
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // Action buttons.
                HStack(spacing: 12) {
                    // Authentication errors include a shortcut to settings.
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

                    // Show the diagnostic shortcut for every error.
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
            // Usage data.
            VStack(spacing: 15) {
                // Circular progress ring.
                ZStack {
                    let primaryLimitData = getPrimaryLimitData(data: data, activeTypes: activeDisplayTypes)

                    if let primary = primaryLimitData {
                        let primaryRingColor = colorForPrimaryByActiveTypes(data: data, activeTypes: activeDisplayTypes)
                        let primaryRingRange = UsageRingDisplay.displayedTrimRange(
                            usedPercentage: primary.percentage,
                            showRemainingMode: showRemainingMode
                        )

                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 100, height: 100)

                        if isClaudeRefreshing {
                            loadingAnimation()
                        } else {
                            Circle()
                                .trim(from: primaryRingRange.from, to: primaryRingRange.to)
                                .stroke(
                                    primaryRingColor,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(
                                    .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05),
                                    value: primaryRingRange
                                )
                        }

                        if activeDisplayTypes.contains(.fiveHour) &&
                           activeDisplayTypes.contains(.sevenDay) {
                            let sevenDayPercentage = data.sevenDay?.percentage ?? (UserSettings.shared.shouldShowCustomPlaceholderInPopover ? 0 : nil)

                            if let percentage = sevenDayPercentage {
                                let outerRingRange = UsageRingDisplay.displayedTrimRange(
                                    usedPercentage: percentage,
                                    showRemainingMode: showRemainingMode
                                )

                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                    .frame(width: 114, height: 114)

                                if isClaudeRefreshing {
                                    outerLoadingAnimation()
                                } else {
                                    Circle()
                                        .trim(from: outerRingRange.from, to: outerRingRange.to)
                                        .stroke(
                                            colorForSevenDay(percentage),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 114, height: 114)
                                        .rotationEffect(.degrees(-90))
                                        .animation(
                                            .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05),
                                            value: outerRingRange
                                        )
                                }
                            }
                        }

                        if !isClaudeRefreshing {
                            DetailUsageRingSweep(
                                trigger: remainingModeAnimationTrigger,
                                diameter: 122,
                                lineWidth: 3,
                                color: primaryRingColor
                            )
                        }

                        DetailUsageRingCenterText(
                            usedPercentage: primary.percentage,
                            showRemainingMode: showRemainingMode
                        )
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
                            // The first two models use the Opus/Sonnet slots above. Additional
                            // models are appended in Claude API order, alternating icon shapes
                            // and using the model names returned by the API. Smart mode shows
                            // every model; custom mode keeps the user's selected fixed slots.
                            if UserSettings.shared.displayMode == .smart {
                                let overflow = Array(data.weeklyModels.enumerated()).dropFirst(2)
                                ForEach(overflow, id: \.offset) { entry in
                                    UnifiedLimitRow(
                                        type: entry.offset % 2 == 0 ? .opusWeekly : .sonnetWeekly,
                                        data: data,
                                        showRemainingMode: showRemainingMode,
                                        weeklyModelOverride: entry.element
                                    )
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleRemainingMode()
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
            // Loading state.
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

    /// Refresh and overflow buttons shared by single- and dual-column headers.
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
                if !UserSettings.shared.accounts.isEmpty {
                    Button(action: { onMenuAction?(.claudeStatus) }) {
                        Label(L.Menu.claudeStatus, systemImage: "safari")
                    }
                }
                if !UserSettings.shared.codexAccounts.isEmpty {
                    Button(action: { onMenuAction?(.codexStatus) }) {
                        Label(L.Menu.codexStatus, systemImage: "safari.fill")
                    }
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
                remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                onRefresh: { onMenuAction?(.refreshCodex) },
                onAnimationHint: { showAnimationHint($0, provider: .codex) },
                onToggleRemainingMode: toggleRemainingMode
            )
        } else if let error = codexErrorMessage {
            VStack(spacing: 12) {
                Image(systemName: codexNeedsRelogin ? "lock.open.trianglebadge.exclamationmark.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                if codexNeedsRelogin {
            // All three refresh layers failed; provide a one-click sign-in action.
                    Button(action: {
                        onMenuAction?(.codexRelogin)
                    }) {
                        Label(L.Usage.codexRelogin, systemImage: "arrow.counterclockwise.circle.fill")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
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

    private var allAccountsBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                Text(L.Menu.account)
                    .font(.headline)
                Spacer()
                refreshAndMenuButtons
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 270, maximum: 320), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(orderedAccountUsageSnapshots) { snapshot in
                        AccountUsageSnapshotCard(
                            snapshot: snapshot,
                            showRemainingMode: $showRemainingMode,
                            refreshState: refreshState,
                            rotationAngle: $rotationAngle,
                            remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                            onRefresh: {
                                onMenuAction?(snapshot.provider == .codex ? .refreshCodex : .refreshClaude)
                            },
                            onToggleRemainingMode: toggleRemainingMode
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            updateNotificationView
        }
    }

    private func multiProviderBody(codex: CodexUsageData?) -> some View {
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
                            codexOnlyMainContent(codex: codex)
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
            if showsAllAccounts {
                allAccountsBody
            } else if isMultiProviderActive {
                multiProviderBody(codex: codexUsageData)
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
        .id(localization.updateTrigger)  // Recreate the view when the language changes.
        .onAppear {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showRemainingMode = savedRemainingMode
            }
            // Start the rotation animation if the popover opened during a refresh.
            if refreshState.isRefreshing {
                startRotationAnimation()
            }
            // Show an update notification when one is available.
            if refreshState.notificationMessage != nil {
                withAnimation {
                    showUpdateNotification = true
                }
                // Hide the notification after three seconds.
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
            // Observe notification message changes.
            if message != nil {
                withAnimation {
                    showUpdateNotification = true
                }
                // Hide the notification after three seconds.
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
            // Clean up timers and reset state when the view disappears.
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

    private func toggleRemainingMode() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05)) {
            showRemainingMode.toggle()
            remainingModeAnimationTrigger += 1
        }
        savedRemainingMode = showRemainingMode
    }
}

// Preview.
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
    @State static var codexErrorMsg: String? = nil
    @State static var codexData: CodexUsageData? = nil
    @State static var codexNeedsRelogin = false
    @StateObject static var refreshState = RefreshState()
    @State static var hasUpdate = false
    @State static var shouldShowBadge = false

    static var previews: some View {
        UsageDetailView(
            usageData: $sampleData,
            codexUsageData: $codexData,
            accountUsageSnapshots: .constant([]),
            errorMessage: $errorMsg,
            codexErrorMessage: $codexErrorMsg,
            codexNeedsRelogin: $codexNeedsRelogin,
            refreshState: refreshState,
            hasAvailableUpdate: $hasUpdate,
            shouldShowUpdateBadge: $shouldShowBadge
        )
    }
}

private struct AccountUsageSnapshotCard: View {
    let snapshot: AccountUsageSnapshot
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountHeader

            if let errorDescription = snapshot.errorDescription {
                Label(errorDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            switch snapshot.payload {
            case .codex, .claude:
                AccountUsageWidgetView(
                    snapshot: snapshot,
                    showRemainingMode: $showRemainingMode,
                    refreshState: refreshState,
                    rotationAngle: $rotationAngle,
                    remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                    onRefresh: onRefresh,
                    onToggleRemainingMode: onToggleRemainingMode
                )
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(providerAccent.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }

    private var accountHeader: some View {
        HStack(spacing: 8) {
            if snapshot.provider == .codex,
               let icon = ImageHelper.createCodexIcon(size: 20) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else if let icon = ImageHelper.createAppIcon(size: 20) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if snapshot.accountIdentity != snapshot.displayName {
                    Text(snapshot.accountIdentity)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(snapshot.provider.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(providerAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(providerAccent.opacity(0.12), in: Capsule())
        }
    }

    private var providerAccent: Color {
        snapshot.provider == .codex
            ? Color(red: 45 / 255, green: 212 / 255, blue: 191 / 255)
            : Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
    }
}

private struct AccountUsageWidgetWindow: Identifiable {
    let id: String
    let title: String
    let limit: UsageData.LimitData
    let color: Color
    let resetText: String
    let remainingText: String
}

private struct AccountUsageWidgetView: View {
    let snapshot: AccountUsageSnapshot
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private var windows: [AccountUsageWidgetWindow] {
        switch snapshot.payload {
        case .claude(let usage):
            var result: [AccountUsageWidgetWindow] = []
            if let fiveHour = usage.fiveHour {
                result.append(
                    AccountUsageWidgetWindow(
                        id: "five-hour",
                        title: "5h",
                        limit: fiveHour,
                        color: UsageColorScheme.fiveHourColorSwiftUI(fiveHour.percentage),
                        resetText: fiveHour.formattedCompactResetTime,
                        remainingText: fiveHour.formattedCompactRemaining
                    )
                )
            }
            if let sevenDay = usage.sevenDay {
                result.append(
                    AccountUsageWidgetWindow(
                        id: "seven-day",
                        title: "1w",
                        limit: sevenDay,
                        color: UsageColorScheme.sevenDayColorSwiftUI(sevenDay.percentage),
                        resetText: sevenDay.formattedCompactResetDate,
                        remainingText: sevenDay.formattedCompactRemaining
                    )
                )
            }
            return result
        case .codex(let usage):
            var result: [AccountUsageWidgetWindow] = []
            if let primary = usage.primary {
                let limit = primary.asUsageLimitData()
                result.append(
                    AccountUsageWidgetWindow(
                        id: "primary",
                        title: "5h",
                        limit: limit,
                        color: UsageColorScheme.codexPrimaryColorSwiftUI(primary.percentage),
                        resetText: limit.formattedCompactResetTime,
                        remainingText: limit.formattedCompactRemaining
                    )
                )
            }
            if let secondary = usage.secondary {
                let limit = secondary.asUsageLimitData()
                result.append(
                    AccountUsageWidgetWindow(
                        id: "secondary",
                        title: "1w",
                        limit: limit,
                        color: UsageColorScheme.codexSecondaryColorSwiftUI(secondary.percentage),
                        resetText: limit.formattedCompactResetDateWithMinutes,
                        remainingText: limit.formattedCompactRemainingWithMinutes
                    )
                )
            }
            return result
        case nil:
            return []
        }
    }

    private var supplementalRows: [(String, String, Color)] {
        switch snapshot.payload {
        case .claude(let usage):
            var rows = usage.weeklyModels.enumerated().map { index, model in
                let fallback = index == 0 ? L.DetailRow.opusWeekly : L.DetailRow.sonnetWeekly
                let name = model.modelName ?? fallback
                let value = showRemainingMode
                    ? model.limit.formattedCompactRemaining
                    : model.limit.formattedCompactResetDate
                let color: Color = index.isMultiple(of: 2) ? .orange : .blue
                return (name, value, color)
            }
            if let extra = usage.extraUsage {
                rows.append((L.DetailRow.extraUsage, showRemainingMode ? extra.formattedRemainingAmount : extra.formattedCompactAmount, .pink))
            }
            return rows
        case .codex(let usage):
            guard let extra = usage.extraUsage, extra.enabled else { return [] }
            return [(L.DetailRow.extraUsage, showRemainingMode ? extra.formattedDetailRemainingAmount : extra.formattedDetailCompactAmount, .orange)]
        case nil:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if windows.isEmpty {
                Text(L.Error.noData)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 145)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(windows) { window in
                        AccountUsageDonutView(
                            window: window,
                            showRemainingMode: showRemainingMode,
                            isRefreshing: refreshState.isRefreshingProvider(snapshot.provider),
                            rotationAngle: rotationAngle,
                            remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                            canRefresh: refreshState.canRefresh && !refreshState.isRefreshing,
                            onRefresh: onRefresh,
                            onToggleRemainingMode: onToggleRemainingMode
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)

                if !supplementalRows.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(Array(supplementalRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(row.2)
                                    .frame(width: 6, height: 6)
                                Text(row.0)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(row.1)
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleRemainingMode?()
                    }
                }
            }
        }
    }
}

private struct AccountUsageDonutView: View {
    let window: AccountUsageWidgetWindow
    let showRemainingMode: Bool
    let isRefreshing: Bool
    let rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    let canRefresh: Bool
    var onRefresh: (() -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private let diameter: CGFloat = 76
    private let lineWidth: CGFloat = 8

    private var displayedPercentage: Double {
        UsageRingDisplay.displayedPercentage(
            usedPercentage: window.limit.percentage,
            showRemainingMode: showRemainingMode
        )
    }

    private var trimRange: UsageRingTrimRange {
        UsageRingDisplay.displayedTrimRange(
            usedPercentage: window.limit.percentage,
            showRemainingMode: showRemainingMode
        )
    }

    private var detailText: String {
        showRemainingMode ? window.remainingText : window.resetText
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)

                if isRefreshing {
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [window.color.opacity(0.18), window.color, .white.opacity(0.85), window.color.opacity(0.18)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(rotationAngle))
                } else {
                    Circle()
                        .trim(from: trimRange.from, to: trimRange.to)
                        .stroke(window.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: trimRange)

                    DetailUsageRingSweep(
                        trigger: remainingModeAnimationTrigger,
                        diameter: diameter + 6,
                        lineWidth: 2,
                        color: window.color
                    )
                }

                Text(window.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .onTapGesture {
                if canRefresh {
                    onRefresh?()
                }
            }

            VStack(spacing: 1) {
                Text("\(Int(displayedPercentage.rounded()))%")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(window.color)

                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleRemainingMode?()
            }
        }
    }

}
