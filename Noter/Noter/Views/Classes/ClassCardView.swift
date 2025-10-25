import SwiftUI

struct ClassCardView: View {
    var studyClass: StudyClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(studyClass.title)
                    .font(.title3.bold())
                Spacer()
                if !studyClass.instructor.isEmpty {
                    Label(studyClass.instructor, systemImage: "person.fill")
                        .font(.footnote)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
            }

            Text(studyClass.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Divider()
                .blendMode(.overlay)

            HStack {
                Label {
                    if let date = studyClass.sortedLectures.first?.date {
                        Text(date, style: .date)
                    } else {
                        Text("No lectures")
                    }
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer()
                Text(studyClass.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    ClassCardView(studyClass: StudyClass.mockClasses().first!)
        .padding()
        .background(.black.opacity(0.1))
}
