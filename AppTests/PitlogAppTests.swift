import PitlogCore
import Testing
@testable import Pitlog

@Test func appLinksPitlogCore() {
    #expect(!PitlogCore.version.isEmpty)
}
