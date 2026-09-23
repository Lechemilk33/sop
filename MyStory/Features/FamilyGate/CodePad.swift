import SwiftUI

/// Four dots showing how many digits have been typed.
struct CodeDots: View {
    let count: Int
    var length: Int = FamilyLock.codeLength

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<length, id: \.self) { index in
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                ZStack {
                    shape.fill(Palette.card)
                    shape.strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder)
                    if index < count {
                        Circle()
                            .fill(Palette.ink)
                            .frame(width: 18, height: 18)
                    }
                }
                .frame(width: 60, height: 68)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) of \(length) digits entered"))
    }
}

/// A large number pad, like the phone's own.
struct CodePad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        keyView(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
        } else {
            Button {
                // Digits skip the tap gate so a code can be typed at normal speed.
                Haptics.tap()
                if key == "⌫" { onDelete() } else { onDigit(key) }
            } label: {
                Group {
                    if key == "⌫" {
                        Image(systemName: Symbols.deleteDigit)
                            .font(.system(size: 26, weight: .bold))
                    } else {
                        Text(key)
                            .appFont(.largeButton)
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget + 8)
                .background(shape.fill(Palette.card))
                .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder))
                .contentShape(shape)
            }
            .buttonStyle(PressDimStyle())
            .accessibilityLabel(Text(key == "⌫" ? "Delete" : key))
        }
    }
}
