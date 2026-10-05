import SwiftUI

extension View {
    /// Multi-line text that never gets clipped: wraps, grows vertically and shrinks slightly only when a
    /// single (German compound) word is wider than the line at accessibility sizes.
    func wrapsLongWords() -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.6)
    }
}
