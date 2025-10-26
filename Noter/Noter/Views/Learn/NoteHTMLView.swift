import SwiftUI
import WebKit

struct NoteHTMLView: View {
    let lecture: Lecture
    @State private var htmlContent: String?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading notes...")
            } else if let html = htmlContent {
                WebView(htmlString: html)
            } else {
                // Fallback to plain text view
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !lecture.summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.headline)
                                
                                Text(lecture.summary)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                        }
                        
                        ForEach(lecture.notes) { note in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(note.content)
                                    .font(.body)
                                
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(lecture.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHTMLContent()
        }
    }
    
    private func loadHTMLContent() {
        Task {
            htmlContent = NoteLoaderService.shared.getHTMLContent(for: lecture)
            isLoading = false
        }
    }
}

struct WebView: UIViewRepresentable {
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

#Preview {
    NavigationStack {
        NoteHTMLView(lecture: Lecture(
            title: "Sample Lecture",
            summary: "This is a sample lecture",
            notes: [
                LectureNote(content: "Sample note content")
            ]
        ))
    }
}
