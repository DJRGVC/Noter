import SwiftUI
import SwiftData

struct ClassesHome: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]
    @State private var isPresentingAddClass = false
    @State private var classToEdit: StudyClass?

    var body: some View {
        NavigationStack {
            Group {
                if classes.isEmpty {
                    emptyState
                } else if sizeClass == .compact {
                    classList
                } else {
                    classGrid
                }
            }
            .navigationTitle("Classes")
            .toolbar { toolbarContent }
            .background(.thinMaterial)
        }
        .sheet(isPresented: $isPresentingAddClass) {
            NavigationStack {
                ClassFormView(mode: .create) { newClass in
                    modelContext.insert(newClass)
                    try? modelContext.save()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $classToEdit) { studyClass in
            NavigationStack {
                ClassFormView(mode: .edit(studyClass)) { _ in
                    try? modelContext.save()
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var classList: some View {
        List {
            ForEach(classes) { studyClass in
                NavigationLink(destination: ClassDetailView(studyClass: studyClass)) {
                    ClassCardView(studyClass: studyClass)
                }
                .listRowBackground(.ultraThinMaterial)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(studyClass)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        classToEdit = studyClass
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var classGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                ForEach(classes) { studyClass in
                    NavigationLink(destination: ClassDetailView(studyClass: studyClass)) {
                        ClassCardView(studyClass: studyClass)
                            .glassBackgroundEffect()
                    }
                    .contextMenu {
                        Button("Edit") { classToEdit = studyClass }
                        Button(role: .destructive) { delete(studyClass) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .padding()
        }
        .background(.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.primary, .blue)
            Text("Organize your classes")
                .font(.title.bold())
            Text("Add a class to begin capturing lectures, notes, and AI-generated study material.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: { isPresentingAddClass = true }) {
                Label("Create your first class", systemImage: "plus")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPresentingAddClass = true
            } label: {
                Label("New Class", systemImage: "plus")
            }
        }
    }

    private func delete(_ studyClass: StudyClass) {
        withAnimation(.easeInOut) {
            modelContext.delete(studyClass)
            try? modelContext.save()
        }
    }
}

#Preview {
    ClassesHome()
        .modelContainer(PreviewContainer.container)
}
