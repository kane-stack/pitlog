import Testing

@testable import Pitlog

struct SoftHyphenTests {
    @Test func removesEverySoftHyphen() {
        #expect("Be\u{00AD}gut\u{00AD}ach\u{00AD}tungs\u{00AD}fens\u{00AD}ter".withoutSoftHyphens == "Begutachtungsfenster")
    }

    @Test func leavesPlainTextAlone() {
        #expect("Servicenachweis – ohne Gewähr".withoutSoftHyphens == "Servicenachweis – ohne Gewähr")
    }

    @Test func removesHyphensOnlyFromTheirOwnCharacter() {
        // A normal hyphen is part of the text and stays.
        #expect("Pickerl-Er\u{00AD}in\u{00AD}ne\u{00AD}rung".withoutSoftHyphens == "Pickerl-Erinnerung")
    }
}
