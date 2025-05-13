import SwiftUI
import PhotosUI
import FirebaseFirestore
import CodeScanner

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var illustrator = ""
    @State private var selectedGenres = Set<String>()
    @State private var isbn = ""
    @State private var language = "English"
    @State private var bookFormat = "Paperback"
    @State private var edition = ""
    @State private var pages = ""
    @State private var publisher = ""
    @State private var summary = ""
    @State private var image: UIImage?
    @State private var showingImagePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    @State private var isShowingScanner = false
    @State private var isFetchingBookData = false
    
    private let genres = [
        "Classics", "Fiction", "Dystopia", "Fantasy", "Literature",
        "Politics", "School", "Science Fiction", "Novels", "Mystery",
        "Biography", "Non-Fiction", "History"
    ]
    
    private let languages = ["English", "Spanish", "French", "German", "Chinese", "Other"]
    private let bookFormats = ["Hardcover", "Paperback", "Mass Market Paperback", "eBook", "Audiobook"]
    
    #if canImport(PhotosUI)
    @State private var pickerItem: PhotosPickerItem?
    #endif
    
    private let db = Firestore.firestore()
    
    private let cloudinaryCloudName = "di0fauucw"
    private let cloudinaryUploadPreset = "book_upload_preset"
    
    var body: some View {
        NavigationView {
            Form {
                bookDetailsSection
                additionalDetailsSection
                coverImageSection
            }
            .navigationTitle("Add New Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveBook()
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || title.isEmpty || author.isEmpty || isbn.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                CodeScannerView(
                    codeTypes: [.ean13, .upce],
                    completion: handleScan
                )
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        isSaving = false
                        isFetchingBookData = false
                    }
                )
            }
            .overlay {
                if isFetchingBookData {
                    VStack {
                        ProgressView("Fetching Book Data...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var bookDetailsSection: some View {
        Section(header: Text("Book Details")) {
            TextField("Title", text: $title)
            TextField("Author", text: $author)
            TextField("Illustrator (optional)", text: $illustrator)
            HStack {
                TextField("ISBN", text: $isbn)
                    .keyboardType(.numberPad)
                Button(action: {
                    isShowingScanner = true
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .accessibilityLabel("Scan ISBN Barcode")
                .disabled(isFetchingBookData)
            }
            NavigationLink(destination: MultiSelectPicker(items: genres, selections: $selectedGenres)) {
                Text("Genres: \(selectedGenres.isEmpty ? "None" : selectedGenres.joined(separator: ", "))")
            }
        }
    }
    
    private var additionalDetailsSection: some View {
        Section(header: Text("Additional Details")) {
            Picker("Language", selection: $language) {
                ForEach(languages, id: \.self) { lang in
                    Text(lang)
                }
            }
            Picker("Format", selection: $bookFormat) {
                ForEach(bookFormats, id: \.self) { format in
                    Text(format)
                }
            }
            TextField("Edition (optional)", text: $edition)
            TextField("Pages (optional)", text: $pages)
                .keyboardType(.numberPad)
            TextField("Publisher (optional)", text: $publisher)
            TextField("Description (optional)", text: $summary, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
        }
    }
    
    private var coverImageSection: some View {
        Section(header: Text("Cover Image")) {
            #if canImport(PhotosUI)
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()) {
                    coverImagePickerContent
                }
                .onChange(of: pickerItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            if let compressedData = uiImage.jpegData(compressionQuality: 0.8),
                               compressedData.count <= 1 * 1024 * 1024 {
                                image = uiImage
                                print("Image selected successfully, size: \(compressedData.count) bytes")
                            } else {
                                print("Image too large (over 1MB) after compression, skipping cover image")
                                image = nil
                            }
                        } else {
                            print("Failed to load or convert image to JPEG data")
                            image = nil
                        }
                    }
                }
            #else
            Button(action: {
                showingImagePicker = true
            }) {
                coverImagePickerContent
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $image)
            }
            #endif
        }
    }
    
    private var coverImagePickerContent: some View {
        HStack {
            Text(image == nil ? "Select Cover Image" : "Change Cover Image")
            Spacer()
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .shadow(radius: 2)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Functions
    
    private func handleScan(result: Result<ScanResult, ScanError>) {
        isShowingScanner = false
        switch result {
        case .success(let scanResult):
            let scannedCode = scanResult.string
            print("Scanned barcode: \(scannedCode)")
            
            let isbnCleaned = scannedCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if isbnCleaned.count == 13 || isbnCleaned.count == 10 {
                isbn = isbnCleaned
                fetchBookDataWithRetry(isbn: isbnCleaned, retries: 3)
            } else {
                alertMessage = "Invalid ISBN scanned. It must be 10 or 13 digits."
                showingAlert = true
            }
            
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
            alertMessage = "Failed to scan barcode: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func fetchBookDataWithRetry(isbn: String, retries: Int, delay: TimeInterval = 1.0) {
        guard retries > 0 else {
            DispatchQueue.main.async {
                self.isFetchingBookData = false
                self.alertMessage = "Failed to fetch book data after multiple attempts. Please check your internet connection or enter the details manually."
                self.showingAlert = true
            }
            return
        }
        
        isFetchingBookData = true
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.alertMessage = "Invalid API URL."
                self.showingAlert = true
                self.isFetchingBookData = false
            }
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    print("Error fetching book data: \(error.localizedDescription), code: \(error.code)")
                    
                    if error.domain == NSURLErrorDomain && (
                        error.code == NSURLErrorSecureConnectionFailed ||
                        error.code == NSURLErrorServerCertificateHasBadDate ||
                        error.code == NSURLErrorServerCertificateUntrusted ||
                        error.code == NSURLErrorCannotConnectToHost ||
                        error.code == NSURLErrorNotConnectedToInternet
                    ) {
                        print("Retrying fetch (\(retries - 1) attempts left)...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.fetchBookDataWithRetry(isbn: isbn, retries: retries - 1, delay: delay * 2)
                        }
                        return
                    }
                    
                    self.isFetchingBookData = false
                    self.alertMessage = "Failed to fetch book data: \(error.localizedDescription). Please check your internet connection or enter the details manually."
                    self.showingAlert = true
                    return
                }
                
                guard let data = data else {
                    self.isFetchingBookData = false
                    self.alertMessage = "No data received from the API. Please try again or enter the details manually."
                    self.showingAlert = true
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    guard let totalItems = json?["totalItems"] as? Int, totalItems > 0,
                          let items = json?["items"] as? [[String: Any]],
                          let book = items.first,
                          let volumeInfo = book["volumeInfo"] as? [String: Any] else {
                        self.isFetchingBookData = false
                        self.alertMessage = "No book found with ISBN \(isbn). Please enter the details manually."
                        self.showingAlert = true
                        return
                    }
                    
                    self.title = (volumeInfo["title"] as? String) ?? ""
                    self.author = (volumeInfo["authors"] as? [String])?.joined(separator: ", ") ?? ""
                    self.publisher = (volumeInfo["publisher"] as? String) ?? ""
                    self.summary = (volumeInfo["summary"] as? String) ?? ""
                    if let pageCount = volumeInfo["pageCount"] as? Int {
                        self.pages = String(pageCount)
                    }
                    if let categories = volumeInfo["categories"] as? [String] {
                        self.selectedGenres = Set(categories.filter { self.genres.contains($0) })
                    }
                    self.language = (volumeInfo["language"] as? String)?.capitalized ?? "English"
                    if !self.languages.contains(self.language) {
                        self.language = "Other"
                    }
                    
                    if let imageLinks = volumeInfo["imageLinks"] as? [String: Any],
                       let thumbnailURLString = imageLinks["thumbnail"] as? String {
                        let secureThumbnailURLString = thumbnailURLString.replacingOccurrences(of: "http://", with: "https://")
                        guard let imageURL = URL(string: secureThumbnailURLString) else {
                            print("Invalid cover image URL: \(secureThumbnailURLString)")
                            self.isFetchingBookData = false
                            return
                        }
                        print("Fetching cover image from: \(secureThumbnailURLString)")
                        URLSession.shared.dataTask(with: imageURL) { imageData, _, imageError in
                            DispatchQueue.main.async {
                                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                                    self.image = uiImage
                                    print("Cover image fetched successfully, size: \(imageData.count) bytes")
                                } else {
                                    print("Failed to fetch cover image: \(imageError?.localizedDescription ?? "No error"). You can manually select a cover image.")
                                }
                                self.isFetchingBookData = false
                            }
                        }.resume()
                    } else {
                        print("No cover image URL provided by the API.")
                        self.isFetchingBookData = false
                    }
                    
                    print("Book data fetched successfully for ISBN: \(isbn)")
                    
                } catch {
                    print("Error parsing API response: \(error.localizedDescription)")
                    self.isFetchingBookData = false
                    self.alertMessage = "Error parsing book data: \(error.localizedDescription). Please enter the details manually."
                    self.showingAlert = true
                }
            }
        }
        task.resume()
    }
    
    private func validateISBN(_ isbn: String) -> Bool {
        let isbnCleaned = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        print("Validating ISBN: \(isbnCleaned)")
        
        if isbnCleaned.count == 10 || isbnCleaned.count == 13 {
            return true
        }
        
        alertMessage = "ISBN must be 10 or 13 digits (numbers only). Example: 1234567890 or 1234567890123"
        showingAlert = true
        return false
    }
    
    private func uploadImageToCloudinary(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])))
            return
        }
        
        let uploadURL = "https://api.cloudinary.com/v1_1/\(cloudinaryCloudName)/image/upload"
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cloudinaryUploadPreset)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"public_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("book_covers/\(isbn)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(isbn).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading image to Cloudinary: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from Cloudinary"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let secureURL = json["secure_url"] as? String {
                    print("Image uploaded successfully to Cloudinary, URL: \(secureURL)")
                    completion(.success(secureURL))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Cloudinary"])))
                }
            } catch {
                print("Error parsing Cloudinary response: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func saveBook() {
        isSaving = true
        print("Starting saveBook process...")
        
        // Check for existing ISBN in Firebase
        db.collection("BooksCatalog").document(isbn).getDocument { document, error in
            if let error = error {
                print("Error checking ISBN in Firestore: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to check ISBN in Firebase: \(error.localizedDescription)"
                    self.showingAlert = true
                    self.isSaving = false
                }
                return
            }
            
            if let document = document, document.exists {
                print("ISBN already exists in Firebase: \(self.isbn)")
                DispatchQueue.main.async {
                    self.alertMessage = "ISBN \(self.isbn) already exists. Please use a unique ISBN."
                    self.showingAlert = true
                    self.isSaving = false
                }
                return
            }
            
            if self.title.isEmpty || self.author.isEmpty || self.isbn.isEmpty {
                DispatchQueue.main.async {
                    self.alertMessage = "Title, Author, and ISBN are required fields."
                    self.showingAlert = true
                    self.isSaving = false
                }
                return
            }
            
            if !self.validateISBN(self.isbn) {
                DispatchQueue.main.async {
                    self.isSaving = false
                }
                return
            }
            
            print("Creating new book with title: \(self.title), author: \(self.author), isbn: \(self.isbn)")
            
            let newBook = Book(
                title: self.title,
                author: self.author,
                illustrator: self.illustrator.isEmpty ? nil : self.illustrator,
                genres: self.selectedGenres.joined(separator: ", "),
                isbn: self.isbn,
                language: self.language,
                bookFormat: self.bookFormat,
                edition: self.edition.isEmpty ? "Unknown" : self.edition,
                pages: Int(self.pages) ?? 0,
                publisher: self.publisher,
                description: self.summary.isEmpty ? "" : self.summary,
                isAvailable: true,
                createdAt: Timestamp(date: Date()),
                isFavorite: false,
                numberOfCopies: 10,
                unavailableCopies: 0,
                coverImageURL: nil
            )
            
            if let image = self.image {
                print("Uploading cover image to Cloudinary...")
                self.uploadImageToCloudinary(image) { result in
                    switch result {
                    case .success(let imageURL):
                        print("Image uploaded to Cloudinary, URL: \(imageURL)")
                        let updatedBook = Book(
                            title: newBook.title,
                            author: newBook.author,
                            illustrator: newBook.illustrator,
                            genres: newBook.genres,
                            isbn: newBook.isbn,
                            language: newBook.language,
                            bookFormat: newBook.bookFormat,
                            edition: newBook.edition,
                            pages: newBook.pages,
                            publisher: newBook.publisher,
                            description: newBook.description,
                            isAvailable: newBook.isAvailable,
                            createdAt: newBook.createdAt,
                            isFavorite: newBook.isFavorite,
                            numberOfCopies: newBook.numberOfCopies,
                            unavailableCopies: newBook.unavailableCopies,
                            coverImageURL: imageURL
                        )
                        
                        do {
                            try self.db.collection("BooksCatalog").document(self.isbn).setData(from: updatedBook)
                            print("Book saved successfully to Firebase: \(self.title)")
                            DispatchQueue.main.async {
                                self.isSaving = false
                                self.dismiss()
                            }
                        } catch {
                            print("Error saving book to Firebase: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.alertMessage = "Failed to save to Firebase: \(error.localizedDescription)"
                                self.showingAlert = true
                                self.isSaving = false
                            }
                        }
                        
                    case .failure(let error):
                        print("Error uploading image to Cloudinary: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.alertMessage = "Failed to upload image to Cloudinary: \(error.localizedDescription)"
                            self.showingAlert = true
                            self.isSaving = false
                        }
                    }
                }
            } else {
                print("No cover image selected for Cloudinary")
                do {
                    try self.db.collection("BooksCatalog").document(self.isbn).setData(from: newBook)
                    print("Book saved successfully to Firebase: \(self.title)")
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.dismiss()
                    }
                } catch {
                    print("Error saving book to Firebase: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to save to Firebase: \(error.localizedDescription)"
                        self.showingAlert = true
                        self.isSaving = false
                    }
                }
            }
        }
    }
}


