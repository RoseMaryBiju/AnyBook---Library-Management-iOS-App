//
//  DashboardViewModel.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class DashboardViewModel: ObservableObject {
    @Published var greetingMessage: String = "Loading..."
    @Published var currentDate: String = ""
    @Published var membershipCount: Int = 0
    @Published var activeMembersCount: Int = 0
    @Published var activeMembers: [ActiveMember] = []
    @Published var bookRequestsCount: Int = 0
    @Published var upcomingEvents: [Event] = []
    
    @Published var booksIssuedPerDay: [BooksIssuedData] = []
    @Published var newMembershipsPerDay: [NewMembershipData] = []
    @Published var mostIssuedGenres: [GenreData] = []
    
    private let db = Firestore.firestore()
    
    init() {
        updateDate()
    }
    
    private func updateDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        currentDate = dateFormatter.string(from: Date())
    }
    
    func fetchLibrarianName() {
        guard let user = Auth.auth().currentUser else {
            greetingMessage = "Please log in"
            return
        }
        
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching name: \(error.localizedDescription)")
                self.greetingMessage = "Good Day, Librarian"
                return
            }
            
            if let document = document, document.exists, let name = document.data()?["name"] as? String, !name.isEmpty {
                let hour = Calendar.current.component(.hour, from: Date())
                self.greetingMessage = hour < 12 ? "Good Morning, \(name)" : hour < 17 ? "Good Afternoon, \(name)" : "Good Evening, \(name)"
            } else {
                self.greetingMessage = "Good Day, Librarian"
            }
        }
    }
    
    func loadActiveMembers(libraryViewModel: LibraryViewModel) {
        let transactions = libraryViewModel.transactions.filter { $0.status == "issued" }
        let activeMemberIDs = Set(transactions.map { $0.memberID })
        print("Active Member IDs from Transactions: \(activeMemberIDs)")
        
        // Count borrowed books per member
        var borrowedBooksCount: [String: Int] = [:]
        for transaction in transactions {
            if transaction.status == "issued" {
                borrowedBooksCount[transaction.memberID, default: 0] += 1
            }
        }
        print("Borrowed Books Count: \(borrowedBooksCount)")
        
        // Since memberID in Transactions is the document ID in users, fetch those specific documents
        if activeMemberIDs.isEmpty {
            print("No active members found in transactions")
            self.activeMembers = []
            self.activeMembersCount = 0
            return
        }
        
        // Use a batch query to fetch user documents by their IDs
        let dispatchGroup = DispatchGroup()
        var members: [ActiveMember] = []
        
        for memberID in activeMemberIDs {
            dispatchGroup.enter()
            db.collection("users").document(memberID).getDocument { [weak self] document, error in
                defer { dispatchGroup.leave() }
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching user document \(memberID): \(error.localizedDescription)")
                    // Add a placeholder member in case of error
                    members.append(ActiveMember(
                        id: memberID,
                        name: "Unknown (ID: \(memberID))",
                        email: "Not available",
                        borrowedBooksCount: borrowedBooksCount[memberID] ?? 0
                    ))
                    return
                }
                
                guard let document = document, document.exists else {
                    print("User document \(memberID) does not exist")
                    members.append(ActiveMember(
                        id: memberID,
                        name: "Unknown (ID: \(memberID))",
                        email: "Not available",
                        borrowedBooksCount: borrowedBooksCount[memberID] ?? 0
                    ))
                    return
                }
                
                let data = document.data() ?? [:]
                let name = data["name"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? "No email"
                let role = data["role"] as? String ?? "unknown"
                print("Fetched user - ID: \(memberID), Role: \(role), Name: \(name), Email: \(email)")
                
                members.append(ActiveMember(
                    id: memberID,
                    name: name,
                    email: email,
                    borrowedBooksCount: borrowedBooksCount[memberID] ?? 0
                ))
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.activeMembers = members
            self.activeMembersCount = members.count
            print("Matching Members: \(self.activeMembers.map { $0.id })")
        }
    }
    
    func fetchBookRequests(libraryViewModel: LibraryViewModel) {
        self.bookRequestsCount = libraryViewModel.bookRequests.filter { $0.status == "pending" }.count
        print("Book Requests Count: \(self.bookRequestsCount)")
    }
    
    func loadEvents() {
        let now = Timestamp(date: Date())
        db.collection("EventsData")
            .whereField("date", isGreaterThanOrEqualTo: now)
            .order(by: "date", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching upcoming events: \(error.localizedDescription)")
                    self.upcomingEvents = []
                    return
                }
                
                self.upcomingEvents = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let date = data["date"] as? Timestamp,
                          let description = data["description"] as? String else {
                        return nil
                    }
                    let bannerURL = data["bannerURL"] as? String
                    return Event(id: doc.documentID, title: title, date: date, eventDescription: description, bannerURL: bannerURL)
                } ?? []
            }
    }
    
    func deleteEvent(event: Event) {
        db.collection("EventsData").document(event.id).delete { error in
            if let error = error {
                print("Error deleting event: \(error.localizedDescription)")
            } else {
                self.loadEvents()
            }
        }
    }
    
    func loadAnalyticsData(catalogViewModel: CatalogViewModel, libraryViewModel: LibraryViewModel, completion: @escaping () -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dispatchGroup = DispatchGroup()
        
        // Books Issued Per Day (Past 7 Days)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let transactions = libraryViewModel.transactions.filter { transaction in
            let issueDate = transaction.issueDate.dateValue()
            return transaction.status == "issued" && issueDate >= sevenDaysAgo
        }
        
        var issuedPerDay: [Date: Int] = [:]
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            issuedPerDay[calendar.startOfDay(for: date)] = 0
        }
        
        for transaction in transactions {
            let issueDate = calendar.startOfDay(for: transaction.issueDate.dateValue())
            if issuedPerDay[issueDate] != nil {
                issuedPerDay[issueDate]! += 1
            }
        }
        
        self.booksIssuedPerDay = issuedPerDay.map { date, count in
            BooksIssuedData(date: date, count: count)
        }.sorted { $0.date < $1.date }
        print("Books Issued Per Day: \(self.booksIssuedPerDay.map { ($0.date, $0.count) })")
        
        // New Memberships Per Day (Past 7 Days) using membershipRequests
        dispatchGroup.enter()
        db.collection("membershipRequests")
            .whereField("status", isEqualTo: "approved")
            .whereField("requestDate", isGreaterThanOrEqualTo: Timestamp(date: sevenDaysAgo))
            .getDocuments { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching membership requests: \(error.localizedDescription)")
                    self.newMembershipsPerDay = []
                    return
                }
                
                let requests = snapshot?.documents.compactMap { doc -> (String, Timestamp)? in
                    let data = doc.data()
                    guard let requestDate = data["requestDate"] as? Timestamp else { return nil }
                    return (doc.documentID, requestDate)
                } ?? []
                
                var membershipsPerDay: [Date: Int] = [:]
                for dayOffset in 0..<7 {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
                    membershipsPerDay[calendar.startOfDay(for: date)] = 0
                }
                
                for (_, requestDate) in requests {
                    let requestDay = calendar.startOfDay(for: requestDate.dateValue())
                    if membershipsPerDay[requestDay] != nil {
                        membershipsPerDay[requestDay]! += 1
                    }
                }
                
                self.newMembershipsPerDay = membershipsPerDay.map { date, count in
                    NewMembershipData(date: date, count: count)
                }.sorted { $0.date < $1.date }
                print("New Memberships Per Day: \(self.newMembershipsPerDay.map { ($0.date, $0.count) })")
            }
        
        // Most Issued Genres
        let issuedTransactions = libraryViewModel.transactions.filter { $0.status == "issued" }
        var genreCounts: [String: Int] = [:]
        let booksByID = Dictionary(uniqueKeysWithValues: catalogViewModel.books.map { ($0.isbn, $0) })
        
        for transaction in issuedTransactions {
            if let book = booksByID[transaction.bookID] {
                let genres = book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for genre in genres {
                    genreCounts[String(genre), default: 0] += 1
                }
            }
        }
        
        self.mostIssuedGenres = genreCounts.map { genre, count in
            GenreData(genre: genre, count: count)
        }.sorted { $0.count > $1.count }.prefix(5).map { $0 }
        print("Most Issued Genres: \(self.mostIssuedGenres.map { ($0.genre, $0.count) })")
        
        // Membership Count (Users with role "member")
        dispatchGroup.enter()
        db.collection("users").whereField("role", isEqualTo: "member").getDocuments { [weak self] snapshot, error in
            defer { dispatchGroup.leave() }
            guard let self = self else { return }
            if let error = error {
                print("Error fetching membership count: \(error.localizedDescription)")
                self.membershipCount = 0
            } else {
                self.membershipCount = snapshot?.documents.count ?? 0
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
}
