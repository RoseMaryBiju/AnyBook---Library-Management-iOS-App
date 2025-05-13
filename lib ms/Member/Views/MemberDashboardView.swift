import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Charts

struct HomePage: View {
    let role: String
    @State private var isLoading = false
    @State private var showLogin = false
    @State private var errorMessage = ""
    @State private var showChatbot = false
    @StateObject private var darkModeManager = DarkModeManager.shared
    
    var body: some View {
        ZStack {
            TabView {
                HomeTabView(role: role, logoutAction: logout)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                BookCatalogTabView(catalogViewModel: MemberCatalogViewModel(), libraryViewModel: LibraryViewModel())
                    .tabItem {
                        Label("Explore", systemImage: "magnifyingglass")
                    }
                
                MyBooksTabView()
                    .tabItem {
                        Label("Mybooks", systemImage: "book.fill")
                    }
            }
            .accentColor(.blue)
            .overlay(
                isLoading ? ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    : nil
            )
            .fullScreenCover(isPresented: $showLogin) {
                LoginView()
            }
            // Floating Chatbot Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showChatbot = true }) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 140)
                    .accessibilityLabel("Open Chatbot")
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showChatbot) {
            BooksLibraryFAQBotView()
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
    
    private func logout() {
        isLoading = true
        errorMessage = ""
        
        do {
            try Auth.auth().signOut()
            isLoading = false
            showLogin = true
        } catch let error {
            isLoading = false
            errorMessage = "Logout failed: \(error.localizedDescription)"
        }
    }
}

// Home Tab View
struct HomeTabView: View {
    let role: String
    let logoutAction: () -> Void
    @StateObject private var catalogViewModel = MemberCatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var darkModeManager = DarkModeManager.shared
    @State private var username: String = "User"
    @State private var isLoaded = false
    @State private var showProfile = false
    @State private var selectedEvent: Event?
    @State private var showingEventDetail = false
    @State private var recommendationOffset: CGFloat = 50
    @State private var recommendationOpacity: Double = 0
    @State private var isRefreshing = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning,"
        case 12..<17:
            return "Good Afternoon,"
        default:
            return "Good Evening,"
        }
    }
    
    var recommendedBooks: [MemberBook] {
        let favoriteBooks = catalogViewModel.books.filter { $0.isFavorite }
        let favoriteGenres = Set(favoriteBooks.flatMap { $0.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } })
        let favoriteAuthors = Set(favoriteBooks.map { $0.author })
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        
        let recommended = catalogViewModel.books.filter { book in
            let bookGenres = Set(book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
            return book.isFavorite ||
                   !bookGenres.intersection(favoriteGenres).isEmpty ||
                   favoriteAuthors.contains(book.author) ||
                   book.createdAt.dateValue() > threeMonthsAgo
        }
        
        return recommended
            .removingDuplicates(by: \.id)
            .sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
            .prefix(8)
            .map { $0 }
    }
    
