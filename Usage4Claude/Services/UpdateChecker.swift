//
//  UpdateChecker.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import AppKit

/// 应用更新检查器
/// 负责检查 GitHub Release 上的新版本并提示用户更新
/// 支持自动检查和手动检查两种模式
class UpdateChecker {
    // MARK: - Properties
    
    /// GitHub 仓库所有者
    private let repoOwner = "f-is-h"
    /// GitHub 仓库名称
    private let repoName = "Usage4Claude"
    
    /// 当前应用版本号
    /// - Returns: 从 Bundle 中读取的版本号，默认为 "1.0.0"
    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    // MARK: - Data Models
    
    /// GitHub Release 数据模型
    /// 对应 GitHub API 返回的 Release JSON 结构
    struct GitHubRelease: Codable {
        /// 版本标签（如 "v1.0.0"）
        let tagName: String
        /// Release 名称
        let name: String
        /// Release 说明内容
        let body: String?
        /// Release 页面 URL
        let htmlUrl: String
        /// Release 附件列表
        let assets: [Asset]
        
        /// Release 附件（如 DMG 文件）
        struct Asset: Codable {
            /// 附件文件名
            let name: String
            /// 下载 URL
            let browserDownloadUrl: String
            
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlUrl = "html_url"
            case assets
        }
    }
    
    // MARK: - Public Methods
    
    /// 🆕 后台静默检查更新（无UI提示）
    /// - Parameter completion: 完成回调，返回是否有更新和最新版本号
    func checkForUpdatesInBackground(completion: @escaping (Bool, String?) -> Void) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Usage4Claude/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false, nil)
                return
            }
            
            DispatchQueue.main.async {
                if error != nil {
                    completion(false, nil)
                    return
                }
                
                guard let data = data else {
                    completion(false, nil)
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let latestVersion = self.parseVersion(from: release.tagName)
                    let currentVersion = self.parseVersion(from: self.currentVersion)
                    
                    let hasUpdate = self.isNewerVersion(latest: latestVersion, current: currentVersion)
                    completion(hasUpdate, hasUpdate ? latestVersion : nil)
                } catch {
                    completion(false, nil)
                }
            }
        }
        
        task.resume()
    }
    
    /// 检查应用更新
    /// - Parameter manually: 是否为手动检查。手动检查会显示所有结果（包括无更新和错误），自动检查只在有更新时提示
    func checkForUpdates(manually: Bool = false) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            if manually {
                showError(message: L.Update.Error.invalidUrl)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Usage4Claude/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if error != nil {
                    if manually {
                        // 只显示自定义错误消息，不显示系统错误描述
                        self.showError(message: L.Update.Error.network)
                    }
                    return
                }
                
                guard let data = data else {
                    if manually {
                        self.showError(message: L.Update.Error.noData)
                    }
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let latestVersion = self.parseVersion(from: release.tagName)
                    let currentVersion = self.parseVersion(from: self.currentVersion)
                    
                    if self.isNewerVersion(latest: latestVersion, current: currentVersion) {
                        self.showUpdateAlert(release: release)
                    } else {
                        if manually {
                            self.showNoUpdateAvailable()
                        }
                    }
                } catch {
                    if manually {
                        // 只显示自定义错误消息，不显示系统错误描述
                        self.showError(message: L.Update.Error.parseFailed)
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Private Methods
    
    /// 解析版本号字符串
    /// - Parameter string: 原始版本号字符串（可能包含 "v" 前缀）
    /// - Returns: 纯数字版本号（如 "1.0.0"）
    private func parseVersion(from string: String) -> String {
        return string.lowercased().replacingOccurrences(of: "v", with: "")
    }
    
    /// 比较版本号大小（语义化版本）
    /// - Parameters:
    ///   - latest: 最新版本号
    ///   - current: 当前版本号
    /// - Returns: 如果 latest 比 current 新则返回 true
    /// - Note: 使用语义化版本比较规则（主版本.次版本.修订号）
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        // 确保至少有3个版本号组件
        let latestPadded = (latestComponents + [0, 0, 0]).prefix(3)
        let currentPadded = (currentComponents + [0, 0, 0]).prefix(3)
        
        for (l, c) in zip(latestPadded, currentPadded) {
            if l > c {
                return true
            } else if l < c {
                return false
            }
        }
        
        return false
    }
    
    /// 显示更新提示对话框
    /// - Parameter release: GitHub Release 数据
    private func showUpdateAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = L.Update.newVersionTitle
        
        let latestVersion = parseVersion(from: release.tagName)
        var infoText = "\(L.Update.latestVersion): \(latestVersion)\n\(L.Update.currentVersion): \(currentVersion)\n\n"
        
        if let body = release.body, !body.isEmpty {
            infoText += formatReleaseNotes(body)
        } else {
            infoText += L.Update.viewReleasePage
        }
        
        alert.informativeText = infoText
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.Update.downloadButton)
        alert.addButton(withTitle: L.Update.remindLaterButton)
        alert.addButton(withTitle: L.Update.viewDetailsButton)
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // 下载更新 - 打开DMG下载链接
            if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                if let url = URL(string: dmgAsset.browserDownloadUrl) {
                    NSWorkspace.shared.open(url)
                }
            } else {
                // 如果没有DMG，打开Release页面
                if let url = URL(string: release.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            
        case .alertThirdButtonReturn:
            // 查看详情 - 打开Release页面
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
            
        default:
            // 稍后提醒 - 什么都不做
            break
        }
    }
    
    /// 显示已是最新版本的提示对话框
    private func showNoUpdateAvailable() {
        let alert = NSAlert()
        alert.messageText = L.Update.upToDateTitle
        alert.informativeText = L.Update.upToDateMessage(currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.Update.okButton)
        alert.runModal()
    }
    
    /// 显示错误提示对话框
    /// - Parameter message: 错误消息内容
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = L.Update.checkFailedTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.Update.confirmButton)
        alert.runModal()
    }
    
    /// 格式化 Release Notes 文本
    /// - Parameter notes: 原始 Release Notes
    /// - Returns: 格式化后的文本，超过长度限制会截断
    /// - Note: 最大长度 300 字符
    private func formatReleaseNotes(_ notes: String) -> String {
        let maxLength = 300
        if notes.count > maxLength {
            let index = notes.index(notes.startIndex, offsetBy: maxLength)
            return String(notes[..<index]) + "...\n\n" + L.Update.viewDetailsHint
        }
        return notes
    }
}
