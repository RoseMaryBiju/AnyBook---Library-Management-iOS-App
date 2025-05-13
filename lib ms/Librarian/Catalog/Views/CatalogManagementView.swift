import SwiftUI
import SwiftCSV
import AVFoundation
import FirebaseFirestore
import UniformTypeIdentifiers

struct CatalogManagementView: View {
    @StateObject private var catalogViewModel = CatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @State private var showingAddBook = false
    @State private var showingEditBook = false
    @State private var bookToEdit: Book?
    @State private var showingQRScannerForCheckOut = false
    @State private var showingQRScannerForCheckIn = false
    @State private var showingCheckOutView = false
    @State private var showingCheckInView = false
    @State private var scannedMemberID: String?
    @State private var showingImportModal = false // For the import modal
    @State private var selectedCSVURL: URL? // To store the selected CSV file
    @State private var isImporting = false // To show progress during import
    @State private var showingAlert = false // To show success/error messages
    @State private var alertMessage = "" // Message for the alert

    struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    }
    
    private let db = Firestore.firestore() // Firestore instance
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Check-Out and Check-In Buttons (Styled like CatalogStatCard)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            Button(action: {
                                scannedMemberID = nil // Reset before scanning
                                showingQRScannerForCheckOut = true
                            }) {
                                VStack(alignment: .center, spacing: 12) {
                                    Spacer()
                                    Text("Check-Out")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Constants.buttonGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                .accessibilityLabel("Check-Out")
                            }
                            
                            Button(action: {
                                scannedMemberID = nil // Reset before scanning
                                showingQRScannerForCheckIn = true
                            }) {
                                VStack(alignment: .center, spacing: 12) {
                                    Spacer()
                                    Text("Check-In")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Constants.buttonGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                .accessibilityLabel("Check-In")
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Statistics Section
                        CatalogStatsView(
                            catalogViewModel: catalogViewModel,
                            libraryViewModel: libraryViewModel,
                            showingImportModal: $showingImportModal
                        )
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("Catalog")
                .onAppear {
                    print("CatalogManagementView appeared")
                    catalogViewModel.loadData()
                    libraryViewModel.loadBookRequests()
                    libraryViewModel.loadTransactions()
                }

                // Floating Add Button at Bottom-Right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddBook = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                                .shadow(radius: 4)
                        }
                        .accessibilityLabel("Add New Book")
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 10)
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
            .sheet(isPresented: $showingEditBook) {
                if let book = bookToEdit {
                    EditBookView(book: book)
                }
            }
            .sheet(isPresented: $showingQRScannerForCheckOut) {
                QRCodeScannerView(
                    scannedCode: $scannedMemberID,
                    onComplete: {
                        print("Scanned Member ID for Check-Out: \(scannedMemberID ?? "nil")")
                        showingQRScannerForCheckOut = false
                        if scannedMemberID != nil {
                            showingCheckOutView = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingQRScannerForCheckIn) {
                QRCodeScannerView(
                    scannedCode: $scannedMemberID,
                    onComplete: {
                        print("Scanned Member ID for Check-In: \(scannedMemberID ?? "nil")")
                        showingQRScannerForCheckIn = false
                        if scannedMemberID != nil {
                            showingCheckInView = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingCheckOutView) {
                if let memberID = scannedMemberID {
                    CheckOutView(catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel, memberID: memberID)
                }
            }
            .sheet(isPresented: $showingCheckInView) {
                if let memberID = scannedMemberID {
                    CheckInView(catalogViewModel: catalogViewModel, libraryViewModel: libraryViewModel, memberID: memberID)
                }
            }
            .sheet(isPresented: $showingImportModal) {
                importModalView
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Import Result"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if !isImporting {
                            showingImportModal = false // Dismiss modal on success
                            catalogViewModel.loadData() // Refresh catalog data
                        }
                    }
                )
            }
        }
    }
    
    // Modal view for importing CSV
    private var importModalView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Import Books from CSV")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a CSV file to import books into the catalog. Ensure the CSV has columns for title, author, isbn, genres, language, bookFormat, edition, pages, publisher, and description.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    isShowingFileImporter = true
                }) {
                    Text(selectedCSVURL == nil ? "Select CSV File" : "Selected: \(selectedCSVURL!.lastPathComponent)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedCSVURL == nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(isImporting || selectedCSVURL != nil)
                
                Button(action: {
                    if let url = selectedCSVURL {
                        importBooksFromCSV(url: url)
                    }
                }) {
                    if isImporting {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        Text("Import Books")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedCSVURL == nil ? Color.gray : Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .disabled(isImporting || selectedCSVURL == nil)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Books")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingImportModal = false
                        selectedCSVURL = nil
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        showError("No file selected.")
                        return
                    }
                    selectedCSVURL = url
                case .failure(let error):
                    showError("Failed to open file picker: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // State for file importer
    @State private var isShowingFileImporter = false
    
    // Function to import books from CSV and upload to Firebase
    private func importBooksFromCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError("Unable to access the selected file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        isImporting = true
        importBooks(from: url, db: db) { result in
            DispatchQueue.main.async {
                isImporting = false
                switch result {
                case .success(let message):
                    alertMessage = message
                    showingAlert = true
                    selectedCSVURL = nil // Reset after successful import
                case .failure(let error):
                    showError("Failed to import books: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Function to parse CSV and upload to Firebase
    private func importBooks(from csvURL: URL, db: Firestore, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let csv = try CSV<Named>(url: csvURL, delimiter: .comma)
            
            // Fetch existing ISBNs from Firebase
            db.collection("BooksCatalog").getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let existingISBNs = Set(snapshot?.documents.map { $0.documentID } ?? [])
                var importedCount = 0
                var skippedCount = 0
                let totalRows = csv.rows.count
                let batch = db.batch()
                
                for row in csv.rows {
                    guard let isbn = row["isbn"], !isbn.isEmpty else {
                        print("Skipping row with missing ISBN")
                        skippedCount += 1
                        continue
                    }
                    
                    if existingISBNs.contains(isbn) {
                        print("Skipping duplicate ISBN: \(isbn)")
                        skippedCount += 1
                        continue
                    }
                    
                    let authorStr = row["author"] ?? "Unknown"
                    var author = authorStr
                    var illustrator: String?
                    
                    let components = authorStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    for component in components {
                        if component.contains("(Illustrator)") {
                            illustrator = component.replacingOccurrences(of: "(Illustrator)", with: "").trimmingCharacters(in: .whitespaces)
                            author = components.filter { !$0.contains("(Illustrator)") && !$0.contains("(Preface)") && !$0.contains("(Introduction)") }
                                .joined(separator: ", ")
                                .trimmingCharacters(in: .whitespaces)
                        }
                    }
                    
                    let genresStr = row["genres"] ?? ""
                    let cleanedGenres = genresStr
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .replacingOccurrences(of: "'", with: "")
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: ", ")
                    
                    let book = Book(
                        title: row["title"] ?? "",
                        author: author.isEmpty ? "Unknown" : author,
                        illustrator: illustrator,
                        genres: cleanedGenres,
                        isbn: isbn,
                        language: row["language"] ?? "",
                        bookFormat: row["bookFormat"] ?? "",
                        edition: row["edition"]?.isEmpty == true ? "Unknown" : (row["edition"] ?? "Unknown"),
                        pages: Int(row["pages"] ?? "0") ?? 0,
                        publisher: row["publisher"] ?? "",
                        description: row["description"] ?? "",
                        isAvailable: true,
                        createdAt: Timestamp(date: Date()),
                        isFavorite: false,
                        numberOfCopies: Int.random(in: 5...15),
                        unavailableCopies: 0,
                        coverImageURL: nil
                    )
                    
                    do {
                        let bookRef = db.collection("BooksCatalog").document(isbn)
                        try batch.setData(from: book, forDocument: bookRef)
                        importedCount += 1
                    } catch {
                        print("Error encoding book with ISBN \(isbn): \(error.localizedDescription)")
                        skippedCount += 1
                    }
                }
                
                // Commit the batch
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        let message = "Imported \(importedCount) books successfully. Skipped \(skippedCount) books (duplicates or invalid data)."
                        completion(.success(message))
                    }
                }
            }
        } catch {
            print("Failed to parse CSV: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // Helper to show error alerts
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            isImporting = false
            alertMessage = message
            showingAlert = true
        }
    }
}

// QR Code Scanner View
struct QRCodeScannerView: View {
    @Binding var scannedCode: String?
    @State private var isShowingManualInput = false
    @State private var manualMemberID = ""
    @State private var errorMessage: String?
    var onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                if isShowingManualInput {
                    VStack(spacing: 20) {
                        TextField("Enter Member ID", text: $manualMemberID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button(action: {
                            if !manualMemberID.isEmpty {
                                scannedCode = manualMemberID
                                onComplete()
                            }
                        }) {
                            Text("Submit Member ID")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            isShowingManualInput = false
                        }) {
                            Text("Back to Scanner")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .navigationTitle("Manual Member ID Input")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                onComplete()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } else {
                    QRCodeScannerRepresentable(scannedCode: $scannedCode, errorMessage: $errorMessage, onComplete: onComplete)
                        .ignoresSafeArea()
                    
                    VStack {
                        Text("Align the QR code within the frame to scan")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.top, 20)
                        
                        Spacer()
                        
                        Button(action: {
                            isShowingManualInput = true
                        }) {
                            Text("Add Member ID Manually")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 20)
                        .accessibilityLabel("Add Member ID Manually")
                    }
                    .navigationTitle("Scan Member QR Code")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                onComplete()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Scanner Error"),
                    message: Text(errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// QR Code Scanner Representable
struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var errorMessage: String?
    var onComplete: () -> Void
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let scanner = QRCodeScannerViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRCodeScannerDelegate {
        var parent: QRCodeScannerRepresentable
        
        init(_ parent: QRCodeScannerRepresentable) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            DispatchQueue.main.async {
                self.parent.scannedCode = code
                self.parent.onComplete()
            }
        }
        
        func didFailWithError(_ error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = error.localizedDescription
            }
        }
    }
}

// QR Code Scanner Delegate Protocol
protocol QRCodeScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: Error)
}

// QR Code Scanner View Controller
class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRCodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession?.isRunning == false {
                self.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession?.isRunning == true {
                self.captureSession?.stopRunning()
            }
        }
    }
    
    private func setupScanner() {
        // Initialize capture session
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video device found"]))
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if let captureSession = captureSession, captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFailWithError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to add video input"]))
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if let captureSession = captureSession, captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to add metadata output"]))
            return
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {
            delegate?.didScanCode(stringValue)
        }
    }
}

// Check-Out Card Component
struct CheckOutCard: View {
    let request: BookRequest
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var catalogViewModel: CatalogViewModel

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    }

    private var book: Book? {
        catalogViewModel.books.first { $0.isbn == request.bookID }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "book.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .foregroundColor(Constants.accentColor)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(book?.title ?? "Unknown Title")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text("Member ID: \(request.memberID)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text("Request ID: \(request.id)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: {
                if let book = book {
                    libraryViewModel.issueBook(request: request)
                }
            }) {
                Text("Issue Book")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Constants.buttonGradient)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            .disabled(book == nil)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// Check-In Card Component
struct CheckInCard: View {
    let transaction: Transaction
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var catalogViewModel: CatalogViewModel
    @State private var showReturnOptions = false
    @State private var showingIncreaseCopiesAlert = false
    let onAction: () -> Void

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    }

    private var book: Book? {
        catalogViewModel.books.first { $0.isbn == transaction.bookID }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "book.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .foregroundColor(Constants.accentColor)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(book?.title ?? "Unknown Title")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text("Member ID: \(transaction.memberID)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text("Due: \(dateFormatter.string(from: transaction.dueDate.dateValue()))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.red)
            }

            Spacer()

            Button(action: {
                showReturnOptions = true
            }) {
                Text("Return")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Constants.buttonGradient)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            .disabled(book == nil)
            .actionSheet(isPresented: $showReturnOptions) {
                ActionSheet(
                    title: Text("Return Options"),
                    message: Text("How would you like to process the return?"),
                    buttons: [
                        .default(Text("Return Normally")) {
                            if let book = book {
                                libraryViewModel.returnBook(transaction: transaction, book: book)
                                onAction()
                            }
                        },
                        .default(Text("Mark as Damaged")) {
                            if book != nil {
                                showingIncreaseCopiesAlert = true
                            }
                        },
                        .default(Text("Mark as Lost")) {
                            if let book = book {
                                libraryViewModel.markBookAsLost(transaction: transaction, book: book)
                                onAction()
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .alert(isPresented: $showingIncreaseCopiesAlert) {
                Alert(
                    title: Text("Mark Book as Damaged"),
                    message: Text("Would you like to increase the number of copies for this book?"),
                    primaryButton: .default(Text("Yes")) {
                        if let book = book {
                            libraryViewModel.markBookAsDamaged(transaction: transaction, book: book, increaseCopies: true)
                            onAction()
                        }
                    },
                    secondaryButton: .default(Text("No")) {
                        if let book = book {
                            libraryViewModel.markBookAsDamaged(transaction: transaction, book: book, increaseCopies: false)
                            onAction()
                        }
                    }
                )
            }
            .onChange(of: libraryViewModel.transactions) { _ in
                onAction()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CatalogManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CatalogManagementView()
            .environmentObject(CatalogViewModel())
            .environmentObject(LibraryViewModel())
    }
}
