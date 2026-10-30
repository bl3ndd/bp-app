import Foundation

/// Two months of believable readings for `-DEMO`: morning and evening, sometimes
/// two in a row, slowly improving from Stage 1 toward Normal, with noise, a
/// few spikes and lows, tags and the odd missed day. Deterministic, so a demo
/// looks the same every launch.
nonisolated enum DemoData {
    struct Sample: Equatable {
        var value: ReadingValue
        var tags: [String]
    }

    static func samples(now: Date, calendar: Calendar, days: Int = 60) -> [Sample] {
        var rng = SplitMix64(seed: 2026)
        var out: [Sample] = []
        let today = calendar.startOfDay(for: now)
        for dayOffset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if rng.next(100) < 8 { continue }  // missed day
            let progress = Double(days - 1 - dayOffset) / Double(max(days - 1, 1))
            let baseSys = 137 - 16 * progress
            let baseDia = 85 - 11 * progress
            for (hour, eveningBump) in [(7, 0.0), (20, -4.0)] {
                if hour == 20, rng.next(100) < 25 { continue }  // skipped evening
                let count = rng.next(100) < 30 ? 2 : 1
                for i in 0..<count {
                    let minute = 10 + Int(rng.next(40)) + i * 3
                    guard let date = calendar.date(byAdding: .minute, value: hour * 60 + minute, to: day), date <= now else { continue }
                    var sys = baseSys + eveningBump + Double(rng.next(13)) - 6
                    var dia = baseDia + eveningBump / 2 + Double(rng.next(9)) - 4
                    var tags: [String] = []
                    switch rng.next(100) {
                    case 0..<4: sys += 22; dia += 9; tags = ["Stressed"]
                    case 4..<10: sys += 9; tags = ["After coffee"]
                    case 10..<12: sys -= 30; dia -= 22; tags = ["Felt dizzy"]
                    case 12..<30: tags = ["Took medication"]
                    default: break
                    }
                    let pulse = 62 + Int(rng.next(18))
                    out.append(Sample(value: ReadingValue(date: date, systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()), pulse: pulse),
                                      tags: tags))
                }
            }
        }
        return out
    }
}

/// Tiny deterministic generator; `SystemRandomNumberGenerator` can't be seeded.
nonisolated struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next(_ upperBound: UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return (z ^ (z >> 31)) % upperBound
    }
}
