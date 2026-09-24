import SwiftUI

/// Dots showing how many digits have been typed, like the iPhone's own.
struct CodeDots: View {
    let count: Int
    var length: Int = FamilyLock.codeLength

    var body: some View {
        HStack(spacing: 22) {
            ForEach(0..<length, id: \.self) { index in
                ZStack {
                    Circle()
                        .strokeBorder(Palette.ink, lineWidth: 2)
                    if index < count {
                        Circle().fill(Palette.ink)
                    }
                }
                .frame(width: 20, height: 20)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) of \(length) digits entered"))
    }
}

/// A large number pad with round glass keys, like the iPhone's own.
struct CodePad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(row, id: \.self) { key in
                        keyView(key)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 78, height: 78)
        } else {
            Button {
                // Digits skip the tap gate so a code can be typed at normal speed.
                Haptics.tap()
                if key == "⌫" { onDelete() } else { onDigit(key) }
            } label: {
                Group {
                    if key == "⌫" {
                        Image(systemName: Symbols.deleteDigit)
                            .font(.system(size: 24, weight: .semibold))
                    } else {
                        Text(key)
                            .appFont(.largeButton)
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(width: 78, height: 78)
                .contentShape(Circle())
                .glassEffect(.regular, in: Circle())
                .overlay(Circle().strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder))
            }
            .buttonStyle(PressDimStyle())
            .accessibilityLabel(Text(key == "⌫" ? "Delete" : key))
        }
    }
}
