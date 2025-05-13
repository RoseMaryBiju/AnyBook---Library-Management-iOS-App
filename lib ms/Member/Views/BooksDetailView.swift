// BooksDetailView.swift
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BooksDetailView: View {
    let book: MemberBook
    @State private var isFavorite: Bool
    @ObservedObject var catalogViewModel: MemberCatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private let customAccentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    private let buttonGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.3, green: 0.5, blue: 0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    init(book: MemberBook, catalogViewModel: MemberCatalogViewModel, libraryViewModel: LibraryViewModel) {
        self.book = book
        self._isFavorite = State(initialValue: book.isFavorite)
        self.catalogViewModel = catalogViewModel
        self.libraryViewModel = libraryViewModel
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Book Cover Image
                    if let urlString = book.coverImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .padding(.bottom, 4)
                        } placeholder: {
                            Image(systemName: "book.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.vertical)
                        }
                    } else {
                        Image(systemName: "book.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.vertical)
                    }
                    
                    // Book Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(book.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("By \(book.author)")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        if let illustrator = book.illustrator, !illustrator.isEmpty {
                            Text("Illustrated by \(illustrator)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Genre Tags
                        HStack(spacing: 8) {
                            let genreArray = book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            if genreArray.isEmpty {
                                Text("No genres")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(customAccentColor.opacity(0.2))
                                    .cornerRadius(8)
                            } else {
                                ForEach(genreArray.prefix(4), id: \.self) { genre in
                                    Text(genre)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(customAccentColor.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            // Heart Button
                            Button(action: {
                                print("Heart button tapped for book: \(book.title)")
                                let newFavoriteStatus = !isFavorite
                                print("Setting favorite status to: \(newFavoriteStatus)")
                                
                                // Update UI immediately
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isFavorite = newFavoriteStatus
                                }
                                
                                // Update in Firestore
                                catalogViewModel.updateFavoriteStatus(bookID: book.isbn, isFavorite: newFavoriteStatus) { error in
                                    if let error = error {
                                        print("Error updating favorite status: \(error.localizedDescription)")
                                        // Revert UI on error
                                        DispatchQueue.main.async {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                isFavorite = !newFavoriteStatus
                                            }
                                        }
                                    } else {
                                        print("Successfully updated favorite status in Firestore")
                                    }
                                }
                            }) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(isFavorite ? .red : .gray)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            // Reserve Button (if available)
                            if book.isAvailable && book.numberOfCopies > 0 {
                                ReserveButton(
                                    bookID: book.isbn,
                                    catalogViewModel: catalogViewModel,
                                    libraryViewModel: libraryViewModel
                                )
                            }
                        }
                        .padding(.bottom, 20)
                        
                        Text("ISBN: \(book.isbn)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Language: \(book.language)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Format: \(book.bookFormat)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Edition: \(book.edition)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Pages: \(book.pages)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Publisher: \(book.publisher)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Cost: $\(String(format: "%.2f", book.cost))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Availability: \(book.isAvailable ? "Available" : "Not Available")")
                            .font(.subheadline)
                            .foregroundColor(book.isAvailable ? .green : .red)
                        
                        Text("Copies: \(book.numberOfCopies) (Unavailable: \(book.unavailableCopies))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Added on: \(dateFormatter.string(from: book.createdAt.dateValue()))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Favorite: \(isFavorite ? "Yes" : "No")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(book.description.isEmpty ? "No summary available." : book.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineLimit(5)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Spacer to ensure content is scrollable
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("BooksDetailView appeared for book: \(book.title)")
            // Update isFavorite from the catalog view model
            if let updatedBook = catalogViewModel.books.first(where: { $0.isbn == book.isbn }) {
                print("Found updated book in catalog, favorite status: \(updatedBook.isFavorite)")
                isFavorite = updatedBook.isFavorite
            } else {
                print("Book not found in catalog")
            }
        }
    }
}

struct BooksDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BooksDetailView(
            book: MemberBook(
                title: "Sample Book",
                author: "Author",
                illustrator: nil,
                genres: "Fiction",
                isbn: "123456",
                language: "English",
                bookFormat: "Hardcover",
                edition: "1st",
                pages: 300,
                publisher: "Publisher",
                description: "A sample book.",
                isAvailable: true,
                createdAt: Timestamp(date: Date()),
                isFavorite: false,
                numberOfCopies: 5,
                unavailableCopies: 1,
                coverImageURL: nil,
                authorID: nil,
                cost: 20.0
            ),
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
        .previewDevice("iPhone 14")
    }
}