    private var myRequests: [BookRequest] {
        guard let userID = Auth.auth().currentUser?.uid else { return [] }
        return libraryViewModel.bookRequests.filter { $0.memberID == userID }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), darkModeManager.isDarkMode ? Color.black : Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    RefreshControl(coordinateSpace: .named("refresh")) { refresh in
                        isRefreshing = true
                        // Reload all data
                        libraryViewModel.fetchBorrowedBooks()
                        libraryViewModel.loadUpcomingEvents()
                        catalogViewModel.loadData()
                        fetchUsername()
                        
                        // Simulate network delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isRefreshing = false
                            refresh.wrappedValue = false
                        }
                    }
                    
                    VStack(spacing: 20) {
                        headerSection
                        quickStatsSection
                        borrowedBooksSection
                        eventsSection
                        recommendationsSection
                    }
                    .padding(.bottom, 20)
                }
                .coordinateSpace(name: "refresh")
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfile) {
                ProfileTabView(role: role, logoutAction: logoutAction)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let selectedEvent = selectedEvent {
                    EventDetailView(
                        event: selectedEvent,
                        onDelete: { libraryViewModel.loadUpcomingEvents() },
                        onEdit: { libraryViewModel.loadUpcomingEvents() }
                    )
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isLoaded = true
                    recommendationOffset = 0
                    recommendationOpacity = 1
                }
                libraryViewModel.fetchBorrowedBooks()
                libraryViewModel.loadUpcomingEvents()
                catalogViewModel.loadData()
                fetchUsername()
            }
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateFormatter.string(from: Date()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(isLoaded ? 1 : 0)
                    .offset(y: isLoaded ? 0 : 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getTimeBasedGreeting())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(darkModeManager.isDarkMode ? .blue : .black)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                    
                    Text(username)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(darkModeManager.isDarkMode ? .blue : .black)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isLoaded)
            
            Spacer()
            
            Button(action: { showProfile = true }) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(darkModeManager.isDarkMode ? .blue : .black)
                    .overlay(
                        Circle()
                            .stroke(darkModeManager.isDarkMode ? Color.blue : Color.black, lineWidth: 2)
                            .frame(width: 56, height: 56)
                    )
                    .scaleEffect(isLoaded ? 1 : 0.5)
                    .opacity(isLoaded ? 1 : 0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isLoaded)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                StatCard(
                    title: "Books Read",
                    value: "\(libraryViewModel.transactions.filter { $0.status == "returned" }.count)",
                    icon: "book.fill",
                    color: .blue,
                    isNavigable: false,
                    isLoaded: isLoaded
                )
                .scaleEffect(isLoaded ? 1 : 0.8)
                .opacity(isLoaded ? 1 : 0)
                
                StatCard(
                    title: "Borrowed",
                    value: "\(libraryViewModel.borrowedBooks.count)",
                    icon: "book.closed.fill",
                    color: .green,
                    isNavigable: false,
                    isLoaded: isLoaded
                )
                .scaleEffect(isLoaded ? 1 : 0.8)
                .opacity(isLoaded ? 1 : 0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: isLoaded)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        var currentDate = today
        
        let returnedTransactions = libraryViewModel.transactions.filter { $0.status == "returned" }
        
        while true {
            let hasReturnedBook = returnedTransactions.contains { transaction in
                if let returnDate = transaction.returnDate {
                    return calendar.isDate(returnDate.dateValue(), inSameDayAs: currentDate)
                }
                return false
            }
            
            if hasReturnedBook {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var borrowedBooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Borrowed Books")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if libraryViewModel.borrowedBooks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No books currently borrowed")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 200, height: 200)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    } else {
                        ForEach(libraryViewModel.borrowedBooks) { borrowedBook in
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: URL(string: borrowedBook.book.coverImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 120, height: 180)
                                .cornerRadius(8)
                                
                                Text(borrowedBook.book.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .frame(width: 120)
                                
                                Text("Due: \(dateFormatter.string(from: borrowedBook.transaction.dueDate.dateValue()))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .scaleEffect(isLoaded ? 1 : 0.8)
                            .opacity(isLoaded ? 1 : 0)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: libraryViewModel.borrowedBooks)
            }
        }
        .padding(.top, 20)
    }
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                if libraryViewModel.upcomingEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No upcoming events available")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                } else {
                    ForEach(libraryViewModel.upcomingEvents.prefix(4), id: \.id) { event in
                        EventRow(
                            event: event,
                            onTap: {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        )
                        .scaleEffect(isLoaded ? 1 : 0.8)
                        .opacity(isLoaded ? 1 : 0)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        
                        if libraryViewModel.upcomingEvents.prefix(4).last.map({ $0.id != event.id }) ?? false {
                            Divider()
                                .padding(.horizontal, 40)
                        }
                    }
                }
                
                NavigationLink(destination: MemberEventsView()) {
                    HStack {
                        Text("See All Events")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .padding(.top, 20)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended for You")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recommendedBooks) { book in
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
                                .overlay(
                                    ZStack {
                                        if book.isFavorite {
                                            Image(systemName: "heart.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 24))
                                                .padding(8)
                                                .background(Circle().fill(Color.white.opacity(0.9)))
                                                .offset(x: 60, y: -60)
                                                .shadow(radius: 2)
                                        }
                                    }
                                )
                                .scaleEffect(isLoaded ? 1 : 0.8)
                                .opacity(isLoaded ? 1 : 0)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .offset(y: recommendationOffset)
                        .opacity(recommendationOpacity)
                    }
                }
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: recommendedBooks)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
    
    private func fetchUsername() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), let name = data["name"] as? String {
                DispatchQueue.main.async {
                    self.username = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }
}

// Member Events View
struct MemberEventsView: View {
    @StateObject private var viewModel = MemberEventsViewModel()
    @State private var selectedEvent: Event?
    @State private var showingEventDetail = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            if viewModel.upcomingEvents.isEmpty {
                VStack {
                    Image(systemName: "calendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                    Text("No upcoming events available")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.upcomingEvents) { event in
                    EventRow(
                        event: event,
                        onTap: {
                            selectedEvent = event
                            showingEventDetail = true
                        }
                    )
                }
            }
        }
        .navigationTitle("Upcoming Events")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchUpcomingEvents()
        }
        .sheet(isPresented: $showingEventDetail) {
            if let selectedEvent = selectedEvent {
                EventDetailView(
                    event: selectedEvent,
                    onDelete: {
                        viewModel.fetchUpcomingEvents()
                    },
                    onEdit: {
                        viewModel.fetchUpcomingEvents()
                    }
                )
            }
        }
    }
}

