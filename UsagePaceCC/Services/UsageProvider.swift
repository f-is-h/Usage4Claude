//
//  UsageProvider.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-27.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

protocol UsageProvider: AnyObject {
    var providerType: ProviderType { get }
    func cancelAllRequests()
}
