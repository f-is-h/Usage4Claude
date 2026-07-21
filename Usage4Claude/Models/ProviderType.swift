//
//  ProviderType.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-27.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

enum ProviderType: String, Codable, CaseIterable, Hashable {
    case claude
    case codex
    case grok

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .grok: return "Grok"
        }
    }
}
