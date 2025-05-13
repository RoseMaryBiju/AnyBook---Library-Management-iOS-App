import SwiftUI

struct BooksListView: View {
    @ObservedObject var viewModel: CatalogViewModel
    @State private var searchText: String = ""
    @State private var showingAddBook = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                
                scrollViewContent
            }
            .navigationTitle("Books")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddBook = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddBook, onDismiss: {
                // No need to manually refresh; snapshot listener in viewModel will handle updates
            }) {
                AddBookView()
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
    
    private var scrollViewContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ForEach(filteredSectionedBooks, id: \.letter) { section in
                    SectionView(section: section, viewModel: viewModel)
                        .id(section.letter)
                }
            }
            .overlay(indexOverlay(proxy: proxy), alignment: .trailing)
        }
    }
    
    private struct SectionView: View {
        let section: (letter: String, books: [Book])
        let viewModel: CatalogViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Self.sectionHeader(for: section.letter)
                
                ForEach(Array(section.books.enumerated()), id: \.offset) { index, book in
                    BookRowView(book: book, showDivider: index < section.books.count - 1, viewModel: viewModel)
                }
            }
            .background(Color(.systemBackground))
        }
        
        static func sectionHeader(for letter: String) -> some View {
            Text(letter.uppercased())
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.vertical, 4)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
        }
    }
    
    private struct BookRowView: View {
        let book: Book
        let showDivider: Bool
        let viewModel: CatalogViewModel
        
        var body: some View {
            VStack(spacing: 0) {
                NavigationLink(destination: BookDetailView(viewModel: viewModel, book: book)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.body)
                            .foregroundColor(.primary)
                        Text("Author: \(book.author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Availability: \(book.isAvailable && book.numberOfCopies > 0 ? "Available" : "Not Available")")
                            .font(.subheadline)
                            .foregroundColor(book.isAvailable && book.numberOfCopies > 0 ? .green : .red)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
                
                if showDivider {
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
    
    private func indexOverlay(proxy: ScrollViewProxy) -> some View {
        IndexView(items: filteredSectionedBooks.map { $0.letter }, scrollToLetter: { letter in
            withAnimation {
                proxy.scrollTo(letter, anchor: .top)
            }
        })
        .frame(maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 5)
    }
    
    private var filteredSectionedBooks: [(letter: String, books: [Book])] {
        let filteredBooks = searchText.isEmpty ? viewModel.books : viewModel.books.filter {
            $0.title.lowercased().contains(searchText.lowercased())
        }
        let grouped = Dictionary(grouping: filteredBooks) { book in
            let firstChar = book.title.first ?? Character("A")
            return String(firstChar.uppercased())
        }
        return grouped.map { (letter: $0.key, books: $0.value) }
            .sorted { $0.letter < $1.letter }
    }
}

struct BooksListView_Previews: PreviewProvider {
    static var previews: some View {
        BooksListView(viewModel: CatalogViewModel())
    }
}

struct IndexView<S: Sequence>: View where S.Element: Hashable {
    let items: S
    let scrollToLetter: (String) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(items), id: \.self) { item in
                Button(action: {
                    scrollToLetter(String(describing: item))
                }) {
                    Text(String(describing: item))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.vertical, 1)
                }
            }
        }
        .frame(width: 20)
    }
}
