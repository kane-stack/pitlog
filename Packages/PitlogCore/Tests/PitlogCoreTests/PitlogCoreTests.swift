import Testing
@testable import PitlogCore

@Test func moduleVersionIsSet() {
    #expect(!PitlogCore.version.isEmpty)
}
