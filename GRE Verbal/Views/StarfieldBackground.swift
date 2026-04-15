import SwiftUI

// MARK: - Starfield Background

struct StarfieldBackground: View {
    var body: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(hex: "05050F"),
                    Color(hex: "0A0A1A"),
                    Color(hex: "0F0F25")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Starfield
            StarfieldView()
                .ignoresSafeArea()
            
            // Subtle purple nebula glow (smaller)
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(x: -80, y: geo.size.height * 0.2)
                    .blur(radius: 40)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "4A0080").opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 150, y: geo.size.height * 0.6)
                    .blur(radius: 50)
            }
        }
    }
}

// MARK: - Starfield View

struct StarfieldView: View {
    @State private var stars: [Star] = Star.generateStars(count: 300)
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
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
    
    // Purple-tinted star colors
    var color: Color {
        switch colorIndex {
        case 0: return Color(hex: "F0E6FF") // Bright white-purple
        case 1: return Color(hex: "D4B8FF") // Soft lavender
        case 2: return Color(hex: "B57EFF") // Medium purple
        case 3: return Color(hex: "9945FF") // Vibrant purple
        default: return Color(hex: "7C3AED") // Deep purple
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
