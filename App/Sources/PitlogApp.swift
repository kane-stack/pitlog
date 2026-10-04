import SwiftData
import SwiftUI

@main
struct PitlogApp: App {
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.entitlements, UnlimitedEntitlements())
        }
        .modelContainer(container)
    }

    @MainActor
    private static func makeContainer() -> ModelContainer {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        do {
            if arguments.contains("-UITestSampleData") {
                return PreviewData.container(withSamples: true)
            }
            // Unit tests host the app; keep CloudKit and the on-disk store out of it.
            if environment["XCTestConfigurationFilePath"] != nil {
                return PreviewData.container(withSamples: false)
            }
            do {
                return try ModelContainerFactory.production()
            } catch {
                // No CloudKit (e.g. unsigned build): keep working on a local store.
                return try ModelContainerFactory.localOnly()
            }
        } catch {
            fatalError("Could not create the model container: \(error)")
        }
    }
}