// ViewModel for Member Events View


struct HomePage_Previews: PreviewProvider {
    static var previews: some View {
        HomePage(role: "Member")
            .previewDevice("iPhone 14")
            .previewDisplayName("iPhone 14")
    }
}

struct RefreshControl: View {
    let coordinateSpace: CoordinateSpace
    let onRefresh: (Binding<Bool>) -> Void
    
    @State private var refresh: Bool = false
    @State private var refreshOffset: CGFloat = 0
    @State private var refreshThreshold: CGFloat = 50
    
    var body: some View {
        GeometryReader { geo in
            if geo.frame(in: coordinateSpace).minY > refreshThreshold {
                Spacer()
                    .onAppear {
                        refresh = true
                        onRefresh($refresh)
                    }
            } else if geo.frame(in: coordinateSpace).minY > 0 {
                Spacer()
                    .onAppear {
                        refreshOffset = geo.frame(in: coordinateSpace).minY
                    }
            }
            
            HStack {
                Spacer()
                if refresh {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .rotationEffect(.degrees(refreshOffset > refreshThreshold ? 180 : 0))
                        .animation(.easeInOut, value: refreshOffset)
                }
                Spacer()
            }
            .offset(y: -50)
        }
        .padding(.top, -50)
    }
}

// Favorites View
struct FavoritesView: View {
    @ObservedObject var catalogViewModel: MemberCatalogViewModel
    
    var body: some View {
        List {
            ForEach(catalogViewModel.books.filter { $0.isFavorite }) { book in
                NavigationLink(destination: BooksDetailView(
                    book: book,
                    catalogViewModel: catalogViewModel,
                    libraryViewModel: LibraryViewModel()
                )) {
                    HStack {
                        AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// My Requests View
struct MyRequestsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var bookDetails: [String: MemberBook] = [:]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var myRequests: [BookRequest] {
        guard let userID = Auth.auth().currentUser?.uid else { return [] }
        return libraryViewModel.bookRequests.filter { $0.memberID == userID }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("My Requests (\(myRequests.filter { $0.status == "pending" }.count))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if myRequests.filter({ $0.status == "pending" }).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No pending requests")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(myRequests.filter { $0.status == "pending" }) { request in
                        if let book = bookDetails[request.bookID] {
                            MemberRequestCard(request: request, book: book, dateFormatter: dateFormatter)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("My Requests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBookDetails()
        }
    }
    
    private func loadBookDetails() {
        let db = Firestore.firestore()
        let requests = myRequests.filter { $0.status == "pending" }
        for request in requests {
            db.collection("BooksCatalog").document(request.bookID).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let book = MemberBook(
                        title: data["title"] as? String ?? "Unknown Title",
                        author: data["author"] as? String ?? "Unknown Author",
                        illustrator: data["illustrator"] as? String,
                        genres: data["genres"] as? String ?? "",
                        isbn: request.bookID,
                        language: data["language"] as? String ?? "Unknown",
                        bookFormat: data["bookFormat"] as? String ?? "Unknown",
                        edition: data["edition"] as? String ?? "Unknown",
                        pages: (data["pages"] as? Int) ?? 0,
                        publisher: data["publisher"] as? String ?? "Unknown",
                        description: data["summary"] as? String ?? "",
                        isAvailable: data["isAvailable"] as? Bool ?? true,
                        createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                        isFavorite: data["isFavorite"] as? Bool ?? false,
                        numberOfCopies: (data["numberOfCopies"] as? Int) ?? 0,
                        unavailableCopies: (data["unavailableCopies"] as? Int) ?? 0,
                        coverImageURL: data["coverImageURL"] as? String,
                        authorID: data["authorID"] as? String,
                        cost: (data["cost"] as? Double) ?? 20.0
                    )
                    DispatchQueue.main.async {
                        bookDetails[request.bookID] = book
                    }
                }
            }
        }
    }
}

// MARK: - Member Request Card UI
struct MemberRequestCard: View {
    let request: BookRequest
    let book: MemberBook
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Requested: \(dateFormatter.string(from: request.createdAt.dateValue()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("Status: \(request.status.capitalized)")
                                .font(.caption)
                                .foregroundColor(request.status == "pending" ? .orange : .secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Book Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Format:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(book.bookFormat)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                HStack {
                    Text("Language:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(book.language)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                if book.isAvailable {
                    HStack {
                        Text("Available Copies:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(book.numberOfCopies - book.unavailableCopies)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}
