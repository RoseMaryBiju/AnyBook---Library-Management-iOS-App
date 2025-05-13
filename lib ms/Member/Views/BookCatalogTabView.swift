// BookCatalogTabView.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Main View
struct BookCatalogTabView: View {
    // MARK: - Properties
    @ObservedObject var catalogViewModel: MemberCatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedGenres: Set<String> = []
    @State private var showFilterOptions = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("matchAllGenres") private var matchAllGenres = false
    @AppStorage("filterByAuthor") private var filterByAuthor = true
    @AppStorage("showOnlyAvailable") private var showOnlyAvailable = false
    
    // MARK: - Constants
    private let customAccentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24)
    ]
    
    private let availableGenres = [
        "Adult", "Animals", "Audiobook", "British Literature", "Childrens",
        "Classics", "Crime", "Detective", "Fiction", "Juvenile", "Kids",
        "Mystery", "Mystery Thriller", "Picture Books", "Poetry", "Storytime",
        "Thriller", "Young Adult"
    ]
    
    // MARK: - Computed Properties
    private var activeFilterCount: Int {
        var count = 0
        if !selectedGenres.isEmpty { count += selectedGenres.count }
        if matchAllGenres { count += 1 }
        if filterByAuthor { count += 1 }
        if showOnlyAvailable { count += 1 }
        return count
    }
    
    var notableAuthors: [String] {
        let authorBookCounts = Dictionary(grouping: catalogViewModel.books, by: { $0.author })
            .mapValues { $0.count }
        let favoriteAuthors = Set(catalogViewModel.books.filter { $0.isFavorite }.map { $0.author })
        return authorBookCounts
            .filter { $0.value > 1 || favoriteAuthors.contains($0.key) }
            .keys
            .sorted()
            .prefix(7)
            .map { $0 }
    }
    
    var recommendedBooks: [MemberBook] {
        let favoriteBooks = catalogViewModel.books.filter { $0.isFavorite }
        let favoriteGenres = Set(favoriteBooks.flatMap { $0.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } })
        let favoriteAuthors = Set(favoriteBooks.map { $0.author })
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        
        let recommended = catalogViewModel.books.filter { book in
            let bookGenres = Set(book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
            return book.isFavorite ||
                   !bookGenres.intersection(favoriteGenres).isEmpty ||
                   favoriteAuthors.contains(book.author) ||
                   book.createdAt.dateValue() > sixMonthsAgo
        }
        
        return recommended
            .removingDuplicates(by: \.id)
            .shuffled()
            .prefix(6)
            .map { $0 }
    }
    
    // MARK: - Initialization
    init(catalogViewModel: MemberCatalogViewModel, libraryViewModel: LibraryViewModel) {
        self.catalogViewModel = catalogViewModel
        self.libraryViewModel = libraryViewModel
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                
                VStack(spacing: 20) {
                    headerView
                    searchBarView
                    filterOptionsView
                    genresFilterView
                    contentScrollView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onAppear {
            catalogViewModel.loadData()
        }
    }
    
    // MARK: - View Components
    private var backgroundView: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            Color.clear
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            if showFilterOptions {
                                showFilterOptions = false
                            }
                        }
                )
        }
    }
    
    private var headerView: some View {
        Text("Book Catalog")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.top, 10)
    }
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
            
            TextField("Search books by title\(filterByAuthor ? " or author" : "")...", text: $searchText)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            filterButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var filterButton: some View {
        Button(action: { showFilterOptions.toggle() }) {
            ZStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(customAccentColor))
                        .offset(x: 10, y: -10)
                }
            }
            .padding(6)
            .background(customAccentColor)
            .clipShape(Circle())
        }
    }
    
    private var filterOptionsView: some View {
        Group {
            if showFilterOptions {
                VStack(alignment: .leading, spacing: 12) {
                    filterHeader
                    filterOptions
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }
    
    private var filterHeader: some View {
        HStack {
            Text("Filter Options")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: clearFilters) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                    Text("Clear Filters")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(customAccentColor)
                .cornerRadius(12)
            }
        }
    }
    
    private var filterOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToggleChip(
                label: matchAllGenres ? "Match All Genres" : "Match Any Genre",
                isOn: $matchAllGenres,
                accentColor: customAccentColor
            )
            
            ToggleChip(
                label: "Search by Author",
                isOn: $filterByAuthor,
                accentColor: customAccentColor
            )
            
            ToggleChip(
                label: "Available Only",
                isOn: $showOnlyAvailable,
                accentColor: customAccentColor
            )
        }
    }
    
    private var genresFilterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(40)), GridItem(.fixed(40))], spacing: 12) {
                    ForEach(availableGenres, id: \.self) { genre in
                        GenreChip(genre: genre, isSelected: selectedGenres.contains(genre), accentColor: customAccentColor) {
                            if selectedGenres.contains(genre) {
                                selectedGenres.remove(genre)
                            } else {
                                selectedGenres.insert(genre)
                            }
                            if showFilterOptions {
                                showFilterOptions = false
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var contentScrollView: some View {
        ScrollView {
            if catalogViewModel.books.isEmpty && errorMessage == nil {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage: errorMessage)
            } else {
                contentView
            }
        }
        .gesture(
            DragGesture()
                .onChanged { _ in
                    if showFilterOptions {
                        showFilterOptions = false
                    }
                }
        )
    }
    
    // MARK: - Content Views
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredBooks) { book in
                    BookCard(
                        book: book,
                        title: book.title,
                        author: book.author,
                        dueDate: nil,
                        catalogViewModel: catalogViewModel,
                        libraryViewModel: libraryViewModel
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var filteredBooks: [MemberBook] {
        var filtered = catalogViewModel.books
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { book in
                let searchLower = searchText.lowercased()
                return book.title.lowercased().contains(searchLower) ||
                       (filterByAuthor && book.author.lowercased().contains(searchLower))
            }
        }
        
        // Apply genre filters
        if !selectedGenres.isEmpty {
            filtered = filtered.filter { book in
                let bookGenres = Set(book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                if matchAllGenres {
                    return selectedGenres.isSubset(of: bookGenres)
                } else {
                    return !selectedGenres.isDisjoint(with: bookGenres)
                }
            }
        }
        
        // Apply availability filter
        if showOnlyAvailable {
            filtered = filtered.filter { $0.isAvailable }
        }
        
        return filtered
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: customAccentColor))
                .scaleEffect(1.5)
            Text("Loading Books...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(errorMessage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: {
                self.errorMessage = nil
                catalogViewModel.loadData()
            }) {
                Text("Retry")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 180)
                    .background(customAccentColor)
                    .cornerRadius(12)
                    .shadow(radius: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func clearFilters() {
        searchText = ""
        selectedGenres.removeAll()
        matchAllGenres = false
        filterByAuthor = false
        showOnlyAvailable = false
    }
}

// MARK: - Preview Provider
struct BookCatalogTabView_Previews: PreviewProvider {
    static var previews: some View {
        BookCatalogTabView(
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
            .previewDevice("iPhone 14")
            .previewDisplayName("iPhone 14")
    }
}
