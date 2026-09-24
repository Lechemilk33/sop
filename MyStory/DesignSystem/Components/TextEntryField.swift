import SwiftUI

/// A big box to type in, for naming a story or a chapter. The keyboard's
/// microphone key lets him say the words instead of typing them.
struct TextEntryField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
        TextField(placeholder, text: $text, axis: .vertical)
            .appFont(.field)
            .foregroundStyle(Palette.ink)
            .lineLimit(1...4)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused(isFocused)
            .onChange(of: text) { _, newValue in
                // Return means "done" here, not a new line.
                if newValue.contains("\n") {
                    text = newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    isFocused.wrappedValue = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(shape.fill(Palette.card))
            .overlay(
                shape.strokeBorder(
                    isFocused.wrappedValue || contrast == .increased ? Palette.ink : Palette.edge,
                    lineWidth: isFocused.wrappedValue ? Metrics.increasedContrastBorder : Metrics.tappableBorder
                )
            )
            .contentShape(shape)
            // Tapping anywhere in the box, not just on the words, starts typing.
            .simultaneousGesture(TapGesture().onEnded { isFocused.wrappedValue = true })
    }
}
