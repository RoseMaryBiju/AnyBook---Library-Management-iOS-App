// MemberSectionView.swift
import SwiftUI
import FirebaseFirestore

struct MemberSectionView: View {
    let title: String
    let books: [MemberBook]
    let emptyMessage: String
    let catalogViewModel: MemberCatalogViewModel
    let libraryViewModel: LibraryViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            
            if books.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(200))], spacing: 16) {
                        ForEach(books) { book in
                            VStack {
                                NavigationLink {
                                    BooksDetailView(
                                        book: book,
                                        catalogViewModel: catalogViewModel,
                                        libraryViewModel: libraryViewModel
                                    )
                                } label: {
                                    BookCard(
                                        book: book,
                                        title: book.title,
                                        author: book.author,
                                        dueDate: nil,
                                        catalogViewModel: catalogViewModel,
                                        libraryViewModel: libraryViewModel
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                if book.isAvailable && book.numberOfCopies > 0 {
                                    ReserveButton(
                                        bookID: book.isbn,
                                        catalogViewModel: catalogViewModel,
                                        libraryViewModel: libraryViewModel
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct MemberSectionView_Previews: PreviewProvider {
    static var previews: some View {
        MemberSectionView(
            title: "Sample Section",
            books: [
                MemberBook(
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
                )
            ],
            emptyMessage: "No books found.",
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
        .previewDevice("iPhone 14")
    }
}
