import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isActive = false

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var angle: Double
        var scale: CGFloat
        var color: Color
        var velocity: CGFloat
        var rotationSpeed: Double
    }

    private let colors: [Color] = [.accentIndigo, .accentPink, .accentPurple, .accentGreen, .accentOrange]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Rectangle()
                        .fill(p.color)
                        .frame(width: 8, height: 8)
                        .rotationEffect(.degrees(p.angle))
                        .scaleEffect(p.scale)
                        .position(x: p.x, y: p.y)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { triggerConfetti() }
    }

    private func triggerConfetti() {
        particles = (0..<80).map { _ in
            ConfettiParticle(
                x: .random(in: 0...400),
                y: -20,
                angle: .random(in: 0...360),
                scale: .random(in: 0.5...1.5),
                color: colors.randomElement()!,
                velocity: .random(in: 200...600),
                rotationSpeed: .random(in: 90...360)
            )
        }

        withAnimation(.easeOut(duration: 2)) {
            particles = particles.map { p in
                var updated = p
                updated.y = 800 + .random(in: 0...200)
                updated.angle = p.angle + .random(in: 180...540)
                return updated
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            particles = []
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        ConfettiView()
        Text("Confetti!").font(.displayLarge).foregroundStyle(Color.textPrimary)
    }
}
