// SearchBooksView.swift
import SwiftUI

struct SearchBooksView: View {
    @ObservedObject var catalogViewModel: MemberCatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var searchText = ""
    
    var filteredBooks: [MemberBook] {
        let searchTerms = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        if searchTerms.isEmpty {
            return catalogViewModel.books
        }
        
        return catalogViewModel.books.filter { book in
            let bookTitle = book.title.lowercased()
            let bookAuthor = book.author.lowercased()
            let bookGenres = book.genres.lowercased()
            
            // Check if all search terms match any of the book properties
            return searchTerms.allSatisfy { term in
                // Check for exact matches first
                let exactTitleMatch = bookTitle == term
                let exactAuthorMatch = bookAuthor == term
                let exactGenreMatch = bookGenres.components(separatedBy: ",").contains { $0.trimmingCharacters(in: .whitespaces) == term }
                
                // If no exact match, check for partial matches
                if !exactTitleMatch && !exactAuthorMatch && !exactGenreMatch {
                    let partialTitleMatch = bookTitle.contains(term)
                    let partialAuthorMatch = bookAuthor.contains(term)
                    let partialGenreMatch = bookGenres.components(separatedBy: ",").contains { 
                        $0.trimmingCharacters(in: .whitespaces).contains(term)
                    }
                    
                    return partialTitleMatch || partialAuthorMatch || partialGenreMatch
                }
                
                return true
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search by title, author, or genre", text: $searchText)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.black)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    if searchText.isEmpty {
                        placeholderView
                    } else if filteredBooks.isEmpty {
                        noResultsView
                    } else {
                        resultsView
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Search Books")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var placeholderView: some View {
        VStack {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            Text("Search for books by title, author, or genre")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack {
            Image(systemName: "book.closed")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            Text("No books found for '\(searchText)'")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredBooks) { book in
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
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        
                        if book.isAvailable && book.numberOfCopies > 0 {
                            ReserveButton(
                                bookID: book.isbn,
                                catalogViewModel: catalogViewModel,
                                libraryViewModel: libraryViewModel
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

struct SearchBooksView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBooksView(
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
        .previewDevice("iPhone 14")
    }
}
