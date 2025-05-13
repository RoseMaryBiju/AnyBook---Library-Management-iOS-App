import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MembersManagementView: View {
    // MARK: - State Properties
    @State private var searchText = ""
    // Modified tuple to include Firestore document ID
    @State private var users: [(id: String, documentId: String, name: String, role: String, membershipPlan: String, membershipExpiryDate: Date?)] = []
    @State private var requests: [(id: String, userId: String, name: String, plan: String, requestDate: Date, status: String)] = []
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var selectedTab = "Members"
    
    // MARK: - Constants
    private let db = Firestore.firestore()
    private let accentColor = Color.blue
    private let secondaryColor = Color(.systemGray6)
    private let cardBackground = Color(.systemBackground)
    
    // MARK: - Computed Properties
    private var filteredUsers: [(id: String, documentId: String, name: String, role: String, membershipPlan: String, membershipExpiryDate: Date?)] {
        let memberFiltered = users.filter { $0.role == "Member" }.sorted(by: { $0.name < $1.name })
        return searchText.isEmpty ? memberFiltered : memberFiltered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    private var filteredRequests: [(id: String, userId: String, name: String, plan: String, requestDate: Date, status: String)] {
        let pendingFiltered = requests.filter { $0.status == "pending" }.sorted(by: { $0.requestDate < $1.requestDate })
        return searchText.isEmpty ? pendingFiltered : pendingFiltered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Text(selectedTab)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // MARK: - Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16, weight: .medium))
                    TextField("Search \(selectedTab.lowercased())", text: $searchText)
                        .font(.system(size: 16, design: .rounded))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(secondaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .accessibilityLabel("Search \(selectedTab.lowercased()) by name")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // MARK: - Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Members").tag("Members")
                    Text("Requests").tag("Requests")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // MARK: - List Content
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 40)
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 24))
                        Text(errorMessage)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            fetchUsers()
                            fetchRequests()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .padding(.top, 40)
                } else if selectedTab == "Members" ? filteredUsers.isEmpty : filteredRequests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                        Text("No \(selectedTab.lowercased()) found.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                } else {
                    List {
                        // MARK: - List Header
                        HStack {
                            Text(selectedTab == "Members" ? "ID" : "Request ID")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text("Name")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        
                        // MARK: - List Items
                        if selectedTab == "Members" {
                            ForEach(filteredUsers, id: \.id) { user in
                                NavigationLink {
                                    userDetailView(user: user)
                                } label: {
                                    MemberRow(user: user)
                                }
                                .listRowBackground(
                                    cardBackground
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                            }
                        } else {
                            ForEach(filteredRequests, id: \.id) { request in
                                RequestRow(
                                    request: request,
                                    onApprove: { approveRequest(request) },
                                    onReject: { rejectRequest(request) }
                                )
                                .listRowBackground(
                                    cardBackground
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemBackground))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .onAppear {
                checkUserAccess()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func checkUserAccess() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please log in."
            return
        }
        db.collection("users").document(user.uid).getDocument { document, error in
            if let role = document?.data()?["role"] as? String, role == "Librarian" || role == "Admin" {
                fetchUsers()
                fetchRequests()
            } else {
                errorMessage = "Access restricted to Librarians and Admins."
            }
        }
    }
    
    private func fetchUsers() {
        isLoading = true
        errorMessage = ""
        
        db.collection("users").whereField("role", isEqualTo: "Member").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to fetch members: \(error.localizedDescription)"
                return
            }
            guard let documents = snapshot?.documents else {
                errorMessage = "No members found."
                return
            }
            
            users = documents.compactMap { doc in
                let data = doc.data()
                var userId = data["userId"] as? String ?? "N/A"
                if userId != "N/A" {
                    userId = String(userId.prefix(6)).padding(toLength: 6, withPad: "0", startingAt: 0)
                }
                let documentId = doc.documentID // Capture the Firestore document ID
                let name = data["name"] as? String ?? "Unknown"
                let role = data["role"] as? String ?? "Member"
                let membershipPlan = data["membershipPlan"] as? String ?? "None"
                let membershipExpiryDate = (data["membershipExpiryDate"] as? Timestamp)?.dateValue()
                return (id: userId, documentId: documentId, name: name, role: role, membershipPlan: membershipPlan, membershipExpiryDate: membershipExpiryDate)
            }
        }
    }
    
    private func fetchRequests() {
        isLoading = true
        errorMessage = ""
        
        db.collection("membershipRequests").whereField("status", isEqualTo: "pending").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to fetch requests: \(error.localizedDescription)"
                return
            }
            guard let documents = snapshot?.documents else {
                errorMessage = "No pending requests found."
                return
            }
            
            requests = documents.compactMap { doc in
                let data = doc.data()
                let userId = data["userId"] as? String ?? "N/A"
                let name = data["name"] as? String ?? "Unknown"
                let plan = data["plan"] as? String ?? "None"
                let requestDate = (data["requestDate"] as? Timestamp)?.dateValue() ?? Date()
                let status = data["status"] as? String ?? "pending"
                return (id: doc.documentID, userId: userId, name: name, plan: plan, requestDate: requestDate, status: status)
            }
        }
    }
    
    private func approveRequest(_ request: (id: String, userId: String, name: String, plan: String, requestDate: Date, status: String)) {
        isLoading = true
        let months = Int(request.plan) ?? 1
        let expiryDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
        
        let userData: [String: Any] = [
            "membershipPlan": request.plan,
            "membershipExpiryDate": Timestamp(date: expiryDate)
        ]
        
        db.collection("users").whereField("userId", isEqualTo: request.userId).getDocuments { snapshot, error in
            if let error = error {
                errorMessage = "Failed to find user: \(error.localizedDescription)"
                isLoading = false
                return
            }
            guard let document = snapshot?.documents.first else {
                errorMessage = "User not found."
                isLoading = false
                return
            }
            
            db.collection("users").document(document.documentID).updateData(userData) { error in
                if let error = error {
                    errorMessage = "Failed to update membership: \(error.localizedDescription)"
                    isLoading = false
                    return
                }
                
                db.collection("membershipRequests").document(request.id).updateData(["status": "approved"]) { error in
                    isLoading = false
                    if let error = error {
                        errorMessage = "Failed to update request: \(error.localizedDescription)"
                    } else {
                        fetchRequests()
                        fetchUsers()
                        errorMessage = ""
                    }
                }
            }
        }
    }
    
    private func rejectRequest(_ request: (id: String, userId: String, name: String, plan: String, requestDate: Date, status: String)) {
        isLoading = true
        db.collection("membershipRequests").document(request.id).updateData(["status": "rejected"]) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to reject request: \(error.localizedDescription)"
            } else {
                fetchRequests()
                errorMessage = ""
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let user: (id: String, documentId: String, name: String, role: String, membershipPlan: String, membershipExpiryDate: Date?)
    
    var body: some View {
        HStack {
            Text(user.id)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            Text(user.name)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityLabel("Member \(user.name), ID \(user.id)")
    }
}

// MARK: - Request Row
struct RequestRow: View {
    let request: (id: String, userId: String, name: String, plan: String, requestDate: Date, status: String)
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(String(request.id.prefix(6)))
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(request.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                Text("Plan: \(request.plan) Month\(request.plan == "1" ? "" : "s")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            HStack(spacing: 8) {
                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .controlSize(.small)
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .controlSize(.small)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityLabel("Membership request for \(request.name), Plan \(request.plan) months")
    }
}

// MARK: - User Detail View
struct userDetailView: View {
    let user: (id: String, documentId: String, name: String, role: String, membershipPlan: String, membershipExpiryDate: Date?)
    
    // MARK: - State Properties
    @State private var reservations: [(bookId: String, bookName: String, reservationDate: Date)] = []
    @State private var isLoadingReservations = false
    @State private var errorMessage = ""
    
    // MARK: - Firestore Instance
    private let db = Firestore.firestore()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Existing User Details
                Text(user.name)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                InfoRow(label: "ID", value: user.id)
                InfoRow(label: "Role", value: user.role)
                InfoRow(label: "Membership Plan", value: "\(user.membershipPlan) Month\(user.membershipPlan == "1" ? "" : "s")")
                InfoRow(label: "Membership Expires", value: user.membershipExpiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not Set")
                
                // Reservations Section
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                Text("Reserved Books")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                if isLoadingReservations {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 20)
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                } else if reservations.isEmpty {
                    Text("No reservations found.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(reservations, id: \.bookId) { reservation in
                            ReservationRow(
                                bookName: reservation.bookName,
                                reservationDate: reservation.reservationDate
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Member Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchReservations()
        }
    }
    
    // MARK: - Fetch Reservations
    private func fetchReservations() {
        isLoadingReservations = true
        errorMessage = ""
        
        print("Fetching reservations for user document ID: \(user.documentId)")
        
        db.collection("reservations")
            .whereField("userId", isEqualTo: user.documentId) // Use documentId instead of id
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reservations: \(error.localizedDescription)")
                    errorMessage = "Failed to fetch reservations: \(error.localizedDescription)"
                    isLoadingReservations = false
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No reservations found for user document ID: \(user.documentId)")
                    errorMessage = "No reservations found."
                    isLoadingReservations = false
                    return
                }
                
                print("Found \(documents.count) reservations")
                
                // Extract reservation data
                let reservationData = documents.compactMap { doc -> (bookId: String, reservationDate: Date)? in
                    let data = doc.data()
                    guard let bookId = data["bookID"] as? String, // Updated to match Firestore field name
                          let reservationDate = (data["reservationDate"] as? Timestamp)?.dateValue() else {
                        print("Invalid reservation data: \(data)")
                        return nil
                    }
                    return (bookId: bookId, reservationDate: reservationDate)
                }
                
                print("Parsed \(reservationData.count) valid reservations")
                
                if reservationData.isEmpty {
                    errorMessage = "No valid reservation data found."
                    isLoadingReservations = false
                    return
                }
                
                // Fetch book names
                fetchBookNames(for: reservationData) { result in
                    isLoadingReservations = false
                    switch result {
                    case .success(let reservationsWithNames):
                        print("Successfully fetched \(reservationsWithNames.count) book names")
                        reservations = reservationsWithNames.sorted(by: { $0.reservationDate < $1.reservationDate })
                    case .failure(let error):
                        print("Error fetching book names: \(error.localizedDescription)")
                        errorMessage = "Failed to fetch book details: \(error.localizedDescription)"
                    }
                }
            }
    }
    
    // MARK: - Fetch Book Names
    private func fetchBookNames(
        for reservations: [(bookId: String, reservationDate: Date)],
        completion: @escaping (Result<[(bookId: String, bookName: String, reservationDate: Date)], Error>) -> Void
    ) {
        var results: [(bookId: String, bookName: String, reservationDate: Date)] = []
        let group = DispatchGroup()
        
        for reservation in reservations {
            group.enter()
            print("Fetching book details for bookId: \(reservation.bookId)")
            
            // Try fetching from 'BooksCatalog' collection
            db.collection("BooksCatalog").document(reservation.bookId).getDocument { document, error in
                if let error = error {
                    print("Error fetching from BooksCatalog for bookId \(reservation.bookId): \(error.localizedDescription)")
                }
                
                if let document = document, document.exists, let name = document.data()?["name"] as? String {
                    print("Found book in BooksCatalog: \(name)")
                    results.append((bookId: reservation.bookId, bookName: name, reservationDate: reservation.reservationDate))
                    group.leave()
                    return
                }
                
                // Fallback to 'books' collection
                db.collection("books").document(reservation.bookId).getDocument { document, error in
                    if let error = error {
                        print("Error fetching from books for bookId \(reservation.bookId): \(error.localizedDescription)")
                    }
                    
                    if let document = document, document.exists, let name = document.data()?["title"] as? String {
                        print("Found book in books: \(name)")
                        results.append((bookId: reservation.bookId, bookName: name, reservationDate: reservation.reservationDate))
                    } else {
                        print("Book not found for bookId: \(reservation.bookId)")
                        results.append((bookId: reservation.bookId, bookName: "Unknown Book", reservationDate: reservation.reservationDate))
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if results.isEmpty && !reservations.isEmpty {
                print("No book details found for any reservations")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No book details found."])))
            } else {
                print("Returning \(results.count) book details")
                completion(.success(results))
            }
        }
    }
}

// MARK: - Reservation Row Component
struct ReservationRow: View {
    let bookName: String
    let reservationDate: Date
    
    var body: some View {
        HStack(alignment: .top) {
            Text(bookName)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(reservationDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("Book \(bookName), reserved on \(reservationDate.formatted(date: .abbreviated, time: .omitted))")
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview
struct MembersManagementView_Previews: PreviewProvider {
    static var previews: some View {
        MembersManagementView()
            .previewDevice("iPhone 14 Pro")
            .preferredColorScheme(.light)
        
        MembersManagementView()
            .previewDevice("iPhone 14 Pro")
            .preferredColorScheme(.dark)
    }
}
