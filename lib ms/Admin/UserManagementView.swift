import SwiftUI
import FirebaseFirestore

struct UserManagementView: View {
    @State private var searchText = ""
    @State private var selectedRole = "Librarian"
    @State private var users: [(id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)] = []
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showingAddLibrarianSheet = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    private let db = Firestore.firestore()
    private let roleOptions = ["Librarian", "Members"]
    private let customAccentColor = Color(red: 0.15, green: 0.38, blue: 0.70)
    private let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var filteredUsers: [(id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)] {
        let roleFiltered = users.filter { user in
            if selectedRole == "Librarian" {
                return user.role == "Librarian" && user.role != "Admin"
            } else {
                return user.role != "Librarian" && user.role != "Admin"
            }
        }
        if searchText.isEmpty {
            return roleFiltered
        } else {
            return roleFiltered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                contentView
                loadingView
                if selectedRole == "Librarian" {
                    floatingActionButton
                        .padding(.bottom, 20)
                        .padding(.trailing, 20)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddLibrarianSheet) {
            AddLibrarianView(onSave: { newUser in
                let extendedUser = (
                    id: newUser.id,
                    name: newUser.name,
                    role: newUser.role,
                    email: newUser.email,
                    personalEmail: newUser.personalEmail,
                    govtDocNumber: newUser.govtDocNumber,
                    dateJoined: newUser.dateJoined
                )
                users.append(extendedUser)
            })
        }
        .onAppear {
            fetchUsers()
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all)
    }

    private var contentView: some View {
        VStack(spacing: 20) {
            searchBarView
            rolePickerView
            userGridView
        }
        .padding(.top, 8)
    }

    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 12)
            TextField("Search \(selectedRole.lowercased())...", text: $searchText)
                .foregroundColor(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
        }
        .background(Color(.secondarySystemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4)
        .padding(.horizontal, 16)
        .animation(.spring(), value: searchText)
    }

    private var rolePickerView: some View {
        Picker("Role", selection: $selectedRole) {
            ForEach(roleOptions, id: \.self) { role in
                Text(role)
                    .font(.system(size: 16, weight: .medium))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .tint(customAccentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var userGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(filteredUsers, id: \.id) { user in
                    UserCardLink(user: user, onDelete: fetchUsers)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding()
                    .background(Color(.secondarySystemBackground).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var loadingView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: customAccentColor))
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 6)
            }
        }
    }

    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingAddLibrarianSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(buttonGradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(showingAddLibrarianSheet ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingAddLibrarianSheet)
            }
        }
    }

    private func fetchUsers() {
        isLoading = true
        db.collection("users").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to fetch users: \(error.localizedDescription)"
                print("Firestore error: \(errorMessage)")
                return
            }
            guard let documents = snapshot?.documents else {
                errorMessage = "No users found."
                return
            }

            users = documents.compactMap { doc in
                let data = doc.data()
                var userId = data["userId"] as? String ?? "N/A"
                if userId != "N/A" {
                    userId = String(userId.prefix(6)).padding(toLength: 6, withPad: "0", startingAt: 0)
                }
                let name = data["name"] as? String ?? "Unknown"
                let role = data["role"] as? String ?? "Member"
                let email = data["email"] as? String ?? "N/A"
                let personalEmail = data["personalEmail"] as? String ?? "N/A"
                let govtDocNumber = data["govtDocNumber"] as? String ?? "N/A"
                let dateJoined = data["dateJoined"] as? String ?? "N/A"
                return (id: userId, name: name, role: role, email: email, personalEmail: personalEmail, govtDocNumber: govtDocNumber, dateJoined: dateJoined)
            }
        }
    }
}

struct UserCardLink: View {
    let user: (id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        NavigationLink(destination: UserDetailView(user: user, onDelete: onDelete)) {
            UserCard(user: user)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct UserCard: View {
    let user: (id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)
    @AppStorage("isDarkMode") private var isDarkMode = false
    private let customAccentColor = Color(red: 0.15, green: 0.38, blue: 0.70)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(customAccentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(customAccentColor.opacity(0.4), lineWidth: 1.5)
                        )
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(customAccentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(user.email)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()
                .background(customAccentColor.opacity(0.3))

            HStack {
                Image(systemName: "number")
                    .font(.system(size: 14))
                    .foregroundColor(customAccentColor)
                Text(user.id)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
                .shadow(.inner(color: .black.opacity(0.05), radius: 2, x: 0, y: 2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }
}

struct UserManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserManagementView()
        }
    }
}
