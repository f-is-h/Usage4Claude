//
//  main.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-21.
//  Copyright © 2026 f-is-h. All rights reserved.
//
//  文档配图渲染器。由 scripts/render_docs_images.sh 编译运行，不进 app 目标。
//  必须叫 main.swift：Swift 只允许这个文件名放顶层代码。
//
//  实例化 app 里真实的 SwiftUI 视图，喂固定假数据，用 ImageRenderer 离屏出图，
//  替代截屏工具：不需要 app 跑起来、不发鼠标事件、不依赖辅助功能权限，
//  同一份源码出来的图永远一样。
//

import SwiftUI
import AppKit

// MARK: - 输出

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

/// 明暗由启动参数决定，不跟当前系统走。
///
/// `MenuBarIconRenderer` 在没有 `NSStatusBarButton` 时会退回读 `AppleInterfaceStyle`，
/// 而 `NSArgumentDomain` 优先级最高且不写盘，所以传 `-AppleInterfaceStyle Dark/Light`
/// 就能把明暗钉死，渲染结果不受这台机器当前设置影响
let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
let variant = isDark ? "dark" : "light"

/// 把视图渲染成 NSImage。
///
/// 并排合成图必须走这一步：SwiftUI 视图读的是 `UserSettings.shared`，而且是在渲染
/// 那一刻才求值的。两组用的设置不同（圆环 vs 线性），如果只是把两个视图拼进一个
/// 容器再统一渲染，后设的那套会同时作用到两组上——左边的圆环会变成线性
@MainActor
func renderImage<V: View>(_ view: V) -> NSImage? {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, isDark ? .dark : .light))
    renderer.scale = 2
    return renderer.nsImage
}

@MainActor
func write<V: View>(_ view: V, to name: String) {
    let path = outDir + "/" + name
    guard let image = renderImage(view),
          let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        print("  ✗ \(name)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("  ✓ \(name)  \(Int(image.size.width))×\(Int(image.size.height))pt")
}

// MARK: - 弹窗外壳

/// 圆角、阴影和顶部箭头都是 `NSPopover` 画的，不属于 SwiftUI 视图，离屏渲染时得自己补。
/// 自己画反而可控：真实弹窗的箭头跟着菜单栏图标在屏幕上的位置浮动，每次截图都不一样
struct PopoverChrome<Content: View>: View {
    let content: Content

    private let cornerRadius: CGFloat = 12
    private let arrowWidth: CGFloat = 22
    private let arrowHeight: CGFloat = 10

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// 箭头和卡片并成一个形状再统一填色、统一上阴影。
    /// 分开画的话阴影会沿着箭头的斜边勾出一道轮廓，箭头看起来比卡片淡一截
    private struct Outline: Shape {
        let cornerRadius: CGFloat
        let arrowWidth: CGFloat
        let arrowHeight: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let card = CGRect(x: rect.minX, y: rect.minY + arrowHeight,
                              width: rect.width, height: rect.height - arrowHeight)
            path.addRoundedRect(in: card,
                                cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                                style: .continuous)

            let centerX = rect.midX
            path.move(to: CGPoint(x: centerX - arrowWidth / 2, y: rect.minY + arrowHeight))
            path.addLine(to: CGPoint(x: centerX, y: rect.minY))
            path.addLine(to: CGPoint(x: centerX + arrowWidth / 2, y: rect.minY + arrowHeight))
            path.closeSubpath()
            return path
        }
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(.top, arrowHeight)
            .background(
                Outline(cornerRadius: cornerRadius, arrowWidth: arrowWidth, arrowHeight: arrowHeight)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(isDark ? 0.45 : 0.22), radius: 10, y: 3)
            )
    }
}

// MARK: - 首屏合成图

