import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileTabView: View {
    let role: String
    let logoutAction: () -> Void
    @State private var name = "Loading..."
    @State private var userId = ""
    @State private var joinedDate: Date? = nil
    @State private var membershipExpiryDate: Date? = nil
    @State private var membershipPlan = "None"
    @State private var hasSubmittedRequest = false
    @StateObject private var darkModeManager = DarkModeManager.shared
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoaded = false

    private let db = Firestore.firestore()
    private let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    private let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    var textColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    var secondaryTextColor: Color {
        colorScheme == .dark ? .gray : .secondary
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(colorScheme == .dark ? .black : .white)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(joinedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .opacity(isLoaded ? 1 : 0)
                                    .offset(y: isLoaded ? 0 : 20)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if isEditingName {
                                        TextField("Enter name", text: $editedName)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .multilineTextAlignment(.leading)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .padding(.horizontal)
                                    } else {
                                        Text(name)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(textColor)
                                            .opacity(isLoaded ? 1 : 0)
                                            .offset(y: isLoaded ? 0 : 20)
                                    }
                                    
                                    Text(role)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(secondaryTextColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.1))
                                        )
                                        .opacity(isLoaded ? 1 : 0)
                                        .offset(y: isLoaded ? 0 : 20)
                                }
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isLoaded)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(darkModeManager.isDarkMode ? .blue : .black)
                                    .overlay(
                                        Circle()
                                            .stroke(darkModeManager.isDarkMode ? Color.blue : Color.black, lineWidth: 2)
                                            .frame(width: 56, height: 56)
                                    )
                                    .scaleEffect(isLoaded ? 1 : 0.5)
                                    .opacity(isLoaded ? 1 : 0)
                            }
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isLoaded)
                            .accessibilityLabel("Profile")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                        
                        // Profile Details Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundColor(accentColor)
                                    .font(.system(size: 20))
                                Text("Profile Details")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(textColor)
                            }
                            
                            VStack(spacing: 16) {
                                DetailRow(icon: "number", label: "ID", value: userId, textColor: textColor, secondaryTextColor: secondaryTextColor)
                                DetailRow(icon: "calendar", label: "Joined", value: joinedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A", textColor: textColor, secondaryTextColor: secondaryTextColor)
                                DetailRow(icon: "clock", label: "Membership Expires", value: membershipExpiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not Set", textColor: textColor, secondaryTextColor: secondaryTextColor)
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        .padding(.horizontal)
                        
                        // Membership Plan Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(accentColor)
                                    .font(.system(size: 20))
                                Text("Membership Plan")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(textColor)
                            }
                            
                            VStack(spacing: 16) {
                                if membershipPlan == "None" {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("No Active Membership")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.red)
                                        
                                        Menu {
                                            ForEach(["1", "3", "6", "12"], id: \.self) { plan in
                                                Button(action: {
                                                    selectMembershipPlan(plan)
                                                }) {
                                                    Text("\(plan) Month\(plan == "1" ? "" : "s")")
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text("Select Membership Plan")
                                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                            }
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(buttonGradient)
                                            .cornerRadius(12)
                                        }
                                        .disabled(hasSubmittedRequest)
                                        .opacity(hasSubmittedRequest ? 0.6 : 1)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Selected Plan")
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(secondaryTextColor)
                                                Text("\(membershipPlan) Month\(membershipPlan == "1" ? "" : "s")")
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(textColor)
                                            }
                                            
                                            Spacer()
                                            
                                            if isMembershipActive {
                                                Text("Active")
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.green.opacity(0.1))
                                                    )
                                            } else {
                                                Text("In Review")
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(.orange)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.orange.opacity(0.1))
                                                    )
                                            }
                                        }
                                        
                                        if !isMembershipActive {
                                            Text("Your membership request is being reviewed by the librarian")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(secondaryTextColor)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                                
                                if !errorMessage.isEmpty && errorMessage.contains("submitted") {
                                    Text(errorMessage)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.green.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        .padding(.horizontal)
                        
                        // QR Code Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "qrcode")
                                    .foregroundColor(accentColor)
                                    .font(.system(size: 20))
                                Text("Member QR Code")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(textColor)
                            }
                            
                            VStack(spacing: 16) {
                                QRCodeView()
                                    .frame(width: 200, height: 200)
                                    .padding(20)
                                    .background(cardBackground)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                                
                                Text("Show this QR code to librarians for quick check-in/out")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(secondaryTextColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        .padding(.horizontal)
                        
                        // Settings Card
                        settingsCard
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        // Logout Button
                        Button(action: {
                            logoutAction()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Logout")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button(isEditingName ? "Save" : "Edit") {
                    if isEditingName {
                        // Save the edited name
                        updateName()
                    } else {
                        // Start editing
                        editedName = name
                        isEditingName = true
                    }
                }
            )
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
        .overlay(
            isLoading ? ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } : nil
        )
        .onAppear {
            fetchUserData()
        }
    }
    
    private var isMembershipActive: Bool {
        guard let expiryDate = membershipExpiryDate else { return false }
        return expiryDate > Date()
    }
    
    private func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in."
            return
        }
        
        isLoading = true
        joinedDate = user.metadata.creationDate
        
        db.collection("users").document(user.uid).getDocument { document, error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                print("Firestore error: \(errorMessage)")
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                errorMessage = "User data not found."
                print("Firestore error: User data not found")
                return
            }
            
            name = data["name"] as? String ?? "Unknown"
            userId = data["userId"] as? String ?? "N/A"
            membershipPlan = data["membershipPlan"] as? String ?? "None"
            if let expiryTimestamp = data["membershipExpiryDate"] as? Timestamp {
                membershipExpiryDate = expiryTimestamp.dateValue()
            }
            isLoaded = true
        }
    }
    
    private func selectMembershipPlan(_ plan: String) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in."
            return
        }
        
        guard role == "Member" else {
            errorMessage = "Only members can request membership plans."
            return
        }
        
        isLoading = true
        let requestData: [String: Any] = [
            "userId": userId,
            "name": name,
            "plan": plan,
            "requestDate": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        db.collection("membershipRequests").addDocument(data: requestData) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to submit membership request: \(error.localizedDescription)"
                print("Firestore error: \(errorMessage)")
            } else {
                errorMessage = "Membership request submitted for approval."
                hasSubmittedRequest = true
                print("Membership request created for \(plan) months")
            }
        }
    }
    
    private func updateName() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in."
            return
        }
        
        isLoading = true
        db.collection("users").document(user.uid).updateData([
            "name": editedName
        ]) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to update name: \(error.localizedDescription)"
            } else {
                name = editedName
                isEditingName = false
                errorMessage = ""
            }
        }
    }
    
    private func updateSettings() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in."
            return
        }
        
        let data: [String: Any] = [
            "settings": [
                "darkMode": darkModeManager.isDarkMode
            ]
        ]
        
        // Update Firestore
        db.collection("users").document(user.uid).updateData(data) { error in
            if let error = error {
                errorMessage = "Failed to update settings: \(error.localizedDescription)"
            } else {
                errorMessage = ""
            }
        }
    }
    
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(accentColor)
                    .font(.system(size: 20))
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
            }
            
            VStack(spacing: 16) {
                ToggleRow(icon: "moon.fill", title: "Dark Mode", isOn: $darkModeManager.isDarkMode) {
                    updateSettings()
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        .padding(.horizontal)
    }
}

// Helper Views
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let textColor: Color
    let secondaryTextColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(secondaryTextColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
            }
            
            Spacer()
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _ in
                    action()
                }
        }
    }
}

struct ProfileTabView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileTabView(role: "Member", logoutAction: {
            print("Logout tapped")
        })
    }
}

