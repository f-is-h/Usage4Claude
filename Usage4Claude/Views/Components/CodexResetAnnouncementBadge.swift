//
//  CodexResetAnnouncementBadge.swift
//  Usage4Claude
//
//  Corner-badge pill anchored to the Codex ring's own top-right corner
//  (positioned by the caller via .overlay(alignment: .topTrailing)), only
//  while a real official reset announcement (Beta, from codex-reset.com) is
//  pending. Absent 95%+ of the time by design — see project plan doc for why
//  this intentionally does not show a probability number. Countdown/label
//  detail lives entirely in the hover tooltip; there's no room to show it
//  persistently at this size.
//

import SwiftUI

struct CodexResetAnnouncementBadge: View {
    let announcement: CodexResetAnnouncement

    /// Codex 松石绿，与 CodexColumnView 的加载动画色一致（#2DD4BF）。
    /// 直接量而非 UsageColorScheme.codexPrimaryColorSwiftUI(percentage:)——
    /// 那个函数按用量百分比三段变色，语义不适用于这里（这不是一个用量值）。
    private let accentColor = Color(red: 45 / 255.0, green: 212 / 255.0, blue: 191 / 255.0)

    /// 参照的预测网站首页——点击徽章导航到这里，而不是某一条个人 X 帖子
    private static let referenceSiteURL = URL(string: "https://codex-reset.com/")!

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // 跨过窗口结束点后自然消失，不依赖下一次抓取周期
            if announcement.isActive(at: context.date) {
                content
            }
        }
        .help(tooltip)
        .onTapGesture {
            NSWorkspace.shared.open(Self.referenceSiteURL)
        }
    }

    /// 图标 + "重置预告"。刻意不加实心胶囊背景和描边——那是 macOS 里按钮的视觉语言，
    /// 会让人误以为点一下就能手动触发重置。这里只是一条信息标记。
    ///
    /// 也刻意不在这里放 Beta 标签：角标可用宽度只有约 84pt，而 Beta 标签要占 24pt，
    /// 英文文案（"Reset expected" 约 67pt）加上它必然溢出、压到圆环上，且每新增一种
    /// 语言都要重新验证宽度。Beta 信息改由设置页标题、tooltip 末行和 README 承载。
    private var content: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 8, weight: .semibold))
            Text(L.CodexAnnouncement.title)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(accentColor)
    }

    /// 系统 tooltip 内容。按「结论 → 依据 → 出处」三段排版：
    /// 第一行倒计时（用户最关心），第二行预告原文引述，第三行数据来源。
    /// label 与 summary 常常高度重复（label 往往是 summary 的摘要），只取更完整的一条，
    /// 避免出现两行说同一件事。
    private var tooltip: String {
        var lines = [countdownLine]

        let quote = announcement.summary.isEmpty ? announcement.label : announcement.summary
        if !quote.isEmpty {
            lines.append("\u{201C}\(quote)\u{201D}")
        }

        lines.append(L.CodexAnnouncement.tooltipFooter)
        return lines.joined(separator: "\n")
    }

    /// 区分预告窗口的性质——这个差别对用户有实际意义：
    /// `.deadline`（"within an hour" 型）表示不会晚于该时刻，确定性更高；
    /// `.center`（"around 2 PM" 型）和 `.range`（只给了窗口）则是估计值。
    private var countdownLine: String {
        switch announcement.kind {
        case .deadline:
            return L.CodexAnnouncement.tooltipCountdownDeadline(countdownDuration)
        case .center, .range:
            return L.CodexAnnouncement.tooltipCountdown(countdownDuration)
        }
    }

    /// 复用 UsageData.LimitData 已有的极简时长格式化。注意它的输出自带
    /// 「还剩 / left / 残り」等语义，所以上面的模板必须是「标签：时长」形式，
    /// 不能写成「预计 %@ 后重置」——那样会拼出「预计 还剩 2小时 后重置」的病句。
    private var countdownDuration: String {
        UsageData.LimitData(percentage: 0, resetsAt: announcement.target).formattedCompactRemaining
    }
}