/// 菜单栏图标 + 挂在它下面的弹窗。
///
/// 图标是真实的 `MenuBarIconRenderer` 出的，弹窗是真实的 `UsageDetailView`，
/// 只有那条菜单栏底是合成的——真机上截不到「菜单栏和弹窗同框」这种画面。
///
/// 不画壁纸：伪造的桌面会随 macOS 改版过时，而且这是产品示意图，不该假装成整屏截图。
/// 条之外背景透明，留给 GitHub 自己的底色，配 README 里的 `<picture>` 明暗两版各自贴合。
/// 条必须通宽并贴着画布顶边，否则读者看不出那是屏幕顶端，只会当成一排浮着的小图标
struct HeroShot<Content: View>: View {
    let menuBarIcon: NSImage
    /// 单色主题的图标是交给系统上色的模板图，需要按明暗自己填色。
    /// 生成那一侧见 `monochromeMenuBarIcon`
    let iconIsTemplate: Bool
    let content: Content

    /// 阴影要往外扩，留出来免得被画布切掉
    private let shadowMargin: CGFloat = 16
    private let stripHeight: CGFloat = 24

    init(menuBarIcon: NSImage, iconIsTemplate: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.menuBarIcon = menuBarIcon
        self.iconIsTemplate = iconIsTemplate
        self.content = content()
    }

    private var hairlineColor: Color { isDark ? .white.opacity(0.10) : .black.opacity(0.09) }

    @ViewBuilder
    private var iconView: some View {
        if iconIsTemplate {
            // 只拿遮罩的 alpha、重新上色，和 macOS 对 template 图做的事一致。
            // 不能用 colorInvert：那会连不透明的区域一起翻，环会变成实心暗块
            Image(nsImage: menuBarIcon)
                .renderingMode(.template)
                .foregroundStyle(isDark ? Color.white : Color.black)
        } else {
            Image(nsImage: menuBarIcon)
        }
    }

    /// 菜单栏的上下边界线：只示意位置，不抢注意力。
    /// 不填背景，让 GitHub 自己的底色透过去
    private var hairline: some View {
        Rectangle()
            .fill(hairlineColor)
            .frame(height: 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            hairline
            iconView
                .frame(maxWidth: .infinity)
                .frame(height: stripHeight)
            hairline

            PopoverChrome { content }
                .padding(.horizontal, shadowMargin)
                .padding(.bottom, shadowMargin)
                .padding(.top, 2)
        }
        .fixedSize()
    }
}

/// 首屏并排图：两种显示模式各一组，合成进同一张 PNG。
///
/// 接的是**已经渲染好的位图**，不是视图——原因见 `renderImage`。
///
/// 不拆成两张图交给 markdown 表格排版：表格的单元格内边距会把总宽顶过 README 的
/// 正文宽度，而且窄屏时会横向滚动。合成成一张，间距和基线都由这里定死，
/// 缩放时整体等比，不会错位
struct SideBySideHero: View {
    let left: NSImage
    let leftLabel: String
    let right: NSImage
    let rightLabel: String

    private var labelColor: Color { isDark ? .white.opacity(0.55) : .black.opacity(0.5) }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            labeled(left, leftLabel)
            labeled(right, rightLabel)
        }
        .fixedSize()
    }

    @ViewBuilder
    private func labeled(_ image: NSImage, _ text: String) -> some View {
        VStack(spacing: 2) {
            Image(nsImage: image)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(labelColor)
                .multilineTextAlignment(.center)
                // 限宽并允许换行：德语和法语的说明比图还宽，
                // 不限的话会把整组撑开，两组并排的总宽就超出 README 正文区了
                .frame(width: image.size.width)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 窗口外壳：圆角和阴影是窗口系统给的，不属于 SwiftUI 视图。
///
/// 刻意不画标题栏和红绿灯：伪造的系统 chrome 会随 macOS 改版过时。
/// 只给圆角和阴影，读起来是「一块界面」，不假装成一张整窗截图
struct WindowChrome<Content: View>: View {
    let content: Content

    private let cornerRadius: CGFloat = 10

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // 必须给内容补一层不透明的窗口底：设置页的内容区本身是透明的，
        // 真实运行时那层底由 NSWindow 提供。
        //
        // 阴影也必须挂在背景形状上，不能直接加在 content 上——SwiftUI 的 .shadow
        // 作用于合成后的图层，内容区透明时每个不透明元素（卡片、单选圆点、勾选框）
        // 都会各自投影，整个窗口看起来就散成好几块浮着的东西
        return content
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(shape)
            .background(
                shape
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(isDark ? 0.5 : 0.25), radius: 14, y: 4)
            )
            .padding(20)
    }
}

