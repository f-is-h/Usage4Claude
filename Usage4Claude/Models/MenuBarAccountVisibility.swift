//
//  MenuBarAccountVisibility.swift
//  Usage4Claude
//

import Foundation

/// Value type backing the per-account menu bar visibility preference.
///
/// The persisted representation contains hidden accounts rather than visible
/// accounts, so accounts added after the preference was saved remain visible.
struct MenuBarAccountVisibility {
    private(set) var hiddenAccountIds: Set<UUID>

    init(persistedAccountIdStrings: [String]?) {
        hiddenAccountIds = Set((persistedAccountIdStrings ?? []).compactMap(UUID.init(uuidString:)))
    }

    func isVisible(accountId: UUID) -> Bool {
        !hiddenAccountIds.contains(accountId)
    }

    mutating func setVisibility(accountId: UUID, isVisible: Bool) {
        if isVisible {
            hiddenAccountIds.remove(accountId)
        } else {
            hiddenAccountIds.insert(accountId)
        }
    }

    mutating func removeAccount(_ accountId: UUID) {
        hiddenAccountIds.remove(accountId)
    }

    var persistedAccountIdStrings: [String] {
        hiddenAccountIds.map(\.uuidString).sorted()
    }
}
