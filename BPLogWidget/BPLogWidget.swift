import WidgetKit
import SwiftUI

struct ReadingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// The app reloads timelines whenever readings change, so one entry and no refresh schedule.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(ReadingEntry(date: Date(), snapshot: context.isPreview ? (WidgetSnapshot.load() ?? .sample) : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        completion(Timeline(entries: [ReadingEntry(date: Date(), snapshot: WidgetSnapshot.load())], policy: .never))
    }
}

/// Latest reading at a glance; any tap opens the Add Reading form.
struct BPLogWidget: Widget {
    let kind = "BPLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
                .widgetURL(WidgetSnapshot.addURL)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Blood Pressure")
        .description("Your latest reading. Tap to add a new one.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct WidgetView: View {
    let entry: ReadingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            if let s = entry.snapshot {
                latest(s)
            } else {
                empty
            }
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                if let s = entry.snapshot { latest(s) } else { empty }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                if let s = entry.snapshot, let sys = s.weekSystolic, let dia = s.weekDiastolic {
                    Text("7-day average").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(sys)/\(dia)").font(.system(size: 26, weight: .bold, design: .rounded))
                }
                Spacer(minLength: 0)
                Label("Add Reading", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.brand))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
            Text("Simply BP")
            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill").font(.title3)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.brand)
    }

    private func latest(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(s.systolic)/\(s.diastolic)")
                .privacySensitive()
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(s.categoryTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(s.categoryColor)
                .lineLimit(1)
            Text(s.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No readings yet").font(.headline)
            Text("Tap to add your first one").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Blood pressure", systemImage: "heart.fill").font(.caption2.weight(.semibold))
            if let s = entry.snapshot {
                Text("\(s.systolic)/\(s.diastolic)").font(.system(size: 22, weight: .bold, design: .rounded)).privacySensitive()
                Text(s.categoryTitle).font(.caption2)
            } else {
                Text("Tap to add a reading").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = entry.snapshot {
                VStack(spacing: -2) {
                    Text("\(s.systolic)").font(.system(size: 17, weight: .bold, design: .rounded)).privacySensitive()
                    Rectangle().frame(width: 22, height: 1.5)
                    Text("\(s.diastolic)").font(.system(size: 15, weight: .semibold, design: .rounded)).privacySensitive()
                }
            } else {
                Image(systemName: "plus").font(.title2.weight(.bold))
            }
        }
    }
}

@main
struct BPLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BPLogWidget()
    }
}
