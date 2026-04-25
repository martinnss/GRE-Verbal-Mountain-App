//
//  ContentView.swift
//  GRE Verbal
//
//  Created by Martin Olivares on 23-01-26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FlashcardViewModel?
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let vm = viewModel {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: vm)
                        .tabItem {
                            Label("Practice", systemImage: "rectangle.stack.fill")
                        }
                        .tag(0)

                    ProgressionView(viewModel: vm)
                        .tabItem {
                            Label("Progress", systemImage: "chart.bar.fill")
                        }
                        .tag(1)

                    DrillSetupView()
                        .tabItem {
                            Label("Timer", systemImage: "timer")
                        }
                        .tag(2)
                }
                .tint(Color(hex: "4ADE80"))
            } else {
                errorView
            }
        }
        .onAppear {
            setupViewModel()
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.refreshOnLaunch(
                todayCompleted: StreakManager.shared.todayCompleted
            )
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color(hex: "060D07")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(hex: "4ADE80"))
                Text("Loading vocabulary...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    private var errorView: some View {
        ZStack {
            Color(hex: "060D07")
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Failed to load vocabulary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("Retry") {
                    setupViewModel()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "4ADE80"))
            }
        }
    }
    
    private func setupViewModel() {
        isLoading = true
        
        let repository = VocabRepository()
        let progressManager = ProgressManager()
        progressManager.configure(with: modelContext)
        
        if repository.isLoaded {
            viewModel = FlashcardViewModel(
                repository: repository,
                progressManager: progressManager
            )
            isLoading = false
        } else {
            // Retry after a short delay if not loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if repository.isLoaded {
                    viewModel = FlashcardViewModel(
                        repository: repository,
                        progressManager: progressManager
                    )
                }
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WordProgress.self, AppSettings.self, DrillSession.self], inMemory: true)
}