// MARK: - 假数据

/// 配图用的假数据。
///
/// 数字是挑过的，不是随手填的——线性图画的是「用量 vs 时间」，对角线代表匀速。
/// 两个点都贴着对角线的话，这张图就看不出它想说什么。所以每一列都安排成
/// 一个点明显在对角线上方（用得比时间快）、一个明显在下方（还宽裕），
/// 横向也拉开距离，时间轴才读得出来。
///
/// 百分比也刻意错开，避免出现一排一样的数字——那看着就像没填真数据。
enum MockUsage {
    /// 重置时间以「当前整点」为基准加整小时偏移。
    ///
    /// 直接用 `Date()` 的话分钟数每次渲染都不同，README 的图每重跑一次就多一次
    /// 无意义的 diff。对齐到整点后同一小时内重复渲染结果一致，显示出来也是干净的整点。
    ///
    /// 做不到完全确定：跨小时重渲仍会变。要彻底钉死，得让视图接受注入的 `now`
    /// （`UsagePaceGraphMath` 的接口已经留了这个参数，是视图没往下传），
    /// 那是为了出图去改 app 代码，不划算
    static let anchor: Date = {
        let calendar = Calendar.current
        let now = Date()
        var parts = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        parts.minute = 0
        parts.second = 0
        return calendar.date(from: parts) ?? now
    }()

    static func resets(inHours hours: Double, minutes: Double = 0) -> Date {
        anchor.addingTimeInterval(hours * 3600 + minutes * 60)
    }

    @MainActor
    static func codex() -> CodexUsageData {
        CodexUsageData(
            // 5 小时窗口已过 60%，却用掉了 88%——点落在对角线上方，明显超速
            primary: CodexUsageData.LimitData(percentage: 88, resetsAt: resets(inHours: 2)),
            // 7 天窗口已过约 40%，只用了 30%——点落在下方，还有余量。
            //
            // 这一项刻意不是整点：Codex 的 7 天窗口返回的是 reset_after_seconds
            // （一个倒计时），重置时刻落在任意分钟上，界面也专门用了精确到分钟的格式
            //（见 formattedCompactResetDateWithMinutes）。配图如果凑成整点，
            // 那个 ":00" 看着就像格式没统一
            secondary: CodexUsageData.LimitData(percentage: 30,
                                                resetsAt: resets(inHours: 100, minutes: 37)),
            extraUsage: CodexExtraUsageData(
                hasCredits: true,
                unlimited: false,
                overageLimitReached: false,
                spendControlReached: false,
                balance: Decimal(string: "99.00"),
                approxLocalMessages: nil,
                approxCloudMessages: nil
            )
        )
    }

    @MainActor
    static func claude() -> UsageData {
        UsageData(
            // 5 小时窗口才过 40%，已经用掉 66%——上方，用得偏快。
            // 这个值同时是圆环视图中间那个大数字，66% 的弧长也好看
            fiveHour: UsageData.LimitData(percentage: 66, resetsAt: resets(inHours: 3)),
            // 7 天窗口已过 75%，只用了 45%——下方，节奏宽裕
            sevenDay: UsageData.LimitData(percentage: 45, resetsAt: resets(inHours: 42)),
            opus: nil,
            sonnet: nil,
            extraUsage: ExtraUsageData(enabled: true, used: 55.55, limit: 100, currency: "USD")
        )
    }
}

@MainActor
func detailView(withCodex: Bool) -> some View {
    UsageDetailView(
        usageData: .constant(MockUsage.claude()),
        codexUsageData: .constant(withCodex ? MockUsage.codex() : nil),
        errorMessage: .constant(nil),
        errorRequiresAuthAction: .constant(false),
        codexErrorMessage: .constant(nil),
        codexErrorRequiresAuthAction: .constant(false),
        codexNeedsRelogin: .constant(false),
        codexResetAnnouncement: .constant(nil),
        refreshState: RefreshState(),
        hasAvailableUpdate: .constant(false),
        shouldShowUpdateBadge: .constant(false)
    )
}

