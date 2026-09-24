import SwiftData
import SwiftUI

/// Family questions first, then every built-in question with a switch to
/// stop asking it (for example, a topic that is painful right now).
struct FamilyQuestionsView: View {
    @Environment(\.modelContext) private var context
    // Photo questions are looked after in Photos, not here.
    @Query(filter: #Predicate<Question> { $0.isBuiltIn == false && $0.photo == nil }, sort: \Question.createdAt, order: .reverse)
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
            } header: {
                Text("Your questions")
            } footer: {
                if !familyQuestions.isEmpty {
                    Text("To remove a question, open it and tap Delete. Stories already told for it are kept.")
                }
            }

            Section {
                ForEach(chapters) { chapter in
                    let builtIn = (chapter.questions ?? [])
                        .filter(\.isBuiltIn)
                        .sorted { (QuestionBank.position[$0.key] ?? .max) < (QuestionBank.position[$1.key] ?? .max) }
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
        if question.answerCount > 0 {
            parts.append("Answered")
        } else {
            parts.append(question.timesShown > 0 ? "Asked, no story yet" : "Not asked yet")
        }
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
}
