import SwiftUI

/// A big box to type in, for naming a story or a chapter, with an example
/// above it in clear dark text (the iPhone's own grey hint is too faint).
/// The keyboard's microphone key, where dictation is on, lets him say the
/// words instead of typing them.
struct TextEntryField: View {
    /// Shown above the box, like "For example: The summer at the lake".
    let example: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            Text(example)
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField(
                "Type here",
                text: $text,
                prompt: Text("Type here").foregroundStyle(Palette.softInk),
                axis: .vertical
            )
            .appFont(.field)
            .foregroundStyle(Palette.ink)
            .lineLimit(1...4)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused(isFocused)
            .accessibilityHint(Text(example))
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
}

/// A short note under a box he types in. It only mentions the keyboard's
/// microphone as a maybe, because dictation can be turned off.
struct TypingTip: View {
    var body: some View {
        Text("If the keyboard has a microphone key, you can tap it and say the words instead of typing.")
            .appFont(.caption)
            .foregroundStyle(Palette.softInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
