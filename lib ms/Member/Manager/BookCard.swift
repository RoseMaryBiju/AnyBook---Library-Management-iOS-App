//
//  BookCard.swift
//  lib ms
//
//  Created by admin12 on 08/05/25.
//


// BookCard.swift
import SwiftUI
import FirebaseFirestore

struct BookCard: View {
    let book: MemberBook
    let title: String
    let author: String
    let dueDate: Date?
    let catalogViewModel: MemberCatalogViewModel
    let libraryViewModel: LibraryViewModel
    
    var body: some View {
        NavigationLink(destination: BooksDetailView(book: book, catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel)) {
            VStack(alignment: .leading, spacing: 8) {
                if let urlString = book.coverImageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 180)
                            .cornerRadius(8)
                    } placeholder: {
                        Image(systemName: "book.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 180)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "book.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 180)
                        .foregroundColor(.gray)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let dueDate = dueDate {
                    Text("Due: \(dueDate, formatter: DateFormatter.shortDate)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

struct BookCard_Previews: PreviewProvider {
    static var previews: some View {
        BookCard(
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
            title: "Sample Book",
            author: "Author",
            dueDate: nil,
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
        .previewDevice("iPhone 14")
    }
}
