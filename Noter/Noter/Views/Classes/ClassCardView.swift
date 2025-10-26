import SwiftUI

struct ClassCardView: View {
    var studyClass: StudyClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(studyClass.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer(minLength: 16)

                if !studyClass.instructor.isEmpty {
                    Label(studyClass.instructor, systemImage: "person.fill")
                        .font(.footnote)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )
                }
            }

            Text(studyClass.details.isEmpty ? "No description yet." : studyClass.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(height: 1.2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.3))
                        .blur(radius: 2)
                )
                .padding(.vertical, 4)

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
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground).opacity(0.85),
                                Color(.systemBackground).opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.35), Color.clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .offset(x: 80, y: -60)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.28), Color.clear],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .offset(x: -90, y: 100)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.35),
                                    Color.purple.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                        .blendMode(.softLight)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        .shadow(color: Color.blue.opacity(0.12), radius: 28, x: 0, y: 18)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    ClassCardView(studyClass: StudyClass.mockClasses().first!)
        .padding()
        .background(.black.opacity(0.1))
}
