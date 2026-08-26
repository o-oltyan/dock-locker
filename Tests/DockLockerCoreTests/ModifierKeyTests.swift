import CoreGraphics
import Testing

@testable import DockLockerCore

@Suite struct ModifierKeyTests {
    @Test func allFiveKeysExist() {
        #expect(ModifierKey.allCases.count == 5)
    }

    @Test func rawValueRoundTrips() {
        for key in ModifierKey.allCases {
            #expect(ModifierKey(rawValue: key.rawValue) == key)
        }
    }

    @Test func flagMasksMatchCGEventFlags() {
        #expect(ModifierKey.fn.flags == .maskSecondaryFn)
        #expect(ModifierKey.control.flags == .maskControl)
        #expect(ModifierKey.option.flags == .maskAlternate)
        #expect(ModifierKey.command.flags == .maskCommand)
        #expect(ModifierKey.shift.flags == .maskShift)
    }

    @Test func defaultIsFn() {
        #expect(ModifierKey.default == .fn)
    }

    @Test func displayNamesAreHumanReadable() {
        #expect(ModifierKey.fn.displayName.contains("Fn"))
        for key in ModifierKey.allCases {
            #expect(!key.displayName.isEmpty)
        }
    }
}
