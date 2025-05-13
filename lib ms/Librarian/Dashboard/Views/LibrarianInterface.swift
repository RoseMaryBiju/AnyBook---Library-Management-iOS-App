import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Charts
import PhotosUI

struct LibrarianInterface: View {
    @State private var selectedTab: Int = 0 // To control the selected tab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LibrarianDashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
                .tag(0)
            
            CatalogManagementView()
                .tabItem {
                    Label("Catalog", systemImage: "books.vertical")
                }
                .tag(1)
            
            MembersManagementView()
                .tabItem {
                    Label("Members", systemImage: "person.3.fill")
                }
                .tag(2)
        }
        .accentColor(.accentColor)
    }
}

// Dashboard View
struct LibrarianDashboardView: View {
    @Binding var selectedTab: Int // Binding to control tab navigation
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var catalogViewModel = CatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @State private var showingProfile = false
    @State private var showingAddEvent = false
    @State private var showingActiveMembers = false
    @State private var isLoaded = false
    @State private var selectedEvent: Event?
    @State private var showingEventDetail = false
    @State private var isLoadingAnalytics = true
    @State private var isLoadingBookRequests = true
    @State private var isLoadingActiveMembers = true
    @State private var isTransactionsLoaded = false
    @State private var isBooksLoaded = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Apply the gradient background to the entire screen
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Fixed Header Section
                    headerSection
                        .zIndex(1) // Ensure header stays on top
                    
                    // Scrollable content
                    ScrollView {
                        VStack(spacing: 4) {
                            quickStatsSection
                            analyticsSection
                            eventsSection
                        }
                        .padding(.top, 0) // Adjusted to ensure consistent spacing
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(dashboardViewModel: dashboardViewModel)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let selectedEvent = selectedEvent {
                    EventDetailView(
                        event: selectedEvent,
                        onDelete: {
                            dashboardViewModel.loadEvents()
                        },
                        onEdit: {
                            dashboardViewModel.loadEvents()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingActiveMembers) {
                ActiveMembersView(dashboardViewModel: dashboardViewModel, libraryViewModel: libraryViewModel)
            }
            .onAppear {
                dashboardViewModel.fetchLibrarianName()
                dashboardViewModel.loadEvents()
                catalogViewModel.loadData()
                
                // Load active members and stats
                if isTransactionsLoaded {
                    dashboardViewModel.loadActiveMembers(libraryViewModel: libraryViewModel)
                    self.isLoadingActiveMembers = false
                }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoaded = true
                }
            }
            .onChange(of: libraryViewModel.bookRequests) { _ in
                dashboardViewModel.fetchBookRequests(libraryViewModel: libraryViewModel)
                self.isLoadingBookRequests = false
            }
            .onChange(of: libraryViewModel.transactions) { _ in
                print("Transactions loaded: \(libraryViewModel.transactions.count) transactions")
                self.isTransactionsLoaded = true
                dashboardViewModel.loadActiveMembers(libraryViewModel: libraryViewModel)
                self.isLoadingActiveMembers = false
                
                // Check if both transactions and books are loaded to trigger analytics
                if self.isBooksLoaded {
                    dashboardViewModel.loadAnalyticsData(catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel) { [weak dashboardViewModel] in
                        self.isLoadingAnalytics = false
                    }
                }
            }
            .onChange(of: catalogViewModel.books) { _ in
                print("Books loaded: \(catalogViewModel.books.count) books")
                self.isBooksLoaded = true
                
                // Check if both transactions and books are loaded to trigger analytics
                if self.isTransactionsLoaded {
                    dashboardViewModel.loadAnalyticsData(catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel) { [weak dashboardViewModel] in
                        self.isLoadingAnalytics = false
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dashboardViewModel.currentDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(dashboardViewModel.greetingMessage)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Button(action: { showingProfile = true }) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.blue)
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 60, height: 60)
                    )
            }
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dashboardViewModel.greetingMessage), \(dashboardViewModel.currentDate)")
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Active Members Card
                Button(action: {
                    showingActiveMembers = true // Present modal
                }) {
                    StatCard(
                        title: "Active Members",
                        value: isLoadingActiveMembers ? "Loading..." : "\(dashboardViewModel.activeMembersCount)",
                        icon: "person.3.fill",
                        color: .green,
                        isNavigable: true,
                        isLoaded: isLoaded && !isLoadingActiveMembers
                    )
                }
                
