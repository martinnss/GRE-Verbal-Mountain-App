import SwiftUI
import UniformTypeIdentifiers

// MARK: - Progression View

struct ProgressionView: View {
    @Bindable var viewModel: FlashcardViewModel
    @State private var includeUnlocked = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated starfield background
                StarfieldBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Overall progress card
                        overallProgressCard
                        
                        // Backup card
                        backupCard
                        
                        // Groups list
                        groupsProgressCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Backup", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Backup Card
    
    private var backupCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "4ADE80"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backup Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Export or import your learning data")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: exportProgress) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Export")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "4ADE80").opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: { showingImportSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Import")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Export/Import Functions
    
    private func exportProgress() {
        let progressData = viewModel.progressManager.exportProgress()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "GRE_Vocab_Backup_\(dateString).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(progressData)
            try data.write(to: tempURL)
            exportURL = tempURL
            showingExportSheet = true
        } catch {
            alertMessage = "Failed to export: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Unable to access the file"
                showAlert = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let progressData = try decoder.decode([ProgressExportData].self, from: data)
                
                viewModel.progressManager.importProgress(progressData)
                alertMessage = "Successfully imported \(progressData.count) words!"
                showAlert = true
            } catch {
                alertMessage = "Failed to import: \(error.localizedDescription)"
                showAlert = true
            }
            
        case .failure(let error):
            alertMessage = "Failed to import: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Overall Progress Card
    
    private var overallProgressCard: some View {
        let stats = viewModel.getOverallStatistics()
        let totalWithoutUnlocked = stats.easyNatural + stats.easyMastered + stats.medium + stats.hard
        let totalWithUnlocked = totalWithoutUnlocked + stats.unlocked
        
        let baseTotal = includeUnlocked ? totalWithUnlocked : totalWithoutUnlocked
        
        // Calculate percentages
        let easyNaturalPercent = baseTotal > 0 ? Double(stats.easyNatural) / Double(baseTotal) * 100 : 0
        let easyMasteredPercent = baseTotal > 0 ? Double(stats.easyMastered) / Double(baseTotal) * 100 : 0
        let mediumPercent = baseTotal > 0 ? Double(stats.medium) / Double(baseTotal) * 100 : 0
        let hardPercent = baseTotal > 0 ? Double(stats.hard) / Double(baseTotal) * 100 : 0
        let unlockedPercent = includeUnlocked && baseTotal > 0 ? Double(stats.unlocked) / Double(baseTotal) * 100 : 0
        
        return VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Progress")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(totalWithoutUnlocked) words studied")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            
            // Progress bar stack
            VStack(spacing: 16) {
                // Visual progress bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if easyNaturalPercent > 0 {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geo.size.width * easyNaturalPercent / 100)
                        }
                        if easyMasteredPercent > 0 {
                            Rectangle()
                                .fill(Color.mint)
                                .frame(width: geo.size.width * easyMasteredPercent / 100)
                        }
                        if mediumPercent > 0 {
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: geo.size.width * mediumPercent / 100)
                        }
                        if hardPercent > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geo.size.width * hardPercent / 100)
                        }
                        if includeUnlocked && unlockedPercent > 0 {
                            Rectangle()
                                .fill(Color(hex: "C4935A").opacity(0.7))
                                .frame(width: geo.size.width * unlockedPercent / 100)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 12)
                
                // Legend
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        ProgressLegendItem(color: .green, label: "Natural", percent: easyNaturalPercent)
                        ProgressLegendItem(color: .mint, label: "Mastered", percent: easyMasteredPercent)
                    }
                    HStack(spacing: 16) {
                        ProgressLegendItem(color: .orange, label: "Medium", percent: mediumPercent)
                        ProgressLegendItem(color: .red, label: "Hard", percent: hardPercent)
                    }
                    if includeUnlocked {
                        HStack(spacing: 16) {
                            ProgressLegendItem(color: Color(hex: "C4935A").opacity(0.7), label: "Backlog", percent: unlockedPercent)
                            Spacer()
                        }
                    }
                }
            }
            
            // Toggle for unlocked
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    includeUnlocked.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: includeUnlocked ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 14))
                    Text(includeUnlocked ? "Hide Backlog" : "Show Backlog (\(stats.unlocked) words)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(includeUnlocked ? Color(hex: "C4935A") : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Groups Progress Card
    
    private var groupsProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Groups", systemImage: "folder.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Tap to view words")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            // Groups list
            LazyVStack(spacing: 12) {
                ForEach(1...viewModel.repository.totalGroups, id: \.self) { groupNumber in
                    NavigationLink(destination: GroupWordsView(groupNumber: groupNumber, viewModel: viewModel)) {
                        GroupProgressRow(
                            groupNumber: groupNumber,
                            stats: viewModel.getGroupStatistics(for: groupNumber),
                            totalWords: viewModel.repository.words(forGroups: [groupNumber]).count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Progress Legend Item

struct ProgressLegendItem: View {
    let color: Color
    let label: String
    let percent: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Text(String(format: "%.0f%%", percent))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Group Progress Row

struct GroupProgressRow: View {
    let groupNumber: Int
    let stats: (easyNatural: Int, easyMastered: Int, medium: Int, hard: Int, unlocked: Int)
    let totalWords: Int
    
    private var totalEasy: Int {
        stats.easyNatural + stats.easyMastered
    }
    
    private var progressPercent: Double {
        guard totalWords > 0 else { return 0 }
        return Double(totalEasy) / Double(totalWords) * 100
    }
    
    private var progressColor: Color {
        if progressPercent >= 80 {
            return .green
        } else if progressPercent >= 50 {
            return .mint
        } else if progressPercent >= 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Group \(groupNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(totalEasy)/\(totalWords)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(String(format: "%.0f%%", progressPercent))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(progressColor)
                    .frame(width: 45, alignment: .trailing)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progressColor, progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressPercent / 100)
                }
            }
            .frame(height: 6)
            
            // Mini stats
            HStack(spacing: 12) {
                MiniStatBadge(count: stats.easyNatural, color: .green, icon: "checkmark.circle.fill")
                MiniStatBadge(count: stats.easyMastered, color: .mint, icon: "star.circle.fill")
                MiniStatBadge(count: stats.medium, color: .orange, icon: "flame.fill")
                MiniStatBadge(count: stats.hard, color: .red, icon: "bolt.fill")
                MiniStatBadge(count: stats.unlocked, color: Color(hex: "C4935A"), icon: "sparkles")
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Mini Stat Badge

struct MiniStatBadge: View {
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let repo = VocabRepository()
    let progress = ProgressManager()
    let viewModel = FlashcardViewModel(repository: repo, progressManager: progress)
    return ProgressionView(viewModel: viewModel)
}
