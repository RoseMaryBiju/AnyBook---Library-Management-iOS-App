import Foundation
import UIKit
import SwiftCSV
import FirebaseFirestore

// MARK: - Models

struct Author: Identifiable, Codable {
    let id: String
    let name: String
    let birthDate: String?
    let bio: String?
    let image: String?
}

struct OpenLibrarySearchResponse: Codable {
    let numFound: Int
    let docs: [OpenLibraryBookDoc]
}

struct OpenLibraryBookDoc: Codable {
    let author_key: [String]?
    let author_name: [String]?
}

struct OpenLibraryAuthorResponse: Codable {
    let name: String
    let birth_date: String?
    let bio: String?
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

class CatalogViewModel: ObservableObject {
    @Published var totalBooks: Int = 0
    @Published var availableBooks: Int = 0
    @Published var unavailableBooks: Int = 0
    @Published var authors: [Author] = []
    @Published var genres: [String] = []
    @Published var books: [Book] = []

    private let db = Firestore.firestore()
    private let session: URLSession

    // Computed property for total authors
    var totalAuthors: Int {
        return authors.count
    }

    init() {
        self.session = URLSession.shared
        loadData()
    }

    func loadData() {
        db.collection("BooksCatalog").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching books from Firestore: \(error.localizedDescription)")
                self.books = []
                self.totalBooks = 0
                self.availableBooks = 0
                self.unavailableBooks = 0
                self.genres = []
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found in BooksCatalog collection")
                self.books = []
                self.totalBooks = 0
                self.availableBooks = 0
                self.unavailableBooks = 0
                self.genres = []
                return
            }

            print("Snapshot listener fetched \(documents.count) documents")

            self.books = documents.compactMap { doc -> Book? in
                let data = doc.data()
                let isbn = data["isbn"] as? String ?? doc.documentID

                let pages = (data["pages"] as? Int) ?? (Int(data["pages"] as? String ?? "0") ?? 0)
                let numberOfCopies = (data["numberOfCopies"] as? Int) ?? (Int(data["numberOfCopies"] as? String ?? "0") ?? 0)
                let unavailableCopies = (data["unavailableCopies"] as? Int) ?? (Int(data["unavailableCopies"] as? String ?? "0") ?? 0)

                let title = data["title"] as? String ?? "Unknown Title"
                let author = data["author"] as? String ?? "Unknown Author"
                let illustrator = data["illustrator"] as? String
                let genres = data["genres"] as? String ?? ""
                let language = data["language"] as? String ?? "Unknown"
                let bookFormat = data["bookFormat"] as? String ?? "Unknown"
                let edition = data["edition"] as? String ?? "Unknown"
                let publisher = data["publisher"] as? String ?? "Unknown"
                let description = data["summary"] as? String ?? ""
                let isAvailable = data["isAvailable"] as? Bool ?? true
                let createdAt = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
                let isFavorite = data["isFavorite"] as? Bool ?? false
                let coverImageURL = data["coverImageURL"] as? String
                let authorID = data["authorID"] as? String
                let cost = (data["cost"] as? Double) ?? 20.0

                guard !title.isEmpty, !author.isEmpty else {
                    print("Skipping document with ISBN: \(isbn) due to missing title or author")
                    return nil
                }

                return Book(
                    title: title,
                    author: author,
                    illustrator: illustrator,
                    genres: genres,
                    isbn: isbn,
                    language: language,
                    bookFormat: bookFormat,
                    edition: edition,
                    pages: pages,
                    publisher: publisher,
                    description: description,
                    isAvailable: isAvailable,
                    createdAt: createdAt,
                    isFavorite: isFavorite,
                    numberOfCopies: numberOfCopies,
                    unavailableCopies: unavailableCopies,
                    coverImageURL: coverImageURL,
                    authorID: authorID,
                    cost: cost
                )
            }.sorted { $0.title < $1.title }

            self.totalBooks = self.books.count
            self.availableBooks = self.books.filter { $0.isAvailable && $0.numberOfCopies > 0 }.count
            self.unavailableBooks = self.books.filter { $0.unavailableCopies >= 1 }.count

            self.genres = self.books
                .filter { $0.isAvailable && $0.numberOfCopies > 0 }
                .flatMap { $0.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                .removingDuplicates()
                .sorted()

            self.loadAuthors()
        }
    }

    private func loadAuthors() {
        db.collection("AuthorsData").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching authors from Firestore: \(error.localizedDescription)")
                self.authors = []
                return
            }

            guard let documents = snapshot?.documents else {
                print("No authors found in AuthorsData collection")
                self.authors = []
                return
            }

