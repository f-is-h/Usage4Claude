//
//  Usage4ClaudeWidget.swift
//  Usage4ClaudeWidget
//
//  WidgetKit widget for displaying Claude usage data.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let data = SharedUsageData.load() ?? .placeholder
        completion(UsageEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let data = SharedUsageData.load() ?? SharedUsageData.error("No data available. Open the app to configure.")

        let currentDate = Date()
        let entry = UsageEntry(date: currentDate, data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let data: SharedUsageData
}

// MARK: - Widget Definition

struct Usage4ClaudeWidget: Widget {
    let kind: String = "Usage4ClaudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            UsageWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude.ai usage limits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Entry View

struct UsageWidgetEntryView: View {
    var entry: UsageEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let data: SharedUsageData

    var body: some View {
        if data.hasError {
            ErrorView(message: data.errorMessage ?? "Error")
        } else if !data.hasData {
            NoDataView()
        } else {
            // Show up to 2 rings in small widget
            let limits = Array(data.activeLimits.prefix(2))
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(limits) { limit in
                        UsageRingView(limit: limit, size: 60)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget View (Apple Style - Screenshot Match)

struct MediumWidgetView: View {
    let data: SharedUsageData

    var body: some View {
        if data.hasError {
            ErrorView(message: data.errorMessage ?? "Error")
        } else if !data.hasData {
            NoDataView()
        } else {
            // Show up to 4 rings like the screenshot
            let limits = Array(data.activeLimits.prefix(4))
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    if index < limits.count {
                        UsageRingItemView(limit: limits[index])
                    } else {
                        EmptyRingItemView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Usage Ring Item View (with label)

struct UsageRingItemView: View {
    let limit: SharedUsageData.LimitEntry

    var body: some View {
        VStack(spacing: 8) {
            UsageRingView(limit: limit, size: 70)

            Text("\(Int(limit.percentage))%")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty Ring Item View

struct EmptyRingItemView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 70, height: 70)
            }

            Text("-")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Usage Ring View

struct UsageRingView: View {
    let limit: SharedUsageData.LimitEntry
    let size: CGFloat

    private var ringColor: Color {
        WidgetColorScheme.color(for: limit.type, percentage: limit.percentage)
    }

    private var progress: Double {
        min(1.0, max(0.0, limit.percentage / 100.0))
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: size * 0.12)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Center icon
            Image(systemName: limit.type.iconName)
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)

            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding()
    }
}

// MARK: - No Data View

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Open app to sync")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Widget Color Scheme

enum WidgetColorScheme {
    /// Get color for limit type and percentage
    static func color(for type: SharedUsageData.LimitType, percentage: Double) -> Color {
        switch type {
        case .fiveHour:
            return fiveHourColor(percentage)
        case .sevenDay:
            return sevenDayColor(percentage)
        case .opus:
            return opusColor(percentage)
        case .sonnet:
            return sonnetColor(percentage)
        case .extraUsage:
            return extraUsageColor(percentage)
        }
    }

    // 5-Hour: Green → Orange → Red
    private static func fiveHourColor(_ percentage: Double) -> Color {
        if percentage < 70 {
            return Color(red: 40/255.0, green: 180/255.0, blue: 70/255.0) // Green #28B446
        } else if percentage < 90 {
            return .orange
        } else {
            return .red
        }
    }

    // 7-Day: Light Purple → Deep Purple → Deep Magenta
    private static func sevenDayColor(_ percentage: Double) -> Color {
        if percentage < 70 {
            return Color(red: 192/255.0, green: 132/255.0, blue: 252/255.0) // #C084FC
        } else if percentage < 90 {
            return Color(red: 180/255.0, green: 80/255.0, blue: 240/255.0)  // #B450F0
        } else {
            return Color(red: 180/255.0, green: 30/255.0, blue: 160/255.0)  // #B41EA0
        }
    }

    // Opus: Amber → Orange → Orange-Red
    private static func opusColor(_ percentage: Double) -> Color {
        if percentage < 70 {
            return Color(red: 251/255.0, green: 191/255.0, blue: 36/255.0)  // #FBBF24
        } else if percentage < 90 {
            return .orange
        } else {
            return Color(red: 255/255.0, green: 100/255.0, blue: 50/255.0)  // #FF6432
        }
    }

    // Sonnet: Light Blue → Blue → Indigo
    private static func sonnetColor(_ percentage: Double) -> Color {
        if percentage < 70 {
            return Color(red: 100/255.0, green: 200/255.0, blue: 255/255.0) // #64C8FF
        } else if percentage < 90 {
            return .blue
        } else {
            return Color(red: 79/255.0, green: 70/255.0, blue: 229/255.0)   // #4F46E5
        }
    }

    // Extra Usage: Pink → Magenta → Purple
    private static func extraUsageColor(_ percentage: Double) -> Color {
        if percentage < 70 {
            return Color(red: 255/255.0, green: 158/255.0, blue: 205/255.0) // #FF9ECD
        } else if percentage < 90 {
            return Color(red: 236/255.0, green: 72/255.0, blue: 153/255.0)  // #EC4899
        } else {
            return Color(red: 217/255.0, green: 70/255.0, blue: 239/255.0)  // #D946EF
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    Usage4ClaudeWidget()
} timeline: {
    UsageEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    Usage4ClaudeWidget()
} timeline: {
    UsageEntry(date: .now, data: .placeholder)
}
