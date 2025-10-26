import SwiftUI

struct ClassCardView: View {
    var studyClass: StudyClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(studyClass.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                if !studyClass.instructor.isEmpty {
                    Text(studyClass.instructor)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(studyClass.details.isEmpty ? "No description yet." : studyClass.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Divider()
                .opacity(0.3)

            HStack(spacing: 12) {
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
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    ClassCardView(studyClass: StudyClass.mockClasses().first!)
        .padding()
        .background(.black.opacity(0.1))
}
