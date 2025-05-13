import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct AdminCatalogManagementView: View {
    @State private var books: [AdminBook] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var selectedGenres: Set<String> = []
    @State private var showFilterOptions = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("matchAllGenres") private var matchAllGenres = false
    @AppStorage("filterByAuthor") private var filterByAuthor = true
    @AppStorage("showOnlyAvailable") private var showOnlyAvailable = false
    @AppStorage("showOnlyUnavailable") private var showOnlyUnavailable = false
    @AppStorage("showOnlyBorrowed") private var showOnlyBorrowed = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
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
    
    private var activeFilterCount: Int {
        var count = 0
        if !selectedGenres.isEmpty { count += selectedGenres.count }
        if matchAllGenres { count += 1 }
        if filterByAuthor { count += 1 }
        if showOnlyAvailable { count += 1 }
        if showOnlyUnavailable { count += 1 }
        if showOnlyBorrowed { count += 1 }
        return count
    }
    
    var filteredBooks: [AdminBook] {
        let lowercasedSearchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return books.filter { book in
            let matchesSearch: Bool
            if lowercasedSearchText.isEmpty {
                matchesSearch = true
            } else {
                let titleMatch = book.title.lowercased().contains(lowercasedSearchText)
                let authorMatch = filterByAuthor ? book.author.lowercased().contains(lowercasedSearchText) : false
                matchesSearch = titleMatch || authorMatch
            }
            
            let matchesGenre: Bool
            if selectedGenres.isEmpty {
                matchesGenre = true
            } else {
                matchesGenre = matchAllGenres ?
                    selectedGenres.allSatisfy { book.genres.contains($0) } :
                    book.genres.contains { selectedGenres.contains($0) }
            }
            
            let matchesAvailability: Bool
            if showOnlyAvailable {
                matchesAvailability = book.isAvailable
            } else if showOnlyUnavailable {
                matchesAvailability = !book.isAvailable
            } else if showOnlyBorrowed {
                matchesAvailability = book.borrowedCopies > 0
            } else {
                matchesAvailability = true
            }
            
            return matchesSearch && matchesGenre && matchesAvailability
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Set background to systemBackground
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Background tap to dismiss filter card
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
                
                VStack(spacing: 20) {
                    // Header
                    Text("Catalog Management")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                        
                        TextField("Search books by title\(filterByAuthor ? " or author" : "")...", text: $searchText)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: { showFilterOptions.toggle() }) {
                            ZStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                
                                if activeFilterCount > 0 {
                                    Text("\(activeFilterCount)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Circle().fill(customAccentColor))
                                        .offset(x: 12, y: -12)
                                }
                            }
                            .padding(8)
                            .background(customAccentColor)
                            .clipShape(Circle())
                        }
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
                    .contentShape(Rectangle())
                    .gesture(TapGesture().onEnded { })
                    
                    // Filter Options
                    if showFilterOptions {
                        VStack(alignment: .leading, spacing: 12) {
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
                            
                            Divider()
                                .background(customAccentColor.opacity(0.3))
                            
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
                                    accentColor: customAccentColor,
                                    onToggle: {
                                        if showOnlyAvailable {
                                            showOnlyUnavailable = false
                                            showOnlyBorrowed = false
                                        }
                                    }
                                )
                                
                                ToggleChip(
                                    label: "Unavailable Only",
                                    isOn: $showOnlyUnavailable,
                                    accentColor: customAccentColor,
                                    onToggle: {
                                        if showOnlyUnavailable {
                                            showOnlyAvailable = false
                                            showOnlyBorrowed = false
                                        }
                                    }
                                )
                                
                                ToggleChip(
                                    label: "Borrowed Only",
                                    isOn: $showOnlyBorrowed,
                                    accentColor: customAccentColor,
                                    onToggle: {
                                        if showOnlyBorrowed {
                                            showOnlyAvailable = false
                                            showOnlyUnavailable = false
                                        }
                                    }
                                )
                            }
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
                        // Prevent taps inside the filter card from closing it
                        .contentShape(Rectangle())
                        .gesture(TapGesture().onEnded { })
                    }
                    
                    // Genres Filter
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
                    
                    // Book Grid
                    ScrollView {
                        if filteredBooks.isEmpty && !books.isEmpty {
                            Text("No books match the current filters.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        } else {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(filteredBooks) { book in
                                    NavigationLink(destination: AdminBookDetailView(book: book)) {
                                        AdminBookCard(book: book)
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal)
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
                
                // Loading Overlay
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: customAccentColor))
                                .scaleEffect(1.5)
                            Text("Loading Books...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 12)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onAppear {
            fetchBooks()
        }
    }
    
    private func fetchBooks() {
        isLoading = true
        db.collection("BooksCatalog").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Failed to fetch books: \(error.localizedDescription)"
                return
            }
            
            guard let documents = snapshot?.documents else {
                errorMessage = "No books found"
                return
            }
            
            books = documents.compactMap { document in
                let data = document.data()
                let coverImageURL = data["coverImageURL"] as? String ?? ""
                
                let createdDate: String
                if let timestamp = data["createdAt"] as? Timestamp {
                    let date = timestamp.dateValue()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a zzz"
                    formatter.timeZone = TimeZone(identifier: "UTC+05:30")
                    createdDate = formatter.string(from: date)
                } else {
                    createdDate = data["createdAt"] as? String ?? "Unknown"
                }
                
                let totalCopies = data["numberOfCopies"] as? Int ?? 0
                let borrowedCopies = data["borrowedCopies"] as? Int ?? 0
                let availableCopies = max(0, totalCopies - borrowedCopies)
                
                let genresString = data["genres"] as? String ?? ""
                let genresArray = genresString
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                return AdminBook(
                    id: document.documentID,
                    title: data["title"] as? String ?? "",
                    author: data["author"] as? String ?? "",
                    genres: genresArray,
                    coverImageURL: coverImageURL,
                    description: data["summary"] as? String ?? "",
                    dueDate: data["dueDate"] as? String,
                    isAvailable: availableCopies > 0,
                    totalCopies: totalCopies,
                    borrowedCopies: borrowedCopies,
                    availableCopies: availableCopies,
                    createdDate: createdDate
                )
            }
        }
    }
    
    private func clearFilters() {
        searchText = ""
        selectedGenres.removeAll()
        matchAllGenres = false
        filterByAuthor = false
        showOnlyAvailable = false
        showOnlyUnavailable = false
        showOnlyBorrowed = false
    }
}

