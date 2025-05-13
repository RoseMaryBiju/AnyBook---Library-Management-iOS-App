import SwiftUI

struct MemberExplore: View {
    @StateObject private var catalogViewModel = MemberCatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var darkModeManager = DarkModeManager.shared
    @State private var searchText = ""
    @State private var selectedGenre: String?
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Genre Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(catalogViewModel.genres, id: \.self) { genre in
                            GenreButton(
                                genre: genre,
                                isSelected: selectedGenre == genre,
                                action: {
                                    if selectedGenre == genre {
                                        selectedGenre = nil
                                    } else {
                                        selectedGenre = genre
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Book Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredBooks) { book in
                            NavigationLink(destination: BooksDetailView(
                                book: book,
                                catalogViewModel: catalogViewModel,
                                libraryViewModel: libraryViewModel
                            )) {
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
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedGenre: $selectedGenre,
                    genres: catalogViewModel.genres
                )
            }
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
    
    private var filteredBooks: [MemberBook] {
        var filtered = catalogViewModel.books
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { book in
                book.title.lowercased().contains(searchText.lowercased()) ||
                book.author.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply genre filter
        if let selectedGenre = selectedGenre {
            filtered = filtered.filter { book in
                book.genres.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .contains(selectedGenre)
            }
        }
        
        return filtered
    }
}

struct GenreButton: View {
    let genre: String
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var darkModeManager = DarkModeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(genre)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : (darkModeManager.isDarkMode ? Color(.systemGray6) : Color(.systemGray6)))
                .foregroundColor(isSelected ? .white : (darkModeManager.isDarkMode ? .white : .primary))
                .cornerRadius(20)
        }
    }
}

struct FilterView: View {
    @Binding var selectedGenre: String?
    let genres: [String]
    @StateObject private var darkModeManager = DarkModeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Genres")) {
                    ForEach(genres, id: \.self) { genre in
                        Button(action: {
                            if selectedGenre == genre {
                                selectedGenre = nil
                            } else {
                                selectedGenre = genre
                            }
                        }) {
                            HStack {
                                Text(genre)
                                Spacer()
                                if selectedGenre == genre {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(darkModeManager.isDarkMode ? .white : .primary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
}

struct MemberExplore_Previews: PreviewProvider {
    static var previews: some View {
        MemberExplore()
            .previewDevice("iPhone 14")
    }
}
