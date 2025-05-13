import SwiftUI

struct AdminBookDetailView: View {
    let book: AdminBook
    @AppStorage("isDarkMode") private var isDarkMode = false
    private let customAccentColor = Color(red: 0.12, green: 0.45, blue: 0.65)

    var body: some View {
        ZStack {
            // Particle Background
            ParticleBackgroundView(accentColor: customAccentColor)
                .opacity(0.2) // Lowered opacity for subtlety

            VStack(spacing: 20) { // Reduced spacing
                // Book Cover
                ZStack {
                    AsyncImage(url: URL(string: book.coverImageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 220, height: 320)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(customAccentColor.opacity(0.8), lineWidth: 2)
                                        .glow(color: customAccentColor.opacity(0.3), radius: 8)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        case .failure:
                            Image(systemName: "book.closed.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 320)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [customAccentColor, customAccentColor.opacity(0.7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(customAccentColor.opacity(0.8), lineWidth: 2)
                                        .glow(color: customAccentColor.opacity(0.3), radius: 8)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .padding(.top, 8)

                // Title
                TypewriterTextView(text: book.title.isEmpty ? "Unknown Title" : book.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded)) // Smaller font
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [customAccentColor, .primary]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: 80) // Constrain title height

                // Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AnimatedBookDetailRow(
                        icon: "books.vertical.fill",
                        label: "Available",
                        value: "\(book.availableCopies)",
                        accentColor: customAccentColor
                    )
                    AnimatedBookDetailRow(
                        icon: "books.vertical",
                        label: "Total",
                        value: "\(book.totalCopies)",
                        accentColor: customAccentColor
                    )
                    AnimatedBookDetailRow(
                        icon: "person.fill",
                        label: "Borrowed",
                        value: "\(book.borrowedCopies)",
                        accentColor: customAccentColor
                    )
                    AnimatedBookDetailRow(
                        icon: "calendar.badge.plus",
                        label: "Added On",
                        value: formattedCreatedDate(),
                        accentColor: customAccentColor
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor.secondarySystemBackground),
                                    Color(UIColor.systemBackground).opacity(0.9)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: customAccentColor.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 16)

                Spacer() // Flexible spacer to push content up
            }
            .padding(.vertical, 20) // Reduced padding
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private func formattedCreatedDate() -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a zzz"
        inputFormatter.timeZone = TimeZone(identifier: "UTC+05:30")

        if let date = inputFormatter.date(from: book.createdDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        return book.createdDate
    }
}

struct AnimatedBookDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let accentColor: Color
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .font(.system(size: 18)) // Smaller icon
                .frame(width: 24)
                .scaleEffect(isHovered ? 1.1 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded)) // Smaller font
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [accentColor, .primary]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground).opacity(0.8))
                .shadow(color: accentColor.opacity(isHovered ? 0.2 : 0.1), radius: 3, x: 0, y: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct TypewriterTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                startTypewriterEffect()
            }
    }

    private func startTypewriterEffect() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

struct ParticleBackgroundView: View {
    let accentColor: Color
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .animation(.easeInOut(duration: particle.duration), value: particle.position)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<15).map { _ in // Fewer particles
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height)),
                size: CGFloat.random(in: 3...6),
                color: accentColor.opacity(Double.random(in: 0.2...0.4)),
                opacity: Double.random(in: 0.2...0.6),
                duration: Double.random(in: 4...7)
            )
        }
        for i in particles.indices {
            withAnimation(.easeInOut(duration: particles[i].duration).repeatForever(autoreverses: true)) {
                particles[i].position.y += CGFloat.random(in: -40...40)
                particles[i].position.x += CGFloat.random(in: -40...40)
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let color: Color
    var opacity: Double
    let duration: Double
}

struct Glow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .blur(radius: radius)
                    .mask(content)
                    .foregroundColor(color)
            )
    }
}

extension View {
    func glow(color: Color, radius: CGFloat) -> some View {
        self.modifier(Glow(color: color, radius: radius))
    }
}

struct AdminBookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AdminBookDetailView(book: AdminBook(
            id: "1",
            title: "The Great Adventure",
            author: "Sample Author",
            genres: ["Fiction"],
            coverImageURL: "https://example.com/book-cover.jpg",
            description: "A thrilling tale of adventure.",
            dueDate: nil,
            isAvailable: true,
            totalCopies: 10,
            borrowedCopies: 3,
            availableCopies: 7,
            createdDate: "May 5, 2025 at 12:14:39 PM UTC+5:30"
        ))
    }
}
