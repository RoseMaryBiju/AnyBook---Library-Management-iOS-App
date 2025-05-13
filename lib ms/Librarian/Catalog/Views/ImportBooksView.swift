//
//  ImportBooksView.swift
//  lib ms
//
//  Created by admin86 on 09/05/25.
//

import SwiftUI
import FirebaseFirestore
import UniformTypeIdentifiers
import SwiftCSV

struct ImportBooksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFileImporter = false
    @State private var isImporting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let db = Firestore.firestore()
    private let cloudinaryCloudName = "di0fauucw"
    private let cloudinaryUploadPreset = "book_upload_preset"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Import Books from CSV")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a CSV file containing book data to import into the library catalog. Ensure the CSV has columns for title, author, isbn, genres, language, bookFormat, edition, pages, publisher, and description.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    isShowingFileImporter = true
                }) {
                    Text("Select CSV File")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(isImporting)
                
                if isImporting {
                    ProgressView("Importing books...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Books")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    importBooks(from: url)
                case .failure(let error):
                    showError("Failed to open file picker: \(error.localizedDescription)")
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Import Result"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if !isImporting {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func importBooks(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError("Unable to access the selected file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        isImporting = true
        Task {
            do {
                let result = try await importBooks(from: url, db: db)
                DispatchQueue.main.async {
                    isImporting = false
                    alertMessage = result
                    showingAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    showError("Failed to import books: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func importBooks(from csvURL: URL, db: Firestore) async throws -> String {
        let csv = try CSV<Named>(url: csvURL, delimiter: .comma)
        print("CSV loaded with \(csv.rows.count) rows")
        
        // Debug BookCovers folder
        print("Debugging BookCovers contents:")
        let fileManager = FileManager.default
        if let resourcePath = Bundle.main.resourcePath {
            let bookCoversPath = resourcePath + "/BookCovers"
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bookCoversPath)
                print("Found \(contents.count) files in BookCovers:")
                contents.forEach { print(" - \($0)") }
            } catch {
                print("Error accessing BookCovers directory: \(error.localizedDescription)")
            }
        }
        
        let snapshot = try await db.collection("BooksCatalog").getDocuments()
        let existingISBNs = Set(snapshot.documents.map { $0.documentID })
        print("Existing ISBNs in Firebase: \(existingISBNs.count)")
        
        var importedCount = 0
        var skippedCount = 0
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
            
            print("Processing book with ISBN: \(isbn)")
            
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
            
            // Load and upload cover image
            var coverImageURL: String? = nil
            if let imageData = loadCoverImage(for: isbn) {
                do {
                    coverImageURL = try await uploadImageToCloudinary(imageData: imageData, isbn: isbn)
                    print("Uploaded cover image for ISBN \(isbn) to Cloudinary: \(coverImageURL ?? "nil")")
                } catch {
                    print("Failed to upload cover image for ISBN \(isbn): \(error.localizedDescription)")
                }
            } else {
                print("No cover image found for ISBN: \(isbn)")
            }
            
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
                coverImageURL: coverImageURL
            )
            
            do {
                let bookRef = db.collection("BooksCatalog").document(isbn)
                try batch.setData(from: book, forDocument: bookRef)
                importedCount += 1
                print("Added book with ISBN \(isbn) to batch")
            } catch {
                print("Error encoding book with ISBN \(isbn): \(error.localizedDescription)")
                skippedCount += 1
            }
        }
        
        print("Committing batch with \(importedCount) books")
        try await batch.commit()
        let message = "Imported \(importedCount) books successfully. Skipped \(skippedCount) books (duplicates or invalid data)."
        print(message)
        return message
    }
    
    private func loadCoverImage(for isbn: String) -> Data? {
        let extensions = ["jpg"]
        let cleanedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for ext in extensions {
            // Try ISBN with extension
            if let path = Bundle.main.path(forResource: cleanedISBN, ofType: ext, inDirectory: "BookCovers"),
               let image = UIImage(contentsOfFile: path),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                print("Loaded cover image for ISBN: \(cleanedISBN), path: \(path)")
                return imageData
            }
            
            // Try ISBN without hyphens
            let isbnNoHyphens = cleanedISBN.replacingOccurrences(of: "-", with: "")
            if isbnNoHyphens != cleanedISBN,
               let path = Bundle.main.path(forResource: isbnNoHyphens, ofType: ext, inDirectory: "BookCovers"),
               let image = UIImage(contentsOfFile: path),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                print("Loaded cover image for ISBN: \(isbnNoHyphens), path: \(path)")
                return imageData
            }
        }
        
        print("No cover image found for ISBN: \(cleanedISBN) in BookCovers directory")
        return nil
    }
    
    private func uploadImageToCloudinary(imageData: Data, isbn: String) async throws -> String {
        let cloudinaryURL = "https://api.cloudinary.com/v1_1/\(cloudinaryCloudName)/image/upload"
        guard let url = URL(string: cloudinaryURL) else {
            print("Invalid Cloudinary URL for ISBN: \(isbn)")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(isbn).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cloudinaryUploadPreset)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"public_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("book_covers/\(isbn)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("Bad server response from Cloudinary for ISBN: \(isbn), status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let secureURL = json?["secure_url"] as? String else {
            print("Cannot parse Cloudinary response for ISBN: \(isbn)")
            throw URLError(.cannotParseResponse)
        }
        
        return secureURL
    }
    
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            isImporting = false
            alertMessage = message
            showingAlert = true
        }
    }
}

struct ImportBooksView_Previews: PreviewProvider {
    static var previews: some View {
        ImportBooksView()
    }
}
