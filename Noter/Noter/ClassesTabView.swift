import SwiftUI
import SwiftData

struct ClassesTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]
    @State private var showingAddClass = false
    @State private var classToEdit: StudyClass?

    var body: some View {
        NavigationStack {
            Group {
                if classes.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Classes")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddClass = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $classToEdit) { studyClass in
                ClassEditorView(mode: .edit(studyClass))
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingAddClass) {
                ClassEditorView(mode: .new)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var content: some View {
        Group {
            if horizontalSizeClass == .compact {
                List {
                    ForEach(classes) { studyClass in
                        NavigationLink(destination: ClassDetailView(studyClass: studyClass)) {
                            ClassCardView(studyClass: studyClass)
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(studyClass)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                classToEdit = studyClass
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        ForEach(classes) { studyClass in
                            NavigationLink(destination: ClassDetailView(studyClass: studyClass)) {
                                ClassCardView(studyClass: studyClass)
                            }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { classToEdit = studyClass }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(studyClass) }
                            }
                        }
                    }
                    .padding()
                }
                .background(GlassBackground())
            }
        }
        .background(GlassBackground())
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            Text("Start by adding your first class")
                .font(.title2.bold())
            Text("Import syllabi, drop in lecture audio, and we will generate structured notes for you.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showingAddClass = true
            } label: {
                Label("Add Class", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue.gradient, in: .capsule)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
        .background(GlassBackground())
    }

    private func delete(_ studyClass: StudyClass) {
        withAnimation {
            modelContext.delete(studyClass)
            do {
                try modelContext.save()
            } catch {
                assertionFailure("Failed to delete class: \(error)")
            }
        }
    }
}

private struct GlassBackground: View {
    var body: some View {
        LinearGradient(colors: [.blue.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .background(.ultraThinMaterial)
    }
}

struct ClassCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let studyClass: StudyClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(studyClass.courseCode)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(6)
                    .background(Color(hex: studyClass.colorHex).opacity(0.2), in: .capsule)
                Spacer()
                Text("\(studyClass.lectures.count) lectures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(studyClass.title)
                .font(.title3.bold())

            Text(studyClass.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack {
                Label(studyClass.instructor, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 180)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: studyClass.colorHex).opacity(colorScheme == .dark ? 0.4 : 0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
}

#Preview {
    ClassesTabView()
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
        .taskPreview {
            let context = $0.modelContext
            if (try? context.fetch(FetchDescriptor<StudyClass>()))?.isEmpty ?? true {
                StudyClass.mockData(context: context)
            }
        }
}
