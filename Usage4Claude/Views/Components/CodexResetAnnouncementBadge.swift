//
//  CodexResetAnnouncementBadge.swift
//  Usage4Claude
//
//  Corner-badge pill anchored to the Codex ring's own top-right corner
//  (positioned by the caller via .overlay(alignment: .topTrailing)), only
//  while a real official reset announcement (Beta, from codex-reset.com) is
//  pending. Absent 95%+ of the time by design — see CodexResetAnnouncement.swift
//  for why this intentionally does not show a probability number. Countdown/label
//  detail lives entirely in the popover opened by clicking the badge; there's no
//  room to show it persistently at this size.
//

import SwiftUI

struct CodexResetAnnouncementBadge: View {
    let announcement: CodexResetAnnouncement

    /// Codex 松石绿，与 CodexColumnView 的加载动画色一致（#2DD4BF）。
    /// 直接量而非 UsageColorScheme.codexPrimaryColorSwiftUI(percentage:)——
    /// 那个函数按用量百分比三段变色，语义不适用于这里（这不是一个用量值）。
    private let accentColor = Color(red: 45 / 255.0, green: 212 / 255.0, blue: 191 / 255.0)

    /// 参照的预测网站首页——弹出说明末行的链接指向这里，而不是某一条个人 X 帖子
    private static let referenceSiteURL = URL(string: "https://codex-reset.com/")!

    /// 点击角标弹出说明
    @State private var showsDetail = false

    /// 说明里的预告原文可能较长，比标题旁小叹号的说明放宽一些再换行
    private static let detailMaxWidth: CGFloat = 320

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // 跨过过期点后自然消失，不依赖下一次抓取周期
            if announcement.isActive(at: context.date) {
                content
            }
        }
        // 与标题旁小叹号一致：点击弹出系统 popover。此前用 tooltip（.help），
        // 实测它在主弹窗里不出现，倒计时等说明实际上看不到
        .onTapGesture { showsDetail.toggle() }
        .popover(isPresented: $showsDetail, arrowEdge: .bottom) {
            detail
        }
        .onChange(of: showsDetail) { isShowing in
            // 说明小弹窗收起：交给 MenuBarUI 判断是否点在了主界面之外
            if !isShowing {
                NotificationCenter.default.post(name: .detailPopoverDismissed, object: nil)
            }
        }
        // 主界面关闭时一并复位，否则下次打开主界面会自动再弹出来
        .onDisappear { showsDetail = false }
    }

    /// 喇叭图标 + "重置预告"。刻意不加实心胶囊背景和描边——那是 macOS 里按钮的视觉语言，
    /// 会让人误以为点一下就能手动触发重置。这里只是一条信息标记。
    ///
    /// 放在 Codex 标题行里，与标题、刷新/菜单按钮共用约 258pt 宽度，因此各语言文案都尽量短。
    /// 图标用喇叭而非循环箭头：标题行右侧就是刷新按钮，循环箭头与它几乎一样。
    /// 始终带文字——只剩图标时用户不点开就不知道它是什么。标题行最挤的情况
    /// （同时显示数据过期小叹号，日文 / 法文）文字允许缩小至 80% 而不是截断成省略号。
    /// Beta 信息由设置页标题、弹出说明末行和 README 承载，不占标题行宽度。
    private var content: some View {
        HStack(spacing: 3) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(L.CodexAnnouncement.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(accentColor)
    }

    /// 弹出说明。按「结论 → 依据 → 出处」三段排版：
    /// 第一行说时间（用户最关心），第二行预告原文引述，第三行数据来源兼网站链接。
    /// 倒计时随 TimelineView 每分钟更新，弹出期间也不会停在打开那一刻
    private var detail: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let timing = timingLine(at: context.date)
            let footer = L.CodexAnnouncement.tooltipFooter
            VStack(alignment: .leading, spacing: 4) {
                Text(timing)
                if let quote {
                    Text(quote)
                        .foregroundColor(.secondary)
                }
                // 末行是数据来源（Beta · 数据来源：codex-reset.com），整行做成链接
                Button(footer) {
                    showsDetail = false
                    NSWorkspace.shared.open(Self.referenceSiteURL)
                }
                .buttonStyle(.link)
                .multilineTextAlignment(.leading)
            }
            .font(.system(size: DetailPopoverText.fontSize))
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: DetailPopoverText.width(
                    fitting: [timing, quote, footer].compactMap { $0 },
                    maxWidth: Self.detailMaxWidth
                ),
                alignment: .leading
            )
            .padding(12)
        }
    }

    /// 预告原文引述。窗口 label 与摘要常常高度重复，只取更完整的摘要；摘要为空时才退回 label
    private var quote: String? {
        let text = announcement.summary.isEmpty ? (announcement.window?.label ?? "") : announcement.summary
        return text.isEmpty ? nil : "\u{201C}\(text)\u{201D}"
    }

    /// 四种情况对用户的意义不同：
    /// - 没给时间（站点 83% 档）：只能说已官宣，不编造倒计时
    /// - 已过声明时间、站点未确认：重置晚到很常见，不显示归零的倒计时
    /// - `.deadline`（"within an hour" 型）表示不会晚于该时刻，措辞用「最迟」
    /// - `.center` / `.range` 是估计值，措辞用「预计」
    private func timingLine(at now: Date) -> String {
        guard let window = announcement.window else {
            return L.CodexAnnouncement.tooltipNoTime
        }
        if announcement.isOverdue(at: now) {
            return L.CodexAnnouncement.tooltipOverdue
        }

        let duration = countdownDuration(to: window.target)
        switch window.kind {
        case .deadline:
            return L.CodexAnnouncement.tooltipCountdownDeadline(duration)
        case .center, .range:
            return L.CodexAnnouncement.tooltipCountdown(duration)
        }
    }

    /// 复用 UsageData.LimitData 已有的极简时长格式化。注意它的输出自带
    /// 「还剩 / left / 残り」等语义，所以上面的模板必须是「标签：时长」形式，
    /// 不能写成「预计 %@ 后重置」——那样会拼出「预计 还剩 2小时 后重置」的病句。
    private func countdownDuration(to target: Date) -> String {
        UsageData.LimitData(percentage: 0, resetsAt: target).formattedCompactRemaining
    }
}
