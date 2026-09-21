import Testing

@testable import DockLockerCore

@Suite struct PermissionStateTests {
    @Test func trustedWhenAXTrustedAndTapWorks() {
        #expect(
            PermissionState.resolve(axTrusted: true, tapFailed: false, wasGrantedBefore: false)
                == .trusted)
        #expect(
            PermissionState.resolve(axTrusted: true, tapFailed: false, wasGrantedBefore: true)
                == .trusted)
    }

    @Test func staleWhenAXTrustedButTapFails() {
        #expect(
            PermissionState.resolve(axTrusted: true, tapFailed: true, wasGrantedBefore: false)
                == .stale)
    }

    @Test func staleWhenGrantNoLongerMatchesThisBuild() {
        #expect(
            PermissionState.resolve(axTrusted: false, tapFailed: false, wasGrantedBefore: true)
                == .stale)
    }

    @Test func untrustedWhenNeverGranted() {
        #expect(
            PermissionState.resolve(axTrusted: false, tapFailed: false, wasGrantedBefore: false)
                == .untrusted)
    }
}
