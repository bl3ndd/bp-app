import Testing
import CoreGraphics
@testable import BPLog

struct MonitorReaderTests {
    private func item(_ text: String, y: CGFloat, height: CGFloat, x: CGFloat = 100, width: CGFloat = 200) -> MonitorReader.Item {
        MonitorReader.Item(text: text, rect: CGRect(x: x, y: y, width: width, height: height))
    }

    @Test func readsAStackedOmronStyleScreen() {
        let items = [
            item("SYS", y: 40, height: 20, x: 20, width: 60),
            item("128", y: 40, height: 120),
            item("DIA", y: 180, height: 20, x: 20, width: 60),
            item("82", y: 180, height: 110),
            item("PULSE /min", y: 320, height: 20, x: 20, width: 100),
            item("70", y: 320, height: 60),
        ]
        #expect(MonitorReader.read(items) == .init(systolic: 128, diastolic: 82, pulse: 70))
    }

    @Test func pulseIsOptional() {
        let items = [item("135", y: 40, height: 120), item("88", y: 180, height: 110)]
        #expect(MonitorReader.read(items) == .init(systolic: 135, diastolic: 88, pulse: nil))
    }

    @Test func ignoresClockAndDate() {
        let items = [
            item("10/30 7:42", y: 0, height: 30),
            item("121", y: 40, height: 120),
            item("79", y: 180, height: 110),
            item("64", y: 320, height: 60),
        ]
        #expect(MonitorReader.read(items) == .init(systolic: 121, diastolic: 79, pulse: 64))
    }

    @Test func smallMemoryNumbersDontWinOverTheBigReading() {
        // A small "previous reading" corner must lose to the big numbers.
        let items = [
            item("110", y: 10, height: 25, x: 300, width: 60),
            item("70", y: 40, height: 25, x: 300, width: 60),
            item("142", y: 60, height: 120),
            item("91", y: 200, height: 110),
            item("77", y: 340, height: 60),
        ]
        #expect(MonitorReader.read(items) == .init(systolic: 142, diastolic: 91, pulse: 77))
    }

    @Test func numbersOnOneLineReadLeftToRight() {
        let items = [item("118 76", y: 50, height: 100, width: 400), item("66", y: 200, height: 50)]
        #expect(MonitorReader.read(items) == .init(systolic: 118, diastolic: 76, pulse: 66))
    }

    @Test func samePulseAsBottomNumberIsKept() {
        let items = [item("130", y: 40, height: 120), item("82", y: 180, height: 110), item("82", y: 320, height: 60)]
        #expect(MonitorReader.read(items) == .init(systolic: 130, diastolic: 82, pulse: 82))
    }

    @Test func implausibleNumbersGiveNothing() {
        #expect(MonitorReader.read([item("12", y: 40, height: 120), item("8", y: 180, height: 110)]) == nil)
        #expect(MonitorReader.read([item("80", y: 40, height: 120), item("120", y: 180, height: 110)]) == nil)
        #expect(MonitorReader.read([]) == nil)
    }
}
