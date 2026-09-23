import SwiftData
import SwiftUI

/// Family questions first, then every built-in question with a switch to
/// stop asking it (for example, a topic that is painful right now).
struct FamilyQuestionsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Question> { $0.isBuiltIn == false }, sort: \Question.createdAt, order: .reverse)
    private var familyQuestions: [Question]
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    QuestionEditorView(question: nil)
                } label: {
                    FamilyMenuRow(title: "Add a question", systemImage: "plus.bubble")
                }
            }

            Section {
                if familyQuestions.isEmpty {
                    Text("Questions you add are asked before the built-in ones.")
                        .foregroundStyle(Palette.softInk)
                }
                ForEach(familyQuestions) { question in
                    NavigationLink {
                        QuestionEditorView(question: question)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question.photo != nil && question.text.isEmpty ? "Tell me about this photo." : question.text)
                                .font(.body.weight(.semibold))
                            Text(detail(for: question))
                                .font(.footnote)
                                .foregroundStyle(Palette.softInk)
                        }
                    }
                }
                .onDelete(perform: deleteFamilyQuestions)
            } header: {
                Text("Your questions")
            }

            Section {
                ForEach(chapters) { chapter in
                    let builtIn = (chapter.questions ?? [])
                        .filter(\.isBuiltIn)
                        .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
                    if !builtIn.isEmpty {
                        DisclosureGroup("\(chapter.name) (\(builtIn.filter { !$0.isHidden }.count) of \(builtIn.count))") {
                            ForEach(builtIn) { question in
                                Toggle(isOn: askBinding(for: question)) {
                                    Text(question.text)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Built-in questions")
            } footer: {
                Text("Switch off any question you'd rather he wasn't asked.")
            }
        }
        .familyBackground()
        .navigationTitle("Questions")
    }

    private func detail(for question: Question) -> String {
        var parts: [String] = []
        if let name = question.askedBy?.name { parts.append("From \(name)") }
        if let chapter = question.chapter?.name { parts.append(chapter) }
        parts.append(question.answerCount > 0 ? "Answered" : "Not asked yet")
        if question.recordedAudio != nil { parts.append("In your voice") }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func askBinding(for question: Question) -> Binding<Bool> {
        Binding(
            get: { !question.isHidden },
            set: { newValue in
                question.isHidden = !newValue
                try? context.save()
            }
        )
    }

    private func deleteFamilyQuestions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(familyQuestions[index])
        }
        try? context.save()
    }
}
