// Tests for --box outlines: an outline never covers its own text, sides are dropped
// where they would cover a neighboring label on a crowded axis, and a box that is both
// handled and warned about is outlined in red only.

import CoreGraphics
import Testing
@testable import ShotShifter

/// Tests for `BoxMarker`.
struct BoxMarkerTests {
    /// A lone box gets all four edges, none of which touches the box itself.
    @Test func outlinesLoneBoxOnAllSides() {
        let box = CGRect(x: 100, y: 50, width: 60, height: 20)
        let edges = BoxMarker.edges(of: box, among: [box])
        #expect(edges.count == 4)
        #expect(!edges.contains { $0.intersects(box) })
    }

    /// Touching boxes keep their top, bottom and outer sides but lose the side facing the neighbor, which would cover its text.
    @Test func dropsSidesThatCrossNeighbors() {
        let left = CGRect(x: 100, y: 50, width: 60, height: 20)
        let right = CGRect(x: 160, y: 50, width: 60, height: 20)
        for (box, other) in [(left, right), (right, left)] {
            let edges = BoxMarker.edges(of: box, among: [left, right])
            #expect(edges.count == 3)
            #expect(!edges.contains { $0.intersects(box) || $0.intersects(other) })
        }
    }

    /// A box that is both handled and warned about shows no green.
    @Test func warnedBoxIsRedOnly() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let box = CGRect(x: 60.3, y: 40.7, width: 50.5, height: 20.2)
        let marked = try BoxMarker.mark(try #require(context.makeImage()), handled: [box], warned: [box])
        let rows = try TestSupport.outlineRows(in: marked)
        #expect(rows.green.isEmpty && !rows.red.isEmpty)
    }
}
