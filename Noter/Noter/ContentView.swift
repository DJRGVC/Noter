    f//
//  ContentView.swift
//  Noter
//
//  Created by Daniel Grant on 10/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var storedName = ""
    @AppStorage("userEmail") private var storedEmail = ""

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                AccountSetupView(name: storedName, email: storedEmail) { name, email in
                    storedName = name
                    storedEmail = email
                    seedMockDataIfNeeded()
                    withAnimation(.smooth) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .glassBackgroundEffect()
        .animation(.smooth, value: hasCompletedOnboarding)
    }

    private func seedMockDataIfNeeded() {
        guard classes.isEmpty else { return }
        StudyClass.mockData(context: modelContext)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
}
