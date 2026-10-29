//
//  UserSettings+Antigravity.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//
//  放在扩展里而不是 UserSettings 的存储属性中，是为了少改上游文件。
//  扩展不能有存储属性，因此直接读写 UserDefaults，并手动发出变更通知。
//

import Foundation
import Combine

extension UserSettings {

    private static let antigravityCustomTypesInitializedKey = "antigravityCustomDisplayTypesInitialized"
    var antigravityAccounts: [AntigravityAccount] { AntigravityAccountStore.shared.accounts }
    var currentAntigravityAccount: AntigravityAccount? { AntigravityAccountStore.shared.current }
    var antigravityEnabled: Bool { !antigravityAccounts.isEmpty }
    var isAntigravityActive: Bool {
        guard let account = currentAntigravityAccount else { return false }
        return !account.isLocal || AntigravityAPIService.locateCLI() != nil
    }

    /// Antigravity 当前应显示的限制类型
    /// - Note: 规则与 `getActiveDisplayTypes` 一致：智能模式显示有数据的窗口，
    ///   自定义模式按用户勾选显示（无数据时以 0% 占位）
    func antigravityDisplayTypes(data: AntigravityUsageData?, forMenuBar: Bool = false) -> [LimitType] {
        let useSmart = displayMode == .smart || (customDisplayMenuBarOnly && !forMenuBar)
        if useSmart {
            return data?.availableLimitTypes ?? []
        }
        return AntigravityUsageData.limitTypes.filter { customDisplayTypes.contains($0) }
    }

    /// 首次拿到 Antigravity 数据时，若处于自定义模式且没有勾选任何 Antigravity 类型，
    /// 默认勾选两个每周窗口，避免启用后菜单栏什么都不显示。只执行一次，之后尊重用户的选择
    func ensureDefaultAntigravityDisplayTypesForCustomMode() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.antigravityCustomTypesInitializedKey) else { return }
        // 智能模式下不消耗这次机会：用户之后切到自定义模式时仍需补上默认勾选
        guard displayMode == .custom else { return }
        defaults.set(true, forKey: Self.antigravityCustomTypesInitializedKey)
        guard customDisplayTypes.isDisjoint(with: AntigravityUsageData.limitTypes) else { return }
        customDisplayTypes.formUnion([.antigravityGeminiWeekly, .antigravityThirdPartyWeekly])
    }
}
