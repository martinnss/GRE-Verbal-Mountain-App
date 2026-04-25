import SwiftUI

// MARK: - Starfield Background

struct StarfieldBackground: View {
    var showAnimatedStars: Bool = true
    var starCount: Int = 180
    var frameRate: Double = 30

    var body: some View {
        ZStack {
            // Base dark gradient — very dark forest green-black
            LinearGradient(
                colors: [
                    Color(hex: "030806"),
                    Color(hex: "060D07"),
                    Color(hex: "080F09")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Starfield
            if showAnimatedStars {
                StarfieldView(starCount: starCount, frameRate: frameRate)
                    .ignoresSafeArea()
            }
            
            // Green nebula glow (top-left)
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "0A3D1A").opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .offset(x: -90, y: geo.size.height * 0.18)
                    .blur(radius: 45)
                
                // Bronze nebula glow (bottom-right)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "3D1F0A").opacity(0.28), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .offset(x: geo.size.width - 140, y: geo.size.height * 0.58)
                    .blur(radius: 55)
            }
        }
    }
}

// MARK: - Starfield View

struct StarfieldView: View {
    let frameRate: Double
    @State private var stars: [Star]

    init(starCount: Int = 180, frameRate: Double = 30) {
        self.frameRate = frameRate
        _stars = State(initialValue: Star.generateStars(count: starCount))
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / max(1.0, frameRate))) { timeline in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for star in stars {
                    let position = star.position(at: time, in: size)
                    let opacity = star.twinkleOpacity(at: time)
                    let pulseSize = star.size * (1.0 + sin(time * star.twinkleSpeed + star.twinklePhase) * 0.2)
                    
                    // Draw glow (subtle)
                    let glowRect = CGRect(
                        x: position.x - pulseSize,
                        y: position.y - pulseSize,
                        width: pulseSize * 2,
                        height: pulseSize * 2
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(star.color.opacity(opacity * 0.15))
                    )
                    
                    // Draw star core
                    let starRect = CGRect(
                        x: position.x - pulseSize / 2,
                        y: position.y - pulseSize / 2,
                        width: pulseSize,
                        height: pulseSize
                    )
                    context.fill(
                        Path(ellipseIn: starRect),
                        with: .color(star.color.opacity(opacity * 0.6))
                    )
                }
            }
        }
    }
}

// MARK: - Star Model

struct Star: Identifiable {
    let id = UUID()
    let baseX: CGFloat
    let baseY: CGFloat
    let size: CGFloat
    let speedX: CGFloat  // Horizontal speed (pixels per second)
    let speedY: CGFloat  // Vertical speed (pixels per second)
    let twinkleSpeed: Double
    let twinklePhase: Double
    let colorIndex: Int
    
    // Green-tinted star colors with occasional bronze accent
    var color: Color {
        switch colorIndex {
        case 0: return Color(hex: "E8FAF0") // Bright white-green
        case 1: return Color(hex: "A8E6BA") // Soft green
        case 2: return Color(hex: "4ADE80") // Vivid emerald
        case 3: return Color(hex: "22C55E") // Medium green
        default: return Color(hex: "C4935A") // Bronze accent
        }
    }
    
    func position(at time: TimeInterval, in size: CGSize) -> CGPoint {
        // Linear movement across screen
        let travelX = time * Double(speedX)
        let travelY = time * Double(speedY)
        
        // Calculate position with wrapping
        var x = (baseX * size.width + CGFloat(travelX)).truncatingRemainder(dividingBy: size.width)
        var y = (baseY * size.height + CGFloat(travelY)).truncatingRemainder(dividingBy: size.height)
        
        // Handle negative wrapping
        if x < 0 { x += size.width }
        if y < 0 { y += size.height }
        
        return CGPoint(x: x, y: y)
    }
    
    func twinkleOpacity(at time: TimeInterval) -> Double {
        // Pulsing glow effect
        let pulse = sin(time * twinkleSpeed + twinklePhase)
        return 0.5 + pulse * 0.5 // Range: 0.0 to 1.0
    }
    
    // Generate stars with random properties
    static func generateStars(count: Int) -> [Star] {
        (0..<count).map { _ in
            let isBright = Double.random(in: 0...1) < 0.12
            // Random direction and speed for each star
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 3...15) // pixels per second
            
            return Star(
                baseX: CGFloat.random(in: 0...1),
                baseY: CGFloat.random(in: 0...1),
                size: isBright ? CGFloat.random(in: 2.5...4) : CGFloat.random(in: 1...2),
                speedX: cos(angle) * speed,
                speedY: sin(angle) * speed,
                twinkleSpeed: Double.random(in: 0.3...1.2),
                twinklePhase: Double.random(in: 0...(.pi * 2)),
                colorIndex: Int.random(in: 0...4)
            )
        }
    }
}

#Preview {
    StarfieldBackground()
}