            self.authors = documents.compactMap { doc -> Author? in
                let data = doc.data()
                let id = doc.documentID
                guard let name = data["name"] as? String else {
                    print("Skipping author with ID \(id) due to missing name")
                    return nil
                }
                return Author(
                    id: id,
                    name: name,
                    birthDate: data["birth_date"] as? String,
                    bio: data["bio"] as? String,
                    image: data["image"] as? String
                )
            }.sorted { $0.name < $1.name }
        }
    }

    func updateAuthorDetails() {
        db.collection("BooksCatalog").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching books for author update: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No books found in BooksCatalog collection")
                return
            }
            
            var delay: Double = 0
            for doc in documents {
                let data = doc.data()
                let isbn = data["isbn"] as? String ?? doc.documentID
                
                if let authorID = data["authorID"] as? String {
                    print("AuthorID \(authorID) already exists for book with ISBN: \(isbn), proceeding to fetch and store author details...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchAndStoreAuthorDetails(olid: authorID)
                    }
                    delay += 1.0
                    continue
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.fetchAuthorOLID(isbn: isbn) { result in
                        switch result {
                        case .success(let olid):
                            self.db.collection("BooksCatalog").document(isbn).updateData([
                                "authorID": olid
                            ]) { error in
                                if let error = error {
                                    print("Error updating authorID for ISBN \(isbn): \(error.localizedDescription)")
                                } else {
                                    print("Updated authorID \(olid) for ISBN \(isbn)")
                                }
                            }
                            self.fetchAndStoreAuthorDetails(olid: olid)
                        case .failure(let error):
                            print("Failed to fetch author OLID for ISBN \(isbn): \(error.localizedDescription)")
                        }
                    }
                }
                delay += 1.0
            }
        }
    }

    private func fetchAuthorOLID(isbn: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://openlibrary.org/search.json?isbn=\(isbn)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(OpenLibrarySearchResponse.self, from: data)
                guard let doc = searchResponse.docs.first,
                      let authorKey = doc.author_key?.first else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Author OLID not found for ISBN \(isbn)"])))
                    return
                }
                completion(.success(authorKey))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func fetchAndStoreAuthorDetails(olid: String) {
        db.collection("AuthorsData").document(olid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking AuthorsData for OLID \(olid): \(error.localizedDescription)")
                return
            }
            
            if snapshot?.exists == true {
                print("Author with OLID \(olid) already exists in AuthorsData, skipping...")
                return
            }
            
            let urlString = "https://openlibrary.org/authors/\(olid).json"
            guard let url = URL(string: urlString) else {
                print("Invalid URL for author OLID \(olid)")
                return
            }
            
            self.session.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error fetching author details for OLID \(olid): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received for author OLID \(olid)")
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let authorResponse = try decoder.decode(OpenLibraryAuthorResponse.self, from: data)
                    
                    let imageURL = "https://covers.openlibrary.org/a/olid/\(olid)-M.jpg"
                    
                    let authorData: [String: Any] = [
                        "name": authorResponse.name,
                        "birth_date": authorResponse.birth_date ?? "Unknown",
                        "bio": authorResponse.bio ?? "No bio available.",
                        "image": imageURL
                    ]
                    
                    self.db.collection("AuthorsData").document(olid).setData(authorData) { error in
                        if let error = error {
                            print("Error storing author details for OLID \(olid): \(error.localizedDescription)")
                        } else {
                            print("Stored author details for OLID \(olid)")
                        }
                    }
                } catch {
                    print("Error decoding author details for OLID \(olid): \(error.localizedDescription)")
                }
            }.resume()
        }
    }

    func fetchUnavailableBooks() -> [Book] {
        return books.filter { $0.unavailableCopies >= 1 }.sorted { $0.title < $1.title }
    }

    func getBookCoverImageURL(_ book: Book) -> URL? {
        guard let urlString = book.coverImageURL, !urlString.isEmpty else {
            print("No cover image URL for book \(book.title)")
            return nil
        }

        let adjustedURLString: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            adjustedURLString = urlString
        } else if urlString.hasPrefix("res.cloudinary.com") {
            adjustedURLString = "https://" + urlString
        } else {
            print("Invalid cover image URL for book \(book.title): \(urlString)")
            return nil
        }

        guard let url = URL(string: adjustedURLString) else {
            print("Failed to create URL from string for book \(book.title): \(adjustedURLString)")
            return nil
        }

        return url
    }

    func getBooksByAuthor(_ author: String) -> [Book] {
        return books.filter { $0.author == author }
    }

    func getBooksByAuthorID(_ authorID: String) -> [Book] {
        return books.filter { $0.authorID == authorID }
    }

    func updateBookAvailability(_ book: Book, isAvailable: Bool, copiesToChange: Int) {
        guard copiesToChange > 0 else {
            print("Invalid number of copies to change: \(copiesToChange)")
            return
        }
        
        var updatedUnavailableCopies = book.unavailableCopies
        if isAvailable {
            // Mark copies as available (decrease unavailableCopies)
            updatedUnavailableCopies = max(0, book.unavailableCopies - copiesToChange)
        } else {
            // Mark copies as unavailable (increase unavailableCopies)
            updatedUnavailableCopies = min(book.numberOfCopies, book.unavailableCopies + copiesToChange)
        }
        
        let updatedIsAvailable = (book.numberOfCopies - updatedUnavailableCopies) > 0
        
        // Update Firestore
        db.collection("BooksCatalog").document(book.isbn).updateData([
            "unavailableCopies": updatedUnavailableCopies,
            "isAvailable": updatedIsAvailable
        ]) { error in
            if let error = error {
                print("Error updating book availability: \(error.localizedDescription)")
            } else {
                print("Book availability updated: unavailableCopies = \(updatedUnavailableCopies), isAvailable = \(updatedIsAvailable)")
                // Update local counts
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.availableBooks = self.books.filter { $0.isAvailable && $0.numberOfCopies > 0 }.count
                    self.unavailableBooks = self.books.filter { $0.unavailableCopies >= 1 }.count
                }
            }
        }
    }
}