struct GenreChip: View {
    let genre: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(genre)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? accentColor : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

struct ToggleChip: View {
    let label: String
    @Binding var isOn: Bool
    let accentColor: Color
    let onToggle: (() -> Void)?
    
    init(label: String, isOn: Binding<Bool>, accentColor: Color, onToggle: (() -> Void)? = nil) {
        self.label = label
        self._isOn = isOn
        self.accentColor = accentColor
        self.onToggle = onToggle
    }
    
    var body: some View {
        Button(action: {
            isOn.toggle()
            onToggle?()
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? accentColor : Color.gray.opacity(0.2))
                        .frame(width: 40, height: 24)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .offset(x: isOn ? 8 : -8)
                }
                
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isOn ? accentColor : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct AdminBookCard: View {
    let book: AdminBook
    @AppStorage("isDarkMode") private var isDarkMode = false
    private let customAccentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: book.coverImageURL)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color(.secondarySystemBackground)
                            Image(systemName: "book.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(customAccentColor.opacity(0.5))
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            Color(.secondarySystemBackground)
                            Image(systemName: "book.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(customAccentColor.opacity(0.5))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 140, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                Text(book.isAvailable ? "Available" : "Borrowed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(book.isAvailable ? Color.green : Color.red)
                    )
                    .padding(10)
            }
            
            Text(book.title.isEmpty ? "Unknown Title" : book.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            Text(book.author.isEmpty ? "Unknown Author" : book.author)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .padding()
        .frame(width: 180, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct AdminBook: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let genres: [String]
    let coverImageURL: String
    let description: String
    let dueDate: String?
    let isAvailable: Bool
    let totalCopies: Int
    let borrowedCopies: Int
    let availableCopies: Int
    let createdDate: String
}

struct AdminCatalogManagementView_Previews: PreviewProvider {
    static var previews: some View {
        AdminCatalogManagementView()
    }
}