                // Book Requests Card
                NavigationLink(destination: BookRequestsView(catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel)) {
                    StatCard(
                        title: "Book Requests",
                        value: isLoadingBookRequests ? "Loading..." : "\(dashboardViewModel.bookRequestsCount)",
                        icon: "book.circle.fill",
                        color: .orange,
                        isNavigable: true,
                        isLoaded: isLoaded && !isLoadingBookRequests
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics Overview")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            if isLoadingAnalytics {
                Text("Loading analytics data...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        booksIssuedChart
                        newMembershipsChart
                        mostIssuedGenresChart
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                }
            }
        }
        .padding(.vertical)
    }
    
    private var booksIssuedChart: some View {
        VStack {
            Text("Books Issued Per Day")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            Chart(dashboardViewModel.booksIssuedPerDay) { data in
                LineMark(
                    x: .value("Date", data.date),
                    y: .value("Books Issued", data.count)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(width: 300, height: 150)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(dateFormatter.string(from: date))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var newMembershipsChart: some View {
        VStack {
            Text("New Memberships")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            if dashboardViewModel.newMembershipsPerDay.isEmpty {
                Text("No new memberships data available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 300, height: 150)
            } else {
                Chart(dashboardViewModel.newMembershipsPerDay) { data in
                    BarMark(
                        x: .value("Date", data.date),
                        y: .value("New Members", data.count)
                    )
                    .foregroundStyle(.green)
                }
                .frame(width: 300, height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(dateFormatter.string(from: date))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var mostIssuedGenresChart: some View {
        VStack {
            Text("Most Issued Genres")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            Chart(dashboardViewModel.mostIssuedGenres) { data in
                SectorMark(
                    angle: .value("Count", data.count),
                    innerRadius: .ratio(0.25),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Genre", data.genre))
                .annotation(position: .overlay, alignment: .center) {
                    Text("\(data.count)")
                        .font(.caption)
                        .foregroundColor(.black)
                }
            }
            .frame(width: 200, height: 150)
            .chartLegend(position: .bottom)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingAddEvent = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Add New Event")
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                if dashboardViewModel.upcomingEvents.isEmpty {
                    Text("No upcoming events available")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Spacer()
                    ForEach(dashboardViewModel.upcomingEvents.prefix(3), id: \.id) { event in
                        EventRow(
                            event: event,
                            onTap: {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if dashboardViewModel.upcomingEvents.prefix(3).last?.id != event.id {
                            Divider()
                                .padding(.leading, 16)
                                .padding(.trailing, 16)
                        }
                    }
                }
                
                NavigationLink(destination: EventsView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
        // Vertical padding removed to maintain consistent spacing
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// Active Members View (Modal)
struct ActiveMembersView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                if dashboardViewModel.activeMembers.isEmpty {
                    Text("No active members found. Please check Firestore data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(dashboardViewModel.activeMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.headline)
                            Text(member.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Borrowed Books: \(member.borrowedBooksCount)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Active Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// View to Add a New Event
struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var description: String = ""
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil

    private struct Constants {
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    }

    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Image Picker Section
                    VStack {
                        if let selectedImage = selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 150)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                VStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Select Event Banner")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                        }

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose Image")
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedPhoto) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = Image(uiImage: uiImage)
                                } else {
                                    errorMessage = "Failed to load the selected image."
                                }
                            }
                        }
                    }

                    Form {
                        Section(header: Text("Event Details")) {
                            // Title and Date Picker Side by Side
                            HStack {
                                TextField("Event Title", text: $title)
                                    .autocapitalization(.words)

                                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .frame(maxWidth: 150)
                            }

                            TextEditor(text: $description)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.vertical, 4)
                        }
                    }

                    Spacer()
                }
                .padding(.top, 10)
                .navigationTitle("Add New Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            saveEvent()
                        }) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(isFormValid ? .blue : .gray)
                        .disabled(!isFormValid || isSaving)
                    }
                }
            }
        }
    }

    private func saveEvent() {
        guard isFormValid else {
            errorMessage = "Please fill in all fields."
            return
        }

        isSaving = true
        errorMessage = nil

        // Step 1: Upload the image to Cloudinary (if selected)
        Task {
            var bannerURL: String? = nil
            if let selectedPhoto = selectedPhoto,
               let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                do {
                    bannerURL = try await uploadImageToCloudinary(imageData: data)
                } catch {
                    self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    self.isSaving = false
                    return
                }
            }

            // Step 2: Save the event to Firestore
            let db = Firestore.firestore()
            var newEventData: [String: Any] = [
                "title": title,
                "date": Timestamp(date: date),
                "description": description
            ]

            if let bannerURL = bannerURL {
                newEventData["bannerURL"] = bannerURL
            }

            db.collection("EventsData").addDocument(data: newEventData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save event: \(error.localizedDescription)"
                    self.isSaving = false
                } else {
                    // Successfully saved, refresh events and dismiss
                    self.dashboardViewModel.loadEvents()
                    self.dismiss()
                }
            }
        }
    }

    // Function to upload image to Cloudinary
    private func uploadImageToCloudinary(imageData: Data) async throws -> String {
        // Configure your Cloudinary credentials here
        let cloudName = "di0fauucw" // Replace with your Cloudinary cloud name
        let uploadPreset = "book_upload_preset" // Replace with your Cloudinary unsigned upload preset
        let cloudinaryURL = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"

        // Create the request
        var request = URLRequest(url: URL(string: cloudinaryURL)!)
        request.httpMethod = "POST"

        // Set up multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build the request body
        var body = Data()

        // Add the image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"event_banner.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add the upload preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)

        // Close the boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Perform the upload
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check the response status
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Parse the JSON response to get the secure URL
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let secureURL = json?["secure_url"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return secureURL
    }
}