// MARK: - 菜单栏图标

/// 生成菜单栏图标。
///
/// `createIcon` 在 SwiftUI 之外直接调用，内部靠 `NSImage.lockFocus()` 绘制，
/// 用的颜色有动态色（圆环数字走 `menuBarIconTextColor`，单色模式的描边是
/// `NSColor.labelColor`），解析结果取决于绘制时的外观。
///
/// 这个外观必须是**应用级**的：`performAsCurrentDrawingAppearance` 管不到
/// `lockFocus` 内部，实测数字和描边仍会按这台机器系统的深浅取色——系统是深色时，
/// 浅色那版图上的数字就是白的，整个看不见。`NSApp.appearance` 才压得住。
/// 渲染器是个跑完就退的短命进程，改这个没有副作用
@MainActor
func applyRenderAppearance() {
    NSApplication.shared.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
}

@MainActor
func menuBarIcon(_ make: () -> NSImage) -> NSImage {
    let image = make()
    image.isTemplate = false
    return image
}

/// 单色主题的图标：固定在浅色外观下生成，深色变体交给 `HeroShot` 整张反相。
///
/// 单色出的是 alpha 遮罩——环用动态色 `NSColor.labelColor`，数字却是写死的
/// `NSColor.black`。对真实 app 无所谓，系统只取 alpha 再统一上色；但离屏渲染用的是
/// RGB，深色外观下环会变白、数字仍是黑，两者对不上，出来就是白环黑字。
///
/// 钉死浅色外观能拿到一张纯黑的遮罩，再整张反相就是纯白，正是 macOS 自己做的事
@MainActor
func monochromeMenuBarIcon(_ make: () -> NSImage) -> NSImage {
    let saved = NSApplication.shared.appearance
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    defer { NSApplication.shared.appearance = saved }
    return menuBarIcon(make)
}

// MARK: - 语言

/// 文件名里的语言代码沿用 docs/images 既有的写法，和 README.zh-CN.md 这类文件名对得上。
/// 注意和 `AppLanguage` 的 rawValue 不同（zh-Hans / zh-Hant）
let docsLanguageCode: [AppLanguage: String] = [
    .english: "en",
    .japanese: "ja",
    .chinese: "zh-CN",
    .chineseTraditional: "zh-TW",
    .korean: "ko",
    .french: "fr",
    .german: "de"
]

/// 首屏两组图下方的说明文字。
/// 渲染器专用，不进 app 的本地化文件——那里只该放界面上真正出现的字符串
let heroLabels: [AppLanguage: (left: String, right: String)] = [
    .english: ("Claude · Ring view · Menu bar (color, with icon)",
               "Claude + Codex · Pace view · Menu bar (monochrome, no icon)"),
    .japanese: ("Claude · リング表示 · メニューバー（カラー、アイコンあり）",
                "Claude + Codex · ペース表示 · メニューバー（モノクロ、アイコンなし）"),
    .chinese: ("Claude · 圆环图 · 菜单栏（彩色有图标）",
               "Claude + Codex · 节奏图 · 菜单栏（单色无图标）"),
    .chineseTraditional: ("Claude · 圓環圖 · 選單列（彩色有圖示）",
                          "Claude + Codex · 節奏圖 · 選單列（單色無圖示）"),
    .korean: ("Claude · 링 보기 · 메뉴바(컬러, 아이콘 포함)",
              "Claude + Codex · 페이스 보기 · 메뉴바(흑백, 아이콘 없음)"),
    .french: ("Claude · Vue anneau · Barre des menus (couleur, avec icône)",
              "Claude + Codex · Vue rythme · Barre des menus (monochrome, sans icône)"),
    .german: ("Claude · Ring-Ansicht · Menüleiste (farbig, mit Symbol)",
              "Claude + Codex · Tempo-Ansicht · Menüleiste (einfarbig, ohne Symbol)")
]

// MARK: - 入口

