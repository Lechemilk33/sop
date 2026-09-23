import Foundation

/// Builds the page in the saved copy that plays every story in any web
/// browser, with no app, account or internet. It is plain HTML and CSS
/// (no scripts), so it should keep working for decades.
enum ArchiveHTML {
    struct FontFace {
        let weight: Int
        let base64TrueType: String
    }

    static func render(
        _ manifest: ArchiveManifest,
        fontFaces: [FontFace] = [],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let owner = manifest.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = owner.isEmpty ? "My stories" : "\(Possessive.of(owner)) stories"
        let savedOn = DayText.long(manifest.createdAt, locale: locale, timeZone: calendar.timeZone)
        let storyCount = StoryCountText.text(manifest.storyCount).lowercased()
        let voiceOwner = owner.isEmpty ? "their" : Possessive.of(owner)
        let lede = "\(storyCount.capitalizedFirst) in \(voiceOwner) own voice, saved \(savedOn). "
            + "Everything is in this folder: the recordings, the words and the photos."
        let peopleHeading = owner.isEmpty ? "The people" : "\(Possessive.of(owner)) people"

        var html = """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        \(fontCSS(fontFaces))
        \(styles)
        </style>
        </head>
        <body>
        <main>
        <h1>\(escape(title))</h1>
        <p class="lede">\(escape(lede))</p>

        """

        if !manifest.people.isEmpty {
            html += "<h2><span class=\"dot blue\"></span>\(escape(peopleHeading))</h2>\n<div class=\"people\">\n"
            for person in manifest.people {
                html += "<section class=\"card person\">\n"
                if let photo = person.photoPath {
                    html += "<img src=\"\(url(photo))\" alt=\"\(escape(person.name))\">\n"
                }
                html += "<h3>\(escape(person.name))</h3>\n"
                if !person.relationship.isEmpty {
                    html += "<p class=\"rel\">\(escape(person.relationship))</p>\n"
                }
                if !person.facts.isEmpty {
                    html += "<ul>" + person.facts.map { "<li>\(escape($0))</li>" }.joined() + "</ul>\n"
                }
                if let hello = person.helloPath {
                    html += "<p class=\"meta\">A hello from \(escape(person.name))</p>\n<audio controls preload=\"none\" src=\"\(url(hello))\"></audio>\n"
                }
                html += "</section>\n"
            }
            html += "</div>\n"
        }

        for chapter in manifest.chapters where !chapter.stories.isEmpty {
            html += "<h2><span class=\"dot gold\"></span>\(escape(chapter.name))</h2>\n"
            for story in chapter.stories {
                html += "<article class=\"card story\">\n<h3>\(escape(story.title))</h3>\n"
                var meta = "Told " + DayText.long(story.recordedAt, locale: locale, timeZone: calendar.timeZone)
                meta += " \u{00B7} " + DurationText.spoken(story.durationSeconds)
                if !story.people.isEmpty {
                    meta += " \u{00B7} With " + story.people.joined(separator: ", ")
                }
                html += "<p class=\"meta\">\(escape(meta))</p>\n"
                if !story.prompt.isEmpty, story.prompt != story.title {
                    html += "<p class=\"prompt\">\u{201C}\(escape(story.prompt))\u{201D}</p>\n"
                }
                if let photo = story.photoPath {
                    html += "<img class=\"story-photo\" src=\"\(url(photo))\" alt=\"\">\n"
                }
                if let audio = story.audioPath {
                    html += "<audio controls preload=\"none\" src=\"\(url(audio))\"></audio>\n"
                }
                if !story.transcript.isEmpty {
                    html += "<details><summary>Read the words</summary><p class=\"words\">\(escape(story.transcript))</p></details>\n"
                }
                html += "</article>\n"
            }
        }

        if !manifest.photos.isEmpty {
            html += "<h2><span class=\"dot brick\"></span>Photos</h2>\n<div class=\"photos\">\n"
            for photo in manifest.photos {
                html += "<figure class=\"card photo\"><img src=\"\(url(photo.path))\" alt=\"\(escape(photo.caption))\">"
                var caption = photo.caption
                if !photo.people.isEmpty {
                    caption += (caption.isEmpty ? "" : " \u{00B7} ") + photo.people.joined(separator: ", ")
                }
                if let year = photo.year {
                    caption += (caption.isEmpty ? "" : " \u{00B7} ") + String(year)
                }
                if !caption.isEmpty {
                    html += "<figcaption>\(escape(caption))</figcaption>"
                }
                html += "</figure>\n"
            }
            html += "</div>\n"
        }

        if !manifest.questions.isEmpty {
            html += "<h2><span class=\"dot green\"></span>Questions from the family</h2>\n"
            for question in manifest.questions {
                html += "<section class=\"card question\">\n<p class=\"ask\">\u{201C}\(escape(question.text))\u{201D}</p>\n"
                if let asker = question.askedBy, !asker.isEmpty {
                    html += "<p class=\"meta\">Asked by \(escape(asker))</p>\n"
                }
                if let photo = question.photoPath {
                    html += "<img class=\"story-photo\" src=\"\(url(photo))\" alt=\"\">\n"
                }
                if let audio = question.audioPath {
                    html += "<audio controls preload=\"none\" src=\"\(url(audio))\"></audio>\n"
                }
                html += "</section>\n"
            }
        }

        html += """
        <footer>Made with My Story. Every recording is also in the Stories folder as its own file, with the words in a text file beside it.</footer>
        </main>
        </body>
        </html>

        """
        return html
    }

