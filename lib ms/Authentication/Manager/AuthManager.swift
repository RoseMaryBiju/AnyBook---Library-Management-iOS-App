import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userRole: String = ""
    @Published var isLoading = true
    
    static let shared = AuthManager()
    private let db = Firestore.firestore()
    
    private init() {
        checkAuthState()
    }
    
    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            // User is signed in, fetch their role
            db.collection("users").document(user.uid).getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching user role: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                if let document = document, document.exists,
                   let role = document.data()?["role"] as? String {
                    DispatchQueue.main.async {
                        self.userRole = role
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.isLoading = false
                    }
                }
            }
        } else {
            // No user is signed in
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.userRole = ""
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
} 