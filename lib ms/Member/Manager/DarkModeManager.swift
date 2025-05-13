import SwiftUI

class DarkModeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "darkModeEnabled")
            // Notify all views to update their appearance
            objectWillChange.send()
        }
    }
    
    static let shared = DarkModeManager()
    
    private init() {
        // Initialize with the saved preference, defaulting to light mode if not set
        self.isDarkMode = UserDefaults.standard.bool(forKey: "darkModeEnabled")
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
    }
    
    func setDarkMode(_ enabled: Bool) {
        isDarkMode = enabled
    }
} 