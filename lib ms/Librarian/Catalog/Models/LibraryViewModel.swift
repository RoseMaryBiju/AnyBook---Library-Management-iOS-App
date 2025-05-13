//
//  LibraryViewModel.swift
//  lib ms
//
//  Created by admin86 on 07/05/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class LibraryViewModel: ObservableObject {
    @Published var bookRequests: [BookRequest] = []
    @Published var transactions: [Transaction] = []
    @Published var fines: [Fine] = []
    @Published var settings: LibrarySettings?
    @Published var borrowedBooks: [BorrowedBook] = []
    @Published var completedBooks: [BorrowedBook] = []
    @Published var upcomingEvents: [Event] = []

    // Computed properties for stats
    var issuedBooksCount: Int {
        transactions.filter { $0.status == "issued" }.count
    }

    var overdueBooksCount: Int {
        let currentDate = Date()
        return transactions.filter { transaction in
            transaction.status == "issued" && transaction.dueDate.dateValue() < currentDate
        }.count
    }

    var pendingFinesCount: Int {
        fines.filter { $0.status == "pending" }.count
    }

    private let db = Firestore.firestore()

    init() {
        loadSettings()
        loadBookRequests()
        loadTransactions()
        loadFines()
        loadUpcomingEvents()
    }

    // MARK: - Data Loading

    func loadSettings() {
        db.collection("Settings").document("librarySettings").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching settings: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else {
                print("No settings found")
                return
            }
            self.settings = LibrarySettings(
                damagedBookPercentage: data["damagedBookPercentage"] as? Double ?? 60.0,
                lostBookPercentage: data["lostBookPercentage"] as? Double ?? 85.0,
                lateReturnFine: data["lateReturnFine"] as? Double ?? 5.0,
                maxBorrowingDays: data["maxBorrowingDays"] as? Int ?? 7,
                reservationDuration: data["reservationDuration"] as? Int ?? 12
            )
        }
    }

    func loadBookRequests() {
        db.collection("BookRequests").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching book requests: \(error.localizedDescription)")
                self.bookRequests = []
                return
            }
            guard let documents = snapshot?.documents else {
                self.bookRequests = []
                return
            }
            self.bookRequests = documents.compactMap { doc in
                let data = doc.data()
                return BookRequest(
                    id: doc.documentID,
                    memberID: data["memberID"] as? String ?? "",
                    bookID: data["bookID"] as? String ?? "",
                    status: data["status"] as? String ?? "pending",
                    createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                    acceptedAt: data["acceptedAt"] as? Timestamp,
                    updatedAt: data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
                )
            }
        }
    }

    func loadTransactions() {
        db.collection("Transactions").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching transactions: \(error.localizedDescription)")
                self.transactions = []
                return
            }
            guard let documents = snapshot?.documents else {
                self.transactions = []
                return
            }
            self.transactions = documents.compactMap { doc in
                let data = doc.data()
                return Transaction(
                    id: doc.documentID,
                    memberID: data["memberID"] as? String ?? "",
                    bookID: data["bookID"] as? String ?? "",
                    requestID: data["requestID"] as? String ?? "",
                    status: data["status"] as? String ?? "issued",
                    issueDate: data["issueDate"] as? Timestamp ?? Timestamp(date: Date()),
                    dueDate: data["dueDate"] as? Timestamp ?? Timestamp(date: Date()),
                    returnDate: data["returnDate"] as? Timestamp,
                    fineID: data["fineID"] as? String
                )
            }
            self.fetchBorrowedBooks()
            self.fetchCompletedBooks()
        }
    }

    func loadFines() {
        db.collection("Fines").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching fines: \(error.localizedDescription)")
                self.fines = []
                return
            }
            guard let documents = snapshot?.documents else {
                self.fines = []
                return
            }
            self.fines = documents.compactMap { doc in
                let data = doc.data()
                return Fine(
                    id: doc.documentID,
                    memberID: data["memberID"] as? String ?? "",
                    transactionID: data["transactionID"] as? String ?? "",
                    amount: data["amount"] as? Double ?? 0.0,
                    reason: data["reason"] as? String ?? "",
                    status: data["status"] as? String ?? "pending",
                    createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                    paidAt: data["paidAt"] as? Timestamp
                )
            }
        }
    }

    func loadUpcomingEvents() {
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

    func fetchBorrowedBooks() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ERROR: No user logged in when fetching borrowed books")
            self.borrowedBooks = []
            return
        }
        print("Fetching borrowed books for user: \(userID)")

        let issuedTransactions = transactions.filter { $0.status == "issued" && $0.memberID == userID }
        print("Found \(issuedTransactions.count) issued transactions for user")
        
        if issuedTransactions.isEmpty {
            print("No issued transactions found. All transactions:")
            transactions.forEach { transaction in
                print("- ID: \(transaction.id), Status: \(transaction.status), MemberID: \(transaction.memberID)")
            }
        }
        
        var fetchedBooks: [BorrowedBook] = []
        let dispatchGroup = DispatchGroup()

        for transaction in issuedTransactions {
            dispatchGroup.enter()
            print("Fetching book details for transaction: \(transaction.id), bookID: \(transaction.bookID)")
            
            db.collection("BooksCatalog").document(transaction.bookID).getDocument { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                guard let self = self else { return }
                
                if let error = error {
                    print("ERROR fetching book details: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("ERROR: No book data found for ID: \(transaction.bookID)")
                    return
                }
                
                print("Successfully fetched book: \(data["title"] as? String ?? "Unknown Title")")
                
                let book = MemberBook(
                    title: data["title"] as? String ?? "Unknown Title",
                    author: data["author"] as? String ?? "Unknown Author",
                    illustrator: data["illustrator"] as? String,
                    genres: data["genres"] as? String ?? "",
                    isbn: transaction.bookID,
                    language: data["language"] as? String ?? "Unknown",
                    bookFormat: data["bookFormat"] as? String ?? "Unknown",
                    edition: data["edition"] as? String ?? "Unknown",
                    pages: (data["pages"] as? Int) ?? 0,
                    publisher: data["publisher"] as? String ?? "Unknown",
                    description: data["summary"] as? String ?? "",
                    isAvailable: data["isAvailable"] as? Bool ?? true,
                    createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                    isFavorite: data["isFavorite"] as? Bool ?? false,
                    numberOfCopies: (data["numberOfCopies"] as? Int) ?? 0,
                    unavailableCopies: (data["unavailableCopies"] as? Int) ?? 0,
                    coverImageURL: data["coverImageURL"] as? String,
                    authorID: data["authorID"] as? String,
                    cost: (data["cost"] as? Double) ?? 20.0
                )
                
                let borrowedBook = BorrowedBook(book: book, transaction: transaction)
                fetchedBooks.append(borrowedBook)
                print("Added book to fetchedBooks array. Current count: \(fetchedBooks.count)")
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.borrowedBooks = fetchedBooks.sorted { $0.transaction.dueDate.dateValue() < $1.transaction.dueDate.dateValue() }
            print("Final borrowedBooks array count: \(self.borrowedBooks.count)")
            if !self.borrowedBooks.isEmpty {
                print("Borrowed books titles:")
                self.borrowedBooks.forEach { book in
                    print("- \(book.book.title) (Due: \(book.transaction.dueDate.dateValue()))")
                }
            } else {
                print("No borrowed books found")
            }
        }
    }
    
    func fetchCompletedBooks() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ERROR: No user logged in when fetching completed books")
            self.completedBooks = []
            return
        }
        print("Fetching completed books for user: \(userID)")

        let completedTransactions = transactions.filter {
            ($0.status == "returned" || $0.status == "damaged" || $0.status == "lost") &&
            $0.memberID == userID
        }
        print("Found \(completedTransactions.count) completed transactions for user")
        
        var fetchedBooks: [BorrowedBook] = []
        let dispatchGroup = DispatchGroup()

        for transaction in completedTransactions {
            dispatchGroup.enter()
            print("Fetching book details for completed transaction: \(transaction.id), bookID: \(transaction.bookID)")
            
            db.collection("BooksCatalog").document(transaction.bookID).getDocument { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                guard let self = self else { return }
                
                if let error = error {
                    print("ERROR fetching book details: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("ERROR: No book data found for ID: \(transaction.bookID)")
                    return
                }
                
                let book = MemberBook(
                    title: data["title"] as? String ?? "Unknown Title",
                    author: data["author"] as? String ?? "Unknown Author",
                    illustrator: data["illustrator"] as? String,
                    genres: data["genres"] as? String ?? "",
                    isbn: transaction.bookID,
                    language: data["language"] as? String ?? "Unknown",
                    bookFormat: data["bookFormat"] as? String ?? "Unknown",
                    edition: data["edition"] as? String ?? "Unknown",
                    pages: (data["pages"] as? Int) ?? 0,
                    publisher: data["publisher"] as? String ?? "Unknown",
                    description: data["summary"] as? String ?? "",
                    isAvailable: data["isAvailable"] as? Bool ?? true,
                    createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                    isFavorite: data["isFavorite"] as? Bool ?? false,
                    numberOfCopies: (data["numberOfCopies"] as? Int) ?? 0,
                    unavailableCopies: (data["unavailableCopies"] as? Int) ?? 0,
                    coverImageURL: data["coverImageURL"] as? String,
                    authorID: data["authorID"] as? String,
                    cost: (data["cost"] as? Double) ?? 20.0
                )
                
                let borrowedBook = BorrowedBook(book: book, transaction: transaction)
                fetchedBooks.append(borrowedBook)
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.completedBooks = fetchedBooks.sorted { $0.transaction.returnDate?.dateValue() ?? Date() > $1.transaction.returnDate?.dateValue() ?? Date() }
            print("Final completedBooks array count: \(self.completedBooks.count)")
        }
    }

    // MARK: - Event Management

    func deleteEvent(_ event: Event) {
        db.collection("EventsData").document(event.id).delete { error in
            if let error = error {
                print("Error deleting event: \(error.localizedDescription)")
            } else {
                self.loadUpcomingEvents()
            }
        }
    }

    // MARK: - Book Requests

    func createBookRequest(memberID: String, bookID: String, startDate: Date, endDate: Date) {
        let requestData: [String: Any] = [
            "memberID": memberID,
            "bookID": bookID,
            "status": "pending",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate)
        ]
        db.collection("BookRequests").addDocument(data: requestData) { error in
            if let error = error {
                print("Error creating book request: \(error.localizedDescription)")
            }
        }
    }

    func acceptBookRequest(_ request: BookRequest, book: Book) {
        guard book.numberOfCopies > 0 else {
            print("Cannot accept request: Book not available")
            return
        }

        db.collection("BooksCatalog").document(request.bookID).updateData([
            "numberOfCopies": book.numberOfCopies - 1,
            "isAvailable": (book.numberOfCopies - 1) > 0
        ]) { error in
            if let error = error {
                print("Error reserving book: \(error.localizedDescription)")
                return
            }

            self.db.collection("BookRequests").document(request.id).updateData([
                "status": "accepted",
                "acceptedAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ]) { error in
                if let error = error {
                    print("Error accepting book request: \(error.localizedDescription)")
                }
            }
        }
    }

    func rejectBookRequest(_ request: BookRequest) {
        db.collection("BookRequests").document(request.id).updateData([
            "status": "rejected",
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error rejecting book request: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Check-Out (Issue Book)

    func issueBook(request: BookRequest) {
        guard request.status == "accepted" else {
            print("Cannot issue book: Request not accepted")
            return
        }

        // Step 1: Decrease the numberOfCopies in BooksCatalog
        db.collection("BooksCatalog").document(request.bookID).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching book: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data(),
                  let numberOfCopies = data["numberOfCopies"] as? Int else {
                print("Book not found or invalid data for bookID: \(request.bookID)")
                return
            }

            // Check if there are enough copies to issue
            guard numberOfCopies > 0 else {
                print("Cannot issue book: No copies available for bookID: \(request.bookID)")
                return
            }

            let newNumberOfCopies = numberOfCopies - 1
            self.db.collection("BooksCatalog").document(request.bookID).updateData([
                "numberOfCopies": newNumberOfCopies,
                "isAvailable": newNumberOfCopies > 0
            ]) { error in
                if let error = error {
                    print("Error updating book copies: \(error.localizedDescription)")
                    return
                }

                // Step 2: Create the transaction
                let issueDate = Date()
                let dueDate = Calendar.current.date(byAdding: .day, value: self.settings?.maxBorrowingDays ?? 7, to: issueDate)!

                let transactionData: [String: Any] = [
                    "memberID": request.memberID,
                    "bookID": request.bookID,
                    "requestID": request.id,
                    "status": "issued",
                    "issueDate": Timestamp(date: issueDate),
                    "dueDate": Timestamp(date: dueDate)
                ]

                self.db.collection("Transactions").addDocument(data: transactionData) { error in
                    if let error = error {
                        print("Error issuing book: \(error.localizedDescription)")
                        return
                    }

                    // Step 3: Update the book request status
                    self.db.collection("BookRequests").document(request.id).updateData([
                        "status": "issued",
                        "updatedAt": Timestamp(date: Date())
                    ]) { error in
                        if let error = error {
                            print("Error updating request status: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    func issueAllBooks(for memberID: String) {
        let acceptedRequests = bookRequests.filter { $0.memberID == memberID && $0.status == "accepted" }
        for request in acceptedRequests {
            issueBook(request: request)
        }
    }

    // MARK: - Check-In (Return Book)

    func returnBook(transaction: Transaction, book: Book) {
        let returnDate = Date()
        let daysLate = calculateDaysLate(dueDate: transaction.dueDate.dateValue(), returnDate: returnDate)
        let lateFine = daysLate > 0 ? Double(daysLate) * (settings?.lateReturnFine ?? 5.0) : 0.0

        // Ensure numberOfCopies doesn't go below 0 (though it should already be handled)
        let newNumberOfCopies = book.numberOfCopies + 1
        db.collection("BooksCatalog").document(book.isbn).updateData([
            "numberOfCopies": newNumberOfCopies,
            "isAvailable": true
        ]) { error in
            if let error = error {
                print("Error updating book availability: \(error.localizedDescription)")
                return
            }

            var transactionUpdate: [String: Any] = [
                "status": "returned",
                "returnDate": Timestamp(date: returnDate)
            ]

            if lateFine > 0 {
                let fineData: [String: Any] = [
                    "memberID": transaction.memberID,
                    "transactionID": transaction.id,
                    "amount": lateFine,
                    "reason": "late",
                    "status": "pending",
                    "createdAt": Timestamp(date: Date())
                ]
                self.db.collection("Fines").addDocument(data: fineData) { error in
                    if let error = error {
                        print("Error creating fine: \(error.localizedDescription)")
                        return
                    }
                    self.db.collection("Transactions").document(transaction.id).updateData([
                        "fineID": self.fines.last?.id ?? ""
                    ])
                }
            }

            self.db.collection("Transactions").document(transaction.id).updateData(transactionUpdate) { error in
                if let error = error {
                    print("Error updating transaction: \(error.localizedDescription)")
                }
            }
        }
    }

    func markBookAsDamaged(transaction: Transaction, book: Book, increaseCopies: Bool) {
        let fineAmount = book.cost * (settings?.damagedBookPercentage ?? 60.0) / 100.0
        let fineData: [String: Any] = [
            "memberID": transaction.memberID,
            "transactionID": transaction.id,
            "amount": fineAmount,
            "reason": "damaged",
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("Fines").addDocument(data: fineData) { error in
            if let error = error {
                print("Error creating fine: \(error.localizedDescription)")
                return
            }

            // Update book: always increment unavailableCopies, conditionally increment numberOfCopies
            var bookUpdate: [String: Any] = [
                "unavailableCopies": max(0, book.unavailableCopies + 1) // Ensure non-negative
            ]
            if increaseCopies {
                let newNumberOfCopies = book.numberOfCopies + 1
                bookUpdate["numberOfCopies"] = newNumberOfCopies
                bookUpdate["isAvailable"] = newNumberOfCopies > 0
            } else {
                bookUpdate["isAvailable"] = book.numberOfCopies > 0
            }

            self.db.collection("BooksCatalog").document(book.isbn).updateData(bookUpdate) { error in
                if let error = error {
                    print("Error updating book: \(error.localizedDescription)")
                    return
                }

                self.db.collection("Transactions").document(transaction.id).updateData([
                    "status": "damaged",
                    "returnDate": Timestamp(date: Date()),
                    "fineID": self.fines.last?.id ?? ""
                ])
            }
        }
    }

    func markBookAsLost(transaction: Transaction, book: Book) {
        let fineAmount = book.cost * (settings?.lostBookPercentage ?? 85.0) / 100.0
        let fineData: [String: Any] = [
            "memberID": transaction.memberID,
            "transactionID": transaction.id,
            "amount": fineAmount,
            "reason": "lost",
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("Fines").addDocument(data: fineData) { error in
            if let error = error {
                print("Error creating fine: \(error.localizedDescription)")
                return
            }

            self.db.collection("Transactions").document(transaction.id).updateData([
                "status": "lost",
                "returnDate": Timestamp(date: Date()),
                "fineID": self.fines.last?.id ?? ""
            ])

            self.db.collection("BooksCatalog").document(book.isbn).updateData([
                "unavailableCopies": max(0, book.unavailableCopies + 1),
                "isAvailable": book.numberOfCopies > 0
            ])
        }
    }

    // MARK: - Fine Management

    func toggleFineStatus(fine: Fine) {
        let newStatus = fine.status == "pending" ? "paid" : "pending"
        var updateData: [String: Any] = [
            "status": newStatus,
            "updatedAt": Timestamp(date: Date())
        ]

        if newStatus == "paid" {
            updateData["paidAt"] = Timestamp(date: Date())
        } else {
            updateData["paidAt"] = FieldValue.delete()
        }

        db.collection("Fines").document(fine.id).updateData(updateData) { error in
            if let error = error {
                print("Error toggling fine status: \(error.localizedDescription)")
            }
        }
    }

    private func calculateDaysLate(dueDate: Date, returnDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dueDate, to: returnDate)
        return max(0, components.day ?? 0)
    }
}

// MARK: - Models

struct BorrowedBook: Identifiable, Equatable {
    let id = UUID()
    let book: MemberBook
    let transaction: Transaction
    
    static func == (lhs: BorrowedBook, rhs: BorrowedBook) -> Bool {
        lhs.id == rhs.id &&
        lhs.book == rhs.book &&
        lhs.transaction == rhs.transaction
    }
}

struct BookRequest: Identifiable, Equatable {
    let id: String
    let memberID: String
    let bookID: String
    let status: String
    let createdAt: Timestamp
    let acceptedAt: Timestamp?
    let updatedAt: Timestamp
}

struct Transaction: Identifiable, Equatable {
    let id: String
    let memberID: String
    let bookID: String
    let requestID: String
    let status: String
    let issueDate: Timestamp
    let dueDate: Timestamp
    let returnDate: Timestamp?
    let fineID: String?
}

struct Fine: Identifiable {
    let id: String
    let memberID: String
    let transactionID: String
    let amount: Double
    let reason: String
    let status: String
    let createdAt: Timestamp
    let paidAt: Timestamp?
}

struct LibrarySettings {
    let damagedBookPercentage: Double
    let lostBookPercentage: Double
    let lateReturnFine: Double
    let maxBorrowingDays: Int
    let reservationDuration: Int
}
