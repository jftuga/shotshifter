// Tests for finding axes among labels: grouping by line, splitting a line holding two
// side-by-side axes into two rows, keeping skipped ticks in a row, and leaving stray
// labels out of every row.

import Testing
@testable import ShotShifter

/// Tests for `AxisRowDetector`.
struct AxisRowDetectorTests {
    /// Two panels side by side put two axes on one line; each becomes its own row.
    @Test func splitsSideBySideAxes() {
        let left = TestSupport.labels(["20:00", "21:00", "22:00", "23:00"], startX: 100, spacing: 100)
        let right = TestSupport.labels(["20:00", "20:05", "20:10", "20:15"], startX: 600, spacing: 60, y: 503)
        let result = AxisRowDetector.detect(left + right, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["20:00", "21:00", "22:00", "23:00"], ["20:00", "20:05", "20:10", "20:15"]])
        #expect(result.unusedLabels.isEmpty)
    }

    /// Stacked panels produce one row per line.
    @Test func findsStackedAxes() {
        let top = TestSupport.labels(["10/16", "10/17", "10/18"], y: 100)
        let bottom = TestSupport.labels(["14:00:00", "14:00:30", "14:01:00"], y: 900)
        #expect(AxisRowDetector.detect(top + bottom, currentYear: TestSupport.year).rows.count == 2)
    }

    /// A skipped tick keeps the same minutes-per-pixel, so the row stays whole.
    @Test func keepsSkippedTick() {
        let labels = TestSupport.labels(["20:00", "21:00"], startX: 100, spacing: 100) + TestSupport.labels(["23:00", "00:00"], startX: 400, spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.count == 1 && result.rows.first?.labels.count == 4)
    }

    /// A lone label, and labels of a different kind, are not part of any row.
    @Test func leavesStrayLabels() {
        let axis = TestSupport.labels(["20:00", "21:00", "22:00"])
        let stray = TestSupport.labels(["14:00"], y: 900) + TestSupport.labels(["10/16"], startX: 700)
        let result = AxisRowDetector.detect(axis + stray, currentYear: TestSupport.year)
        #expect(result.rows.count == 1)
        #expect(Set(result.unusedLabels.map(\.text)) == ["14:00", "10/16"])
    }

    /// A step that changes by more than the tolerance closes the row; the new run starts at the label that broke it.
    @Test func splitsOnStepChange() {
        let labels = TestSupport.labels(["20:00", "21:00", "22:00", "22:10", "22:20"], spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["20:00", "21:00", "22:00"], ["22:10", "22:20"]])
        #expect(result.unusedLabels.isEmpty)
    }
}
