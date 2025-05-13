import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class MemberCatalogViewModel: ObservableObject {
    @Published var books: [MemberBook] = []
    @Published var genres: [String] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var booksListener: ListenerRegistration?
    private var favoritesListener: ListenerRegistration?
    
    init() {
        loadData()
    }
    
    deinit {
        // Remove listeners when view model is deallocated
        booksListener?.remove()
        favoritesListener?.remove()
    }
    
    func loadData() {
        print("Starting to load books data...")
        isLoading = true
        error = nil
        
        // Remove any existing listeners
        booksListener?.remove()
        favoritesListener?.remove()
        
        // Set up books listener
        booksListener = db.collection("BooksCatalog").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { 
                print("Self was deallocated")
                return 
            }
            
            self.isLoading = false
            
            if let error = error {
                print("Error loading books: \(error.localizedDescription)")
                self.error = error
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No books found in snapshot")
                return
            }
            
            print("Fetched \(documents.count) documents from Firestore")
            
            self.books = documents.compactMap { document in
                do {
                    let book = try document.data(as: MemberBook.self)
                    print("Successfully decoded book: \(book.title)")
                    return book
                } catch {
                    print("Error decoding book document: \(error.localizedDescription)")
                    return nil
                }
            }
            
            print("Successfully loaded \(self.books.count) books")
            
            // Compute genres from books
            let allGenres = Set(self.books.flatMap { book in
                book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            })
            self.genres = Array(allGenres).sorted()
            print("Computed \(self.genres.count) unique genres")
            
            // Set up favorites listener after loading books
            self.setupFavoritesListener()
        }
    }
    
    private func setupFavoritesListener() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No user ID available for favorites listener")
            return
        }
        
        print("Setting up favorites listener for user: \(userID)")
        
        favoritesListener = db.collection("UserFavorites").document(userID).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error in favorites listener: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(),
               let favorites = data["favorites"] as? [String] {
                print("Received favorites update: \(favorites)")
                
                // Update isFavorite status for all books
                for (index, book) in self.books.enumerated() {
                    let wasFavorite = self.books[index].isFavorite
                    self.books[index].isFavorite = favorites.contains(book.isbn)
                    if wasFavorite != self.books[index].isFavorite {
                        print("Updated favorite status for book \(book.title): \(self.books[index].isFavorite)")
                    }
                }
            } else {
                print("No favorites data found or empty favorites array")
                // Reset all favorites to false if no data
                for (index, _) in self.books.enumerated() {
                    self.books[index].isFavorite = false
                }
            }
        }
    }
    
    func updateFavoriteStatus(bookID: String, isFavorite: Bool, completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No user ID available for updating favorite status")
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        print("Updating favorite status for book \(bookID) to \(isFavorite)")
        
        let userFavoritesRef = db.collection("UserFavorites").document(userID)
        
        if isFavorite {
            // Add to favorites
            userFavoritesRef.setData([
                "favorites": FieldValue.arrayUnion([bookID])
            ], merge: true) { error in
                if let error = error {
                    print("Error adding to favorites: \(error.localizedDescription)")
                } else {
                    print("Successfully added book to favorites")
                }
                completion(error)
            }
        } else {
            // Remove from favorites
            userFavoritesRef.updateData([
                "favorites": FieldValue.arrayRemove([bookID])
            ]) { error in
                if let error = error {
                    print("Error removing from favorites: \(error.localizedDescription)")
                } else {
                    print("Successfully removed book from favorites")
                }
                completion(error)
            }
        }
    }
}

