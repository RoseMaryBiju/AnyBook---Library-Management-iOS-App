//
//  EditBookView.swift
//  AnyBook
//
//  Created by admin86 on 24/04/25.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct EditBookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var author: String
    @State private var illustrator: String
    @State private var selectedGenres: Set<String>
    @State private var isbn: String
    @State private var language: String
    @State private var bookFormat: String
    @State private var edition: String
    @State private var pages: String
    @State private var publisher: String
    @State private var description: String
    @State private var genres: [String] = ["Classics", "Fiction", "Dystopia", "Fantasy", "Literature", "Politics", "School", "Science Fiction", "Novels", "Mystery", "Biography", "Non-Fiction", "History"]
    @State private var image: UIImage?
    @State private var showingImagePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    private let languages = ["English", "Spanish", "French", "German", "Chinese", "Other"]
    private let bookFormats = ["Hardcover", "Paperback", "Mass Market Paperback", "eBook", "Audiobook"]
    private let book: Book
    private let originalISBN: String
    private let db = Firestore.firestore()
    private let cloudinaryCloudName = "di0fauucw"
    private let cloudinaryUploadPreset = "book_upload_preset"
    
    #if canImport(PhotosUI)
    @State private var pickerItem: PhotosPickerItem?
    #endif
    
    init(book: Book) {
        self.book = book
        self.originalISBN = book.isbn
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _illustrator = State(initialValue: book.illustrator ?? "")
        _selectedGenres = State(initialValue: Set(book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }))
        _isbn = State(initialValue: book.isbn)
        _language = State(initialValue: book.language.isEmpty ? "English" : book.language)
        _bookFormat = State(initialValue: book.bookFormat.isEmpty ? "Paperback" : book.bookFormat)
        _edition = State(initialValue: book.edition.isEmpty ? "Unknown" : book.edition)
        _pages = State(initialValue: String(book.pages))
        _publisher = State(initialValue: book.publisher)
        _description = State(initialValue: book.description)
        _image = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Book Details")) {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Illustrator (optional)", text: $illustrator)
                    TextField("ISBN", text: $isbn)
                        .keyboardType(.numberPad)
                    NavigationLink(destination: MultiSelectPicker(items: genres, selections: $selectedGenres)) {
                        Text("Genres: \(selectedGenres.isEmpty ? "None" : selectedGenres.joined(separator: ", "))")
                    }
                }
                
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
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                
                Section(header: Text("Cover Image")) {
                    #if canImport(PhotosUI)
                    PhotosPicker(
                        selection: $pickerItem,
                        matching: .images,
                        photoLibrary: .shared()) {
                            HStack {
                                Text(image == nil ? "Select New Cover Image" : "Change Cover Image")
                                Spacer()
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                        .shadow(radius: 2)
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .frame(width: 80, height: 120)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                }
                            }
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
                        HStack {
                            Text(image == nil ? "Select New Cover Image" : "Change Cover Image")
                            Spacer()
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                    .shadow(radius: 2)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .frame(width: 80, height: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(image: $image)
                    }
                    #endif
                }
            }
            .navigationTitle("Edit Book")
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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    isSaving = false
                })
            }
        }
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
        print("Starting saveBook process for editing...")
        
        // Check for existing ISBN in Firebase (excluding the current book)
        db.collection("BooksCatalog").whereField("isbn", isEqualTo: isbn).getDocuments { snapshot, error in

            if let error = error {
                print("Error checking ISBN in Firestore: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to check ISBN in Firebase: \(error.localizedDescription)"
                    self.showingAlert = true
                    self.isSaving = false
                }
                return
            }
            
            if let documents = snapshot?.documents, !documents.isEmpty {
                // Check if the existing document is the current book (by comparing ISBNs)
                let matchingDocs = documents.filter { $0.documentID != self.originalISBN }
                if !matchingDocs.isEmpty {
                    print("ISBN already exists in Firebase: \(self.isbn)")
                    DispatchQueue.main.async {
                        self.alertMessage = "ISBN \(self.isbn) already exists. Please use a unique ISBN."
                        self.showingAlert = true
                        self.isSaving = false
                    }
                    return
                }
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
            
            print("Updating book with title: \(self.title), author: \(self.author), isbn: \(self.isbn)")
            
            var bookData: [String: Any] = [
                "title": self.title,
                "author": self.author,
                "illustrator": self.illustrator.isEmpty ? nil : self.illustrator,
                "genres": self.selectedGenres.joined(separator: ", "),
                "isbn": self.isbn,
                "language": self.language,
                "bookFormat": self.bookFormat,
                "edition": self.edition.isEmpty ? "Unknown" : self.edition,
                "pages": Int(self.pages) ?? 0,
                "publisher": self.publisher,
                "description": self.description.isEmpty ? "" : self.description,
                "isAvailable": self.book.isAvailable,
                "createdAt": self.book.createdAt,
                "isFavorite": self.book.isFavorite,
                "numberOfCopies": self.book.numberOfCopies,
                "unavailableCopies": self.book.unavailableCopies
            ]
            
            if let image = self.image {
                print("Uploading new cover image to Cloudinary...")
                self.uploadImageToCloudinary(image) { result in
                    switch result {
                    case .success(let imageURL):
                        bookData["coverImageURL"] = imageURL
                        print("Image uploaded to Cloudinary, URL: \(imageURL)")
                        self.saveToFirebase(bookData: bookData)
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
                // If no new image is selected, retain the existing coverImageURL
                bookData["coverImageURL"] = self.book.coverImageURL
                self.saveToFirebase(bookData: bookData)
            }
        }
    }
    
    private func saveToFirebase(bookData: [String: Any]) {
        // If ISBN has changed, delete the old document and create a new one
        if self.isbn != self.originalISBN {
            // Delete the old document
            self.db.collection("BooksCatalog").document(self.originalISBN).delete { error in
                if let error = error {
                    print("Error deleting old document: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to update book: \(error.localizedDescription)"
                        self.showingAlert = true
                        self.isSaving = false
                    }
                    return
                }
                
                // Create new document with the updated ISBN
                self.db.collection("BooksCatalog").document(self.isbn).setData(bookData) { error in
                    self.handleSaveResult(error: error)
                }
            }
        } else {
            // Update the existing document
            self.db.collection("BooksCatalog").document(self.isbn).setData(bookData) { error in
                self.handleSaveResult(error: error)
            }
        }
    }
    
    private func handleSaveResult(error: Error?) {
        if let error = error {
            print("Error saving book to Firebase: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.alertMessage = "Failed to save to Firebase: \(error.localizedDescription)"
                self.showingAlert = true
                self.isSaving = false
            }
        } else {
            print("Book updated successfully in Firebase: \(self.title)")
            DispatchQueue.main.async {
                self.isSaving = false
                self.dismiss()
            }
        }
    }
}
