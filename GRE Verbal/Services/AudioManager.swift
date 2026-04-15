import Foundation
import AVFoundation

// MARK: - Audio Manager with Offline Caching

@Observable
final class AudioManager: NSObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    var isPlaying = false
    var isLoading = false
    
    private override init() {
        // Create cache directory for audio files
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesPath.appendingPathComponent("AudioCache", isDirectory: true)
        
        super.init()
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure audio session for playback
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    // Get cached file URL for a word
    private func cachedFileURL(for urlString: String) -> URL {
        let filename = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return cacheDirectory.appendingPathComponent("\(filename).mp3")
    }
    
    // Check if audio is cached
    func isAudioCached(for urlString: String) -> Bool {
        let cachedURL = cachedFileURL(for: urlString)
        return fileManager.fileExists(atPath: cachedURL.path)
    }
    
    // Play pronunciation with offline-first approach
    func playPronunciation(from urlString: String) {
        guard !urlString.isEmpty else { return }
        
        let cachedURL = cachedFileURL(for: urlString)
        
        // Try cached version first
        if fileManager.fileExists(atPath: cachedURL.path) {
            playFromFile(cachedURL)
            return
        }
        
        // Download and cache, then play
        downloadAndPlay(from: urlString, cacheTo: cachedURL)
    }
    
    private func playFromFile(_ url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("❌ Failed to play audio from file: \(error)")
            isPlaying = false
        }
    }
    
    private func downloadAndPlay(from urlString: String, cacheTo cacheURL: URL) {
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                guard let self = self, let data = data, error == nil else {
                    print("❌ Failed to download audio: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Cache the audio file
                do {
                    try data.write(to: cacheURL)
                    print("✅ Cached audio to: \(cacheURL.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to cache audio: \(error)")
                }
                
                // Play from memory
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                    self.isPlaying = true
                } catch {
                    print("❌ Failed to play audio from data: \(error)")
                    self.isPlaying = false
                }
            }
        }.resume()
    }
    
    // Pre-cache audio for a list of words (background operation)
    func preCacheAudio(for words: [VocabWord]) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            for word in words {
                let urlString = word.pronunciation
                let cachedURL = self.cachedFileURL(for: urlString)
                
                // Skip if already cached
                if self.fileManager.fileExists(atPath: cachedURL.path) {
                    continue
                }
                
                // Download and cache
                guard let url = URL(string: urlString) else { continue }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    try data.write(to: cachedURL)
                } catch {
                    // Silently fail for background caching
                }
                
                // Small delay to avoid hammering the server
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // Get cache size
    var cacheSizeFormatted: String {
        var totalSize: Int64 = 0
        
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    // Clear cache
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
