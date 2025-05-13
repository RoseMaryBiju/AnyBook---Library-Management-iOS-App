import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var isActive = false
    @State private var bounceOffset: CGFloat = 0.0
    @State private var textOpacity: Double = 0.0
    @StateObject private var authManager = AuthManager.shared
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("4") // Ensure "logo" exists in Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 350, height: 350)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(y: bounceOffset)
                
                Text("AnyBook")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .opacity(textOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
                textOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                bounceOffset = -10
            }
            
            // Check if it's first launch
            if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                showOnboarding = false
            } else {
                showOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            }
            
            // Wait for 2 seconds before checking auth state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isActive = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingScreen()
        }
        .fullScreenCover(isPresented: $isActive) {
            if authManager.isLoading {
                // Show loading state
                ZStack {
                    Color.white.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            } else if authManager.isAuthenticated {
                // Navigate to appropriate dashboard based on role
                switch authManager.userRole {
                case "Admin":
                    AdminDashboardView()
                case "Librarian":
                    LibrarianInterface()
                case "Member":
                    HomePage(role: "Member")
                default:
                    LoginView()
                }
            } else {
                LoginView()
            }
        }
    }
}

struct OnboardingScreen: View {
    @State private var currentPage = 0
    let pages = [
        ("Welcome to AnyBook", "Discover a seamless way to manage your books with cutting-edge features.", "1"),
        ("Share Your Books", "Easily exchange books with friends and family.", "2"),
        ("Enjoy Reading", "Embark on a personalized reading journey tailored just for you!", "3")
    ]
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var navigateToLogin = false
    @State private var iconScale: CGFloat = 1.0
    @State private var textOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // TabView for onboarding pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(pages[index].2)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 280, height: 280)
                                .offset(y: offset)
                                .scaleEffect(iconScale)
                                .shadow(radius: 5)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .onAppear {
                                    // Reset states
                                    offset = 50
                                    iconScale = 0.8
                                    textOpacity = 0.0
                                    
                                    // Icon animation: slide up and scale
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                        offset = 0
                                        iconScale = 1.0
                                    }
                                    
                                    // Text fade-in
                                    withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                                        textOpacity = 1.0
                                    }
                                }
                            
                            Text(pages[index].0)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .opacity(textOpacity)
                                .transition(.opacity)
                            
                            Text(pages[index].1)
                                .font(.system(size: 18, weight: .regular, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .opacity(textOpacity)
                                .transition(.opacity)
                        }
                        .frame(maxWidth: .infinity)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Navigation button
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            navigateToLogin = true
                        }
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                isAnimating = true
                            }
                        }
                }
                .padding(.bottom, 50)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .fullScreenCover(isPresented: $navigateToLogin) {
                LoginView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}

struct ContentView: View {
    var body: some View {
        SplashView()
    }
}

#Preview {
    ContentView()
}
