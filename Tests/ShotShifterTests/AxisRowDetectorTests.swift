// Tests for finding axes among labels: grouping by line, splitting a line holding two
// side-by-side axes into two rows, keeping skipped ticks in a row, leaving stray and
// misread labels out of every row, and finding labels on an axis line.

import CoreGraphics
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

    /// Side-by-side panels with two labels each stay separate two-label rows.
    @Test func keepsTwoLabelPanels() {
        let labels = [100, 500, 900].flatMap { TestSupport.labels(["20:00", "22:00"], startX: CGFloat($0), spacing: 100) }
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == Array(repeating: ["20:00", "22:00"], count: 3))
        #expect(result.unusedLabels.isEmpty)
    }

    /// Misread ticks inside an axis are left out of the row rather than paired with their right
    /// neighbor into a two-label row and shifted to a wrong time (img048: 10:30 read as `10:20`
    /// and 11:10 as `10:00` became the rows `10:20 10:40` and `10:00 11:20`).
    @Test func leavesOutMisreadTicks() {
        let labels = TestSupport.labels(["10:10", "10:20", "10:20", "10:40", "10:50", "11:00", "10:00", "11:20", "11:30", "11:40"], spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["10:10", "10:20", "10:40", "10:50", "11:00", "11:20", "11:30", "11:40"]])
        #expect(result.unusedLabels.map(\.box.minX) == [300, 700])
    }

    /// A misread seconds tick next to the end of an axis is left out the same way (img110: 19:30:00
    /// read as `10:30:00` became the row `10:30:00 19:31:00` and was rewritten as 05:30:00).
    @Test func leavesOutMisreadSecondsTick() {
        let labels = TestSupport.labels(["19:27:00", "19:28:00", "19:29:00", "10:30:00", "19:31:00"], spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["19:27:00", "19:28:00", "19:29:00", "19:31:00"]])
        #expect(result.unusedLabels.map(\.text) == ["10:30:00"])
    }

    /// Repeated two-label panels keep every label, even when the step across a panel boundary
    /// matches the step across a whole panel (img367: label centers measured from the screenshot;
    /// 22:00 to 20:00 over 661 pixels is close to 20:00 to 20:00 over 722 pixels).
    @Test func keepsRepeatedTwoLabelPanels() {
        let centers: [(String, CGFloat)] = [("20:00", 219), ("22:00", 294), ("20:00", 955), ("22:00", 1030), ("20:00", 1677), ("22:00", 1761)]
        let labels = centers.flatMap { text, center in LabelParser.labels(in: TestSupport.observation(text, x: center - 25)) }
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == Array(repeating: ["20:00", "22:00"], count: 3))
        #expect(result.unusedLabels.isEmpty)
    }

    /// A misread first tick is left out instead of forming a two-label row with the axis's second tick.
    @Test func leavesOutMisreadFirstTick() {
        let labels = TestSupport.labels(["10:30:00", "19:31:00", "19:32:00", "19:33:00"], spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["19:31:00", "19:32:00", "19:33:00"]])
        #expect(result.unusedLabels.map(\.text) == ["10:30:00"])
    }

    /// Correct labels whose recognized centers are a few pixels off are kept (img012: hourly date-time
    /// labels about 77 pixels apart, measured gaps from 70 to 84 pixels).
    @Test func keepsJitteredLabels() {
        let centers: [(String, CGFloat)] = [("06:00", 67), ("07:00", 142), ("08:00", 222), ("09:00", 300), ("10:00", 378), ("11:00", 461), ("12:00", 531), ("13:00", 615), ("14:00", 685), ("15:00", 762), ("16:00", 840), ("17:00", 913)]
        let labels = centers.flatMap { time, center in LabelParser.labels(in: TestSupport.observation("10/15 \(time)", x: center - 55)) }
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.reduce(0) { $0 + $1.labels.count } == centers.count)
        #expect(result.unusedLabels.isEmpty)
    }

    /// A minute-digit misread that is not a whole number of ticks from its neighbors is left out
    /// (img085: 17:05 on a five-minute axis read as `17:09` and rewritten as 12:09).
    @Test func leavesOutOffTickMisread() {
        let labels = TestSupport.labels(["16:50", "16:55", "17:00", "17:09", "17:10", "17:15"], spacing: 100)
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [["16:50", "16:55", "17:00", "17:10", "17:15"]])
        #expect(result.unusedLabels.map(\.text) == ["17:09"])
    }

    /// A correct first label whose box is far off center is kept (img108: the box of 18:51:00 took in
    /// text to its left, putting its center 24 pixels from the tick on a 64-pixel spacing).
    @Test func keepsOffCenterFirstLabel() {
        let centers: [(String, CGFloat)] = [("18:51:00", 105), ("18:52:00", 193), ("18:53:00", 257), ("18:54:00", 320)]
        let labels = centers.flatMap { text, center in LabelParser.labels(in: TestSupport.observation(text, x: center - 40)) }
        #expect(AxisRowDetector.detect(labels, currentYear: TestSupport.year).unusedLabels.isEmpty)
    }

    /// Jitter of more than the step tolerance keeps an axis whole when every time is a whole number of
    /// ticks from its neighbor (img104: the final 18:30 became a lone label, 36 pixels after a 42-pixel gap).
    @Test func keepsAxisWholeDespiteJitter() {
        let centers: [(String, CGFloat)] = [("17:00", 1781), ("17:15", 1818), ("17:30", 1857), ("17:45", 1896), ("18:00", 1930), ("18:15", 1972), ("18:30", 2008)]
        let labels = centers.flatMap { text, center in LabelParser.labels(in: TestSupport.observation(text, x: center - 25)) }
        let result = AxisRowDetector.detect(labels, currentYear: TestSupport.year)
        #expect(result.rows.map { $0.labels.map(\.text) } == [centers.map(\.0)])
    }

    /// Only labels that would belong to a detected row are kept: a missing tick before the row is kept,
    /// while a label on another line, a time of another format (img001: a tooltip's `18:38:00` on an
    /// `HH:mm` axis line), and a time that does not fall on a tick are dropped.
    @Test func findsLabelsFittingRows() {
        let rows = AxisRowDetector.detect(TestSupport.labels(["20:00", "21:00", "22:00"]), currentYear: TestSupport.year).rows
        let candidates = TestSupport.labels(["19:00"], startX: -50, y: 503) + TestSupport.labels(["14:00"], y: 900) + TestSupport.labels(["18:38:00"], startX: 500) + TestSupport.labels(["23:30"], startX: 550)
        #expect(AxisRowDetector.labelsFittingRows(candidates, rows: rows, currentYear: TestSupport.year).map(\.text) == ["19:00"])
    }
}
