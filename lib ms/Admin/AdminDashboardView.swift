import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Charts

struct AdminDashboardView: View {
    @State private var name = "Admin"
    @State private var userId = ""
    @State private var role = "Admin"
    @State private var bookCount = 0
    @State private var memberCount = 0
    @State private var librarianCount = 0
    @State private var totalFine = 25
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showLogin = false
    @State private var showProfile = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var profileIconPosition: CGPoint = .zero
    @State private var selectedTab = 0
    @State private var graphType: GraphType = .bar
    @State private var timePeriod: TimePeriod = .week
    @State private var librarianGraphData: [GraphDataPoint] = []
    @State private var memberGraphData: [GraphDataPoint] = []
    @State private var bookGraphData: [GraphDataPoint] = []
    @State private var userListener: ListenerRegistration?
    @State private var bookListener: ListenerRegistration?
    @State private var statsListener: ListenerRegistration?

    private let db = Firestore.firestore()
    private let accentColor = Color.blue

    enum GraphType: String, CaseIterable, Identifiable {
        case bar = "Bar"
        case line = "Line"
        var id: String { rawValue }
    }

    enum TimePeriod: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }

    private var dynamicGreeting: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 0..<12:
            return "Good Morning, \(name)"
        case 12..<17:
            return "Good Afternoon, \(name)"
        default:
            return "Good Evening, \(name)"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentDateString)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(dynamicGreeting)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Button(action: { showProfile = true }) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 52))
                                    .foregroundColor(.blue)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                            .frame(width: 60, height: 60)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(title: "Total Books", value: "\(bookCount)", icon: "book.fill", color: .blue, isNavigable: false, isLoaded: !isLoading)
                            StatCard(title: "Members", value: "\(memberCount)", icon: "person.2.fill", color: .green, isNavigable: false, isLoaded: !isLoading)
                            StatCard(title: "Librarians", value: "\(librarianCount)", icon: "calendar", color: .purple, isNavigable: false, isLoaded: !isLoading)
                            StatCard(title: "Revenue", value: "₹\(totalFine)", icon: "creditcard.fill", color: .orange, isNavigable: false, isLoaded: true)
                        }
                        .padding(.horizontal)

                        // Analytics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Analytics Overview")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            HStack {
                                Picker("Time Period", selection: $timePeriod) {
                                    ForEach(TimePeriod.allCases) { period in
                                        Text(period.rawValue).tag(period)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(accentColor)
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("Line Graph")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                    Toggle("", isOn: Binding(
                                        get: { graphType == .line },
                                        set: { _ in graphType = graphType == .line ? .bar : .line }
                                    ))
                                    .labelsHidden()
                                }
                            }
                            .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    graphCardView(
                                        title: "User Requests",
                                        librarianData: librarianGraphData,
                                        memberData: memberGraphData,
                                        librarianColor: .red,
                                        memberColor: .blue
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14, design: .rounded))
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 3)
                                .padding(.horizontal)
                        }
                        Spacer()
                    }
                }
                .refreshable {
                    fetchAllData()
                }
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

                UserManagementView()
                    .tabItem {
                        Label("Users", systemImage: "person.2.fill")
                    }
                    .tag(1)

                AdminBooksManagementView()
                    .tabItem {
                        Label("Catalog", systemImage: "book.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Modify", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .accentColor(accentColor)
            .onChange(of: selectedTab) { _ in
                showProfile = false
            }
            .fullScreenCover(isPresented: $showLogin) {
                LoginView()
            }
            .sheet(isPresented: $showProfile) {
                AdminProfileView(
                    name: name,
                    email: "admin@anybook.com",
                    isDarkMode: $isDarkMode,
                    onLogout: logoutAction,
                    onDismiss: { showProfile = false }
                )
            }
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    .scaleEffect(1.5)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            fetchAllData()
        }
        .onChange(of: timePeriod) { _ in
            print("Time period changed to: \(timePeriod.rawValue)")
            fetchGraphData()
        }
        .onDisappear {
            userListener?.remove()
            bookListener?.remove()
            statsListener?.remove()
        }
    }

    private func fetchAllData() {
        isLoading = true
        fetchUserData()
        fetchLibraryStats()
        fetchGraphData()
    }

    private func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in."
            role = ""
            isLoading = false
            return
        }

        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                print("User data fetch error: \(error.localizedDescription)")
                checkLoadingState()
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                errorMessage = "User data not found."
                checkLoadingState()
                return
            }

            name = data["name"] as? String ?? "Unknown"
            userId = data["userId"] as? String ?? "N/A"
            role = data["role"] as? String ?? ""
            checkLoadingState()
        }
    }

    private func fetchLibraryStats() {
        // Initial fetch using getDocuments
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                errorMessage = "Failed to fetch users: \(error.localizedDescription)"
                print("Initial users fetch error: \(error.localizedDescription)")
                checkLoadingState()
                return
            }
            guard let documents = snapshot?.documents else {
                errorMessage = "No users found."
                memberCount = 0
                librarianCount = 0
                checkLoadingState()
                return
            }
            memberCount = documents.filter { $0.data()["role"] as? String == "Member" }.count
            librarianCount = documents.filter { $0.data()["role"] as? String == "Librarian" }.count
            
            // Log all user documents for debugging
            print("All users fetched for stats:")
            for doc in documents {
                let role = doc.data()["role"] as? String ?? "Unknown"
                let dateJoined = doc.data()["dateJoined"] as? String ?? "N/A"
                print("Document \(doc.documentID): role=\(role), dateJoined=\(dateJoined)")
            }
            
            checkLoadingState()
        }

        db.collection("BooksCatalog").getDocuments { snapshot, error in
            if let error = error {
                errorMessage = "Failed to fetch books: \(error.localizedDescription)"
                print("Initial books fetch error: \(error.localizedDescription)")
                checkLoadingState()
                return
            }
            bookCount = snapshot?.documents.count ?? 0
            checkLoadingState()
        }

        // Set up real-time listeners after initial fetch
        statsListener?.remove()
        statsListener = db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Users snapshot listener error: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else {
                memberCount = 0
                librarianCount = 0
                return
            }
            memberCount = documents.filter { $0.data()["role"] as? String == "Member" }.count
            librarianCount = documents.filter { $0.data()["role"] as? String == "Librarian" }.count
        }

        db.collection("BooksCatalog").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Books snapshot listener error: \(error.localizedDescription)")
                return
            }
            bookCount = snapshot?.documents.count ?? 0
        }

        totalFine = 25 // Placeholder; update with actual fine calculation if available
    }

    private func fetchGraphData() {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        var periods: [Date] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // Determine startDate and periods array
        switch timePeriod {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            for i in 0...6 {
                if let d = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: now)) {
                    periods.append(d)
                }
            }
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -5, to: now)!
            for i in 0...5 {
                if let d = calendar.date(byAdding: .weekOfYear, value: -i, to: now) {
                    periods.append(calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d))!)
                }
            }
        case .month:
            startDate = calendar.date(byAdding: .month, value: -5, to: now)!
            for i in 0...5 {
                if let d = calendar.date(byAdding: .month, value: -i, to: now) {
                    periods.append(calendar.date(from: calendar.dateComponents([.year, .month], from: d))!)
                }
            }
        case .year:
            startDate = calendar.date(byAdding: .year, value: -4, to: now)!
            for i in 0...4 {
                if let d = calendar.date(byAdding: .year, value: -i, to: now) {
                    periods.append(calendar.date(from: calendar.dateComponents([.year], from: d))!)
                }
            }
        }
        periods.sort()

        print("Querying users with dateJoined >= \(dateFormatter.string(from: startDate)) for time period: \(timePeriod.rawValue)")

        // Initialize graph data with zeros for all periods
        var librarianDataPoints = periods.map { GraphDataPoint(date: $0, value: 0, role: "Librarian") }
        var memberDataPoints = periods.map { GraphDataPoint(date: $0, value: 0, role: "Member") }

        let dispatchGroup = DispatchGroup()

        // Fetch users with explicit role filter
        var librarianCounts: [Date: Int] = [:]
        var memberCounts: [Date: Int] = [:]
        for period in periods {
            librarianCounts[period] = 0
            memberCounts[period] = 0
        }

        dispatchGroup.enter()
        db.collection("users")
            .whereField("role", in: ["Librarian", "Member"])
            .whereField("dateJoined", isGreaterThanOrEqualTo: dateFormatter.string(from: startDate))
            .getDocuments { snapshot, error in
                if let error = error {
                    let errorDesc = error.localizedDescription
                    self.errorMessage = "Failed to fetch user data. Please ensure Firestore indexes are set up correctly."
                    print("User fetch error: \(errorDesc)")
                    if errorDesc.contains("The query requires an index") {
                        self.errorMessage += " Create the index in Firebase Console."
                    }
                    // Set fallback data to prevent graph from breaking
                    self.librarianGraphData = librarianDataPoints
                    self.memberGraphData = memberDataPoints
                    dispatchGroup.leave()
                    return
                }
                let documents = snapshot?.documents ?? []
                print("Fetched \(documents.count) user documents")
                
                var librarianDocs = 0
                var memberDocs = 0
                
                for doc in documents {
                    guard let dateString = doc.data()["dateJoined"] as? String,
                          let roleRaw = doc.data()["role"] as? String else {
                        print("Skipping document \(doc.documentID): missing dateJoined or role")
                        continue
                    }
                    guard let date = dateFormatter.date(from: dateString) else {
                        print("Skipping document \(doc.documentID): invalid date format \(dateString)")
                        continue
                    }
                    let userRole = roleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    print("Processing User: role=\(userRole), dateJoined=\(dateString), parsed=\(date)")
                    
                    // Find the period bucket for this date
                    let bucket = self.findPeriodBucket(for: date, in: periods, calendar: calendar)
                    guard let periodBucket = bucket else {
                        print("No period bucket found for date: \(dateString)")
                        continue
                    }
                    
                    if userRole == "librarian" {
                        librarianCounts[periodBucket, default: 0] += 1
                        librarianDocs += 1
                    } else if userRole == "member" {
                        memberCounts[periodBucket, default: 0] += 1
                        memberDocs += 1
                    } else {
                        print("Unexpected role: \(userRole) for document \(doc.documentID)")
                    }
                }
                
                print("Processed \(librarianDocs) librarian documents and \(memberDocs) member documents from users")
                dispatchGroup.leave()
            }

        // Fetch membership requests
        dispatchGroup.enter()
        db.collection("membershipRequests")
            .whereField("status", isEqualTo: "approved")
            .whereField("requestDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching membership requests: \(error.localizedDescription)")
                    dispatchGroup.leave()
                    return
                }
                let requests = snapshot?.documents ?? []
                print("Fetched \(requests.count) membership request documents")
                
                var membershipDocs = 0
                for doc in requests {
                    guard let requestDate = doc.data()["requestDate"] as? Timestamp else {
                        print("Skipping membership request \(doc.documentID): missing requestDate")
                        continue
                    }
                    let date = requestDate.dateValue()
                    print("Processing Membership Request: id=\(doc.documentID), requestDate=\(date)")
                    
                    // Find the period bucket for this date
                    let bucket = self.findPeriodBucket(for: date, in: periods, calendar: calendar)
                    guard let periodBucket = bucket else {
                        print("No period bucket found for membership request date: \(date)")
                        continue
                    }
                    
                    memberCounts[periodBucket, default: 0] += 1
                    membershipDocs += 1
                }
                
                print("Processed \(membershipDocs) membership request documents")
                dispatchGroup.leave()
            }

        dispatchGroup.notify(queue: .main) {
            // Update data points with counts
            librarianDataPoints = periods.map { GraphDataPoint(date: $0, value: librarianCounts[$0] ?? 0, role: "Librarian") }
            memberDataPoints = periods.map { GraphDataPoint(date: $0, value: memberCounts[$0] ?? 0, role: "Member") }
            
            print("Librarian Data Points: \(librarianDataPoints.map { "\($0.date): \($0.value)" })")
            print("Member Data Points: \(memberDataPoints.map { "\($0.date): \($0.value)" })")
            
            self.librarianGraphData = librarianDataPoints
            self.memberGraphData = memberDataPoints
            self.checkLoadingState()
        }
    }

    private func findPeriodBucket(for date: Date, in periods: [Date], calendar: Calendar) -> Date? {
        switch timePeriod {
        case .day:
            return periods.first(where: { calendar.isDate($0, inSameDayAs: date) })
        case .week:
            return periods.first(where: { calendar.isDate($0, equalTo: date, toGranularity: .weekOfYear) })
        case .month:
            return periods.first(where: { calendar.isDate($0, equalTo: date, toGranularity: .month) })
        case .year:
            return periods.first(where: { calendar.isDate($0, equalTo: date, toGranularity: .year) })
        }
    }

    private func checkLoadingState() {
        let userDataFetched = name != "Admin" || !errorMessage.contains("user data")
        let statsFetched = memberCount > 0 || librarianCount > 0 || bookCount > 0 || errorMessage.contains("users") || errorMessage.contains("books")
        let graphDataFetched = !librarianGraphData.isEmpty || !memberGraphData.isEmpty

        if userDataFetched && statsFetched && graphDataFetched {
            isLoading = false
        }
        print("Loading state: userDataFetched=\(userDataFetched), statsFetched=\(statsFetched), graphDataFetched=\(graphDataFetched), isLoading=\(isLoading)")
    }

    private func truncateDate(_ date: Date, for timePeriod: TimePeriod, calendar: Calendar) -> Date {
        switch timePeriod {
        case .day:
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return calendar.date(from: components)!
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: date))!
        }
    }

    private func fillDataPoints(_ dataPoints: [GraphDataPoint], from startDate: Date, to endDate: Date, calendar: Calendar, timePeriod: TimePeriod, role: String) -> [GraphDataPoint] {
        var filledData: [GraphDataPoint] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let matchingPoint = dataPoints.first { calendar.isDate($0.date, equalTo: currentDate, toGranularity: timePeriod.calendarComponent) }
            filledData.append(GraphDataPoint(date: currentDate, value: matchingPoint?.value ?? 0, role: role))
            currentDate = calendar.date(byAdding: timePeriod.calendarComponent, value: 1, to: currentDate)!
        }

        return filledData
    }

    private func logoutAction() {
        do {
            try Auth.auth().signOut()
            showLogin = true
        } catch let signOutError as NSError {
            errorMessage = "Error signing out: \(signOutError.localizedDescription)"
        }
    }

    private func graphCardView(title: String, librarianData: [GraphDataPoint], memberData: [GraphDataPoint], librarianColor: Color, memberColor: Color) -> some View {
        let allDates = Array(Set(librarianData.map { $0.date } + memberData.map { $0.date })).sorted()
        let hasLibrarianData = librarianData.contains { $0.value > 0 }
        let hasMemberData = memberData.contains { $0.value > 0 }

        return VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.bottom, 5)

            if !hasLibrarianData && !hasMemberData {
                VStack {
                    Spacer()
                    Text("No data for this period.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Spacer()
                }
                .frame(width: 300, height: 200)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(isDarkMode ? 0.15 : 0.05), radius: 3)
            } else if !hasMemberData && hasLibrarianData {
                VStack {
                    Spacer()
                    Text("No member data available. Only librarian data shown.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                    Spacer()
                    Chart {
                        ForEach(librarianData) { point in
                            if graphType == .bar {
                                BarMark(
                                    x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                    y: .value("Count", point.value)
                                )
                                .foregroundStyle(librarianColor)
                                .cornerRadius(4)
                                .annotation(position: .top) {
                                    if point.value > 0 {
                                        Text("\(point.value)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                LineMark(
                                    x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                    y: .value("Count", point.value)
                                )
                                .foregroundStyle(librarianColor)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle().strokeBorder(lineWidth: 1))
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: timePeriod.dateFormatStyle, centered: true)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(Color(.systemBackground))
                            .border(Color.gray.opacity(isDarkMode ? 0.4 : 0.2), width: 1)
                    }
                    .frame(height: 150)
                }
                .frame(width: 300, height: 200)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(isDarkMode ? 0.15 : 0.05), radius: 3)
            } else {
                Chart {
                    ForEach(librarianData) { point in
                        if graphType == .bar {
                            BarMark(
                                x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                y: .value("Count", point.value)
                            )
                            .foregroundStyle(by: .value("Role", "Librarians"))
                            .position(by: .value("Role", "Librarians"))
                            .cornerRadius(4)
                            .annotation(position: .top) {
                                if point.value > 0 {
                                    Text("\(point.value)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            LineMark(
                                x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                y: .value("Count", point.value)
                            )
                            .foregroundStyle(by: .value("Role", "Librarians"))
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle().strokeBorder(lineWidth: 1))
                        }
                    }
                    ForEach(memberData) { point in
                        if graphType == .bar {
                            BarMark(
                                x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                y: .value("Count", point.value)
                            )
                            .foregroundStyle(by: .value("Role", "Members"))
                            .position(by: .value("Role", "Members"))
                            .cornerRadius(4)
                            .annotation(position: .top) {
                                if point.value > 0 {
                                    Text("\(point.value)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            LineMark(
                                x: .value("Date", point.date, unit: timePeriod.chartUnit),
                                y: .value("Count", point.value)
                            )
                            .foregroundStyle(by: .value("Role", "Members"))
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle().strokeBorder(lineWidth: 1))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Librarians": librarianColor,
                    "Members": memberColor
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: timePeriod.dateFormatStyle, centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color(.systemBackground))
                        .border(Color.gray.opacity(isDarkMode ? 0.4 : 0.2), width: 1)
                }
                .frame(width: 300, height: 200)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(isDarkMode ? 0.15 : 0.05), radius: 3)
            }
        }
    }
}

struct GraphDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    var value: Int
    let role: String
}

extension AdminDashboardView.TimePeriod {
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    var dateFormatStyle: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.day(.twoDigits).month(.twoDigits) // e.g., 03/05
        case .week:
            return .dateTime.day(.twoDigits).month(.abbreviated) // e.g., 01 Apr
        case .month:
            return .dateTime.month(.abbreviated).year(.twoDigits) // e.g., Apr 25
        case .year:
            return .dateTime.year() // e.g., 2025
        }
    }

    var chartUnit: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}




struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDashboardView()
            .preferredColorScheme(.light)
        AdminDashboardView()
            .preferredColorScheme(.dark)
    }
}
