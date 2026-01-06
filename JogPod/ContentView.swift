import SwiftUI
import SwiftData

/// Main content view for the JogPod application.
///
/// This view serves as the root view and will be expanded to include
/// the full workout and podcast management interface.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("JogPod")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Podcast-Enhanced Workouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("JogPod")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JogPodSchema.models, inMemory: true)
}
