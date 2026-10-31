import Foundation

/// Host clock read out in seconds, so every capture source can timestamp its
/// samples on one shared timeline.
nonisolated enum HostClock {
    private static let scale: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    static func seconds() -> Double {
        seconds(fromTicks: mach_absolute_time())
    }

    /// Host ticks → seconds, for the IOProc's `inInputTime`.
    static func seconds(fromTicks ticks: UInt64) -> Double {
        Double(ticks) * scale
    }
}