MainActor.assumeIsolated {
    DocsRenderMode.isActive = true
    applyRenderAppearance()

    let settings = UserSettings.shared
    // 快照，渲染完原样放回去：这个进程的 Bundle.main 是 app bundle，
    // UserDefaults 域和正式版是同一个，不还原会把用户的设置留在出图状态。
    // 新增任何被渲染器改动的设置项，都要加进这个元组
    let saved = (settings.displayMode, settings.customDisplayTypes, settings.graphDisplayType,
                 settings.menuBarIconSize, settings.iconDisplayMode, settings.iconStyleMode,
                 settings.debugModeEnabled, settings.language)
    defer {
        (settings.displayMode, settings.customDisplayTypes, settings.graphDisplayType,
         settings.menuBarIconSize, settings.iconDisplayMode, settings.iconStyleMode,
         settings.debugModeEnabled, settings.language) = saved
    }

    for language in AppLanguage.allCases {
        // localized() 每次调用都读 UserSettings.shared.language 并加载对应的 .lproj，
        // 所以这里切完立刻生效，不需要重启或发通知
        settings.language = language
        let code = docsLanguageCode[language] ?? language.rawValue
        let labels = heroLabels[language] ?? heroLabels[.english]!
        print("rendering \(code) \(variant)…")

        // 第一组：圆环图 Claude，三个常用限额；菜单栏中等尺寸、彩色、图标 + 百分比
        settings.debugModeEnabled = false
        settings.displayMode = .custom
        settings.customDisplayTypes = [.fiveHour, .sevenDay, .extraUsage]
        settings.graphDisplayType = .ring
        settings.menuBarIconSize = .medium
        settings.iconDisplayMode = .both
        settings.iconStyleMode = .colorTranslucent

        let ringIcon = menuBarIcon {
            MenuBarIconRenderer(settings: settings)
                .createIcon(usageData: MockUsage.claude(), hasUpdate: false, button: nil)
        }
        let ringShot = renderImage(
            HeroShot(menuBarIcon: ringIcon) { detailView(withCodex: false) }
        )

        // 第二组：节奏图 + Claude/Codex 双栏。菜单栏换成单色、只显示百分比，
        // 和第一组的彩色带图标形成对照，顺带说明这两项都能换。
        //
        // 双栏形态由 isMultiProviderActive 决定，正常路径要求两家都真的有账户；
        // DEBUG 下调试模式 + 自定义显示里两家类型都勾上也算数，走这条不用伪造凭据
        settings.debugModeEnabled = true
        settings.customDisplayTypes = [.fiveHour, .sevenDay, .extraUsage,
                                       .codexPrimary, .codexSecondary, .codexExtraUsage]
        settings.graphDisplayType = .pace
        settings.iconDisplayMode = .percentageOnly
        settings.iconStyleMode = .monochrome

        let paceIcon = monochromeMenuBarIcon {
            MenuBarIconRenderer(settings: settings)
                .createIcon(usageData: MockUsage.claude(),
                            codexUsageData: MockUsage.codex(),
                            hasUpdate: false,
                            button: nil)
        }
        let paceShot = renderImage(
            HeroShot(menuBarIcon: paceIcon, iconIsTemplate: true) {
                detailView(withCodex: true)
            }
        )

        if let ringShot, let paceShot {
            write(
                SideBySideHero(left: ringShot, leftLabel: labels.left,
                               right: paceShot, rightLabel: labels.right),
                to: "hero.\(code).\(variant)@2x.png"
            )
        }

        // 设置窗口「显示」页。前面两组把设置改成了单色/仅百分比/节奏图，
        // 这里要摆回有代表性的默认样子，否则截出来的是上一组留下的状态
        settings.debugModeEnabled = false
        settings.iconStyleMode = .colorTranslucent
        settings.iconDisplayMode = .both
        settings.menuBarIconSize = .medium
        settings.displayMode = .smart
        settings.graphDisplayType = .ring

        write(WindowChrome { SettingsView(initialTab: .display) },
              to: "settings.display.\(code).\(variant)@2x.png")
    }
}
