import SwiftUI
import FamilyControls

struct ScreenTimeSettingsView: View {

    @State private var manager = ScreenTimeManager.shared
    @State private var showingPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060D07").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        authorizationSection
                        if manager.isAuthorized {
                            blockedAppsSection
                            statusSection
                        }
                        if manager.isAuthorized && manager.hasAppSelection {
                            dangerSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("App Blocker")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .familyActivityPicker(isPresented: $showingPicker, selection: $pickerSelection)
            .onChange(of: showingPicker) { _, isShowing in
                if !isShowing {
                    manager.saveSelection(pickerSelection)
                }
            }
            .onAppear {
                manager.refreshState()
                pickerSelection = manager.currentSelection
            }
            .alert("Reset App Blocker?", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) { manager.resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all blocked apps and stop the blocking schedule.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "4ADE80"))

            Text("Study Before Scrolling")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Block distracting apps until you complete your GRE verbal practice. After finishing, you get \(ScreenTimeConstants.sessionMinutes) minutes of access.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Time Permission", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(.white)

            if manager.isAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "4ADE80"))
                    Text("Authorized")
                        .foregroundStyle(Color(hex: "4ADE80"))
                        .font(.subheadline)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let error = manager.authorizationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    } else {
                        Text("GRE Verbal needs Screen Time permission to block distracting apps.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Button(action: {
                        Task { await manager.requestAuthorization() }
                    }) {
                        Label("Grant Permission", systemImage: "lock.shield")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "4ADE80"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Blocked Apps Section

    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Blocked Apps", systemImage: "apps.iphone.badge.plus")
                .font(.headline)
                .foregroundStyle(.white)

            if manager.hasAppSelection {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "4ADE80"))
                    Text("Apps selected")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.subheadline)
                    Spacer()
                    Button("Change") {
                        pickerSelection = manager.currentSelection
                        showingPicker = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "4ADE80"))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose apps like YouTube, Instagram, and TikTok to block until you complete practice.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    Button(action: { showingPicker = true }) {
                        Label("Select Apps to Block", systemImage: "plus.app")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "4ADE80"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Status", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.white)

            if manager.isSessionActive {
                sessionActiveRow
            } else if manager.hasAppSelection {
                blockedRow
            } else {
                notConfiguredRow
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionActiveRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Session Active")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("\(manager.minutesRemainingInSession) min remaining")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var blockedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.title2)
                .foregroundStyle(.red.opacity(0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Apps Blocked")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("Complete practice to unlock for \(ScreenTimeConstants.sessionMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var notConfiguredRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text("Select apps to start blocking")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showingResetAlert = true }) {
                Label("Reset All Settings", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ScreenTimeSettingsView()
        .preferredColorScheme(.dark)
}
