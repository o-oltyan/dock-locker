import CoreGraphics
import Testing

@testable import DockLockerCore

@Suite struct GeometryConversionTests {
    @Test func pointCocoaToCG() {
        let cg = GeometryConversion.cgPoint(fromCocoa: CGPoint(x: 100, y: 200), mainDisplayHeight: 1000)
        #expect(cg == CGPoint(x: 100, y: 800))
    }

    @Test func pointConversionIsAnInvolution() {
        let original = CGPoint(x: -350, y: 1234)
        let there = GeometryConversion.cgPoint(fromCocoa: original, mainDisplayHeight: 1080)
        let back = GeometryConversion.cocoaPoint(fromCG: there, mainDisplayHeight: 1080)
        #expect(back == original)
    }

    @Test func rectCocoaToCG() {
        let cocoa = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let cg = GeometryConversion.cgRect(fromCocoa: cocoa, mainDisplayHeight: 1080)
        #expect(cg == CGRect(x: 0, y: 580, width: 1000, height: 500))
    }

    @Test func rectAboveAndLeftOfMainGetsNegativeCGCoordinates() {
        // A 1920x1080 display sitting left of and above a 1920x1080 main display.
        // Cocoa: its origin is (-1920, 1080). CG: origin should be (-1920, -1080).
        let cocoa = CGRect(x: -1920, y: 1080, width: 1920, height: 1080)
        let cg = GeometryConversion.cgRect(fromCocoa: cocoa, mainDisplayHeight: 1080)
        #expect(cg == CGRect(x: -1920, y: -1080, width: 1920, height: 1080))
    }

    @Test func rectConversionIsAnInvolution() {
        let original = CGRect(x: 2560, y: -400, width: 1440, height: 2560)
        let there = GeometryConversion.cgRect(fromCocoa: original, mainDisplayHeight: 1169)
        let back = GeometryConversion.cocoaRect(fromCG: there, mainDisplayHeight: 1169)
        #expect(back == original)
    }
}
