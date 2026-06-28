import SwiftUI
import CatscanAPI

/// Detail for a single flap event: the full snapshot plus its metadata.
struct FlapEventDetailView: View {
    let event: FlapEvent

    private var imageURL: URL? { AppEnvironment.imageURL(for: event.imagePath) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RemoteImageView(url: imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 240, maxHeight: 360)
                    .background(Color.black.opacity(imageURL == nil ? 0 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                metadataCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flap Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            detailRow("Date", value: event.timestamp.formatted(date: .complete, time: .omitted))
            Divider().padding(.leading, 16)
            detailRow("Time", value: event.timestamp.formatted(date: .omitted, time: .standard))
            Divider().padding(.leading, 16)
            detailRow("Captured", value: event.timestamp.formatted(.relative(presentation: .named)))
            Divider().padding(.leading, 16)
            detailRow("Snapshot", value: event.imagePath == nil ? "None" : "Available")
            Divider().padding(.leading, 16)
            detailRow("Event ID", value: shortID)
        }
        .cardStyle()
    }

    private func detailRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var shortID: String {
        event.id.count > 8 ? String(event.id.prefix(8)).uppercased() : event.id.uppercased()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FlapEventDetailView(
            event: FlapEvent(id: UUID().uuidString, timestamp: .now, imagePath: "/images/sample.jpg")
        )
    }
}
#endif
