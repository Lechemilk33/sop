import SwiftUI
import UIKit

/// A photo waiting to be framed, with where the framing started.
struct FramingSession: Identifiable {
    let id = UUID()
    let image: UIImage
    /// Where the square starts.
    let framing: PortraitFraming
    /// Around the faces, for "Start again".
    let automatic: PortraitFraming
}

/// Move and zoom a photo so the person's face fills the square he'll see in
/// My people. This is for the family, so it uses drag and pinch like the
/// iPhone's own photo tools, with buttons as well.
struct PhotoFramingView: View {
    let session: FramingSession
    let onDone: (PortraitFraming) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var framing: PortraitFraming
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    init(session: FramingSession, onDone: @escaping (PortraitFraming) -> Void) {
        self.session = session
        self.onDone = onDone
        _framing = State(initialValue: session.framing)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Drag and pinch so their face fills the square. This is how they'll look in My people.")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    let live = framing.zoomed(by: pinch).panned(by: dragTranslation, viewSide: side)
                    let placement = live.placement(viewSide: side)
                    Image(uiImage: session.image)
                        .resizable()
                        .frame(width: placement.size.width, height: placement.size.height)
                        .offset(x: placement.origin.x, y: placement.origin.y)
                        .frame(width: side, height: side, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder)
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousGesture(
                                DragGesture().updating($dragTranslation) { value, state, _ in
                                    state = value.translation
                                },
                                MagnifyGesture().updating($pinch) { value, state, _ in
                                    state = value.magnification
                                }
                            )
                            .onEnded { value in
                                let translation = value.first?.translation ?? .zero
                                let magnification = value.second?.magnification ?? 1
                                framing = framing.zoomed(by: magnification).panned(by: translation, viewSide: side)
                            }
                        )
                        .accessibilityLabel("The photo, framed")
                }
                .aspectRatio(1, contentMode: .fit)

                HStack(spacing: 12) {
                    Button {
                        framing = framing.zoomed(by: 0.8)
                    } label: {
                        Label("Zoom out", systemImage: "minus.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Button {
                        framing = framing.zoomed(by: 1.25)
                    } label: {
                        Label("Zoom in", systemImage: "plus.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.bordered)

                Button("Start again") {
                    framing = session.automatic
                }
                .frame(minHeight: 44)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Move and Zoom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        onDone(framing)
                        dismiss()
                    }
                }
            }
        }
    }
}