    /// Escapes text for use in HTML content and attributes.
    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    /// A relative path, percent-encoded and HTML-escaped for a `src` attribute.
    static func url(_ relativePath: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?#&;=+'")
        let encoded = relativePath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0) }
            .joined(separator: "/")
        return escape(encoded)
    }

    private static func fontCSS(_ faces: [FontFace]) -> String {
        faces.map { face in
            "@font-face{font-family:'Atkinson Hyperlegible Next';font-weight:\(face.weight);font-style:normal;src:url(data:font/ttf;base64,\(face.base64TrueType)) format('truetype');}"
        }.joined(separator: "\n")
    }

    private static let styles = """
    :root{--paper:#FBF5EA;--ink:#26190F;--soft:#574636;--hair:#DCCBB0;--brick:#9F3118;--blue:#122F5C;--green:#276336;--gold:#F2B535;--goldrim:#7A5410}
    *{box-sizing:border-box}
    body{margin:0;background:var(--paper);color:var(--ink);font-family:'Atkinson Hyperlegible Next',-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:20px;line-height:1.5}
    main{max-width:880px;margin:0 auto;padding:36px 20px 80px}
    h1{font-size:42px;line-height:1.15;margin:0 0 10px}
    h2{font-size:30px;line-height:1.2;margin:52px 0 18px;display:flex;align-items:center;gap:12px}
    h3{font-size:25px;line-height:1.25;margin:0 0 6px}
    .lede{color:var(--soft);margin:0 0 12px}
    .dot{width:18px;height:18px;border-radius:50%;flex:none}
    .dot.gold{background:var(--gold);border:3px solid var(--goldrim)}
    .dot.blue{background:var(--blue)}
    .dot.brick{background:var(--brick)}
    .dot.green{background:var(--green)}
    .card{background:#fff;border:2px solid var(--hair);border-radius:22px;padding:18px}
    .people{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:16px}
    .person img{width:100%;aspect-ratio:1/1;object-fit:cover;border-radius:16px;background:#EADCC6;margin-bottom:10px}
    .person ul{margin:8px 0 12px;padding-left:22px}
    .rel{color:var(--soft);font-weight:700;margin:0}
    .story,.question{margin:0 0 16px}
    .ask{font-size:23px;font-weight:700;margin:0 0 6px}
    .meta{color:var(--soft);font-size:17px;margin:0 0 12px}
    .prompt{font-style:normal;color:var(--soft);margin:0 0 12px}
    .story-photo{width:100%;max-height:420px;object-fit:cover;border-radius:16px;margin:0 0 12px}
    audio{width:100%}
    details{margin-top:14px}
    summary{cursor:pointer;font-weight:700}
    .words{white-space:pre-wrap;margin:10px 0 0}
    .photos{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:16px}
    .photo{margin:0}
    .photo img{width:100%;border-radius:14px;display:block}
    figcaption{color:var(--soft);font-size:17px;margin-top:8px}
    footer{margin-top:64px;color:var(--soft);font-size:16px}
    """
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
