//
//  BookDetailView.swift
//  AnyBook
//
//  Created by admin86 on 25/04/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct BookDetailView: View {
    @ObservedObject var viewModel: CatalogViewModel
    let book: Book
    @State private var bookToEdit: Book?
    @State private var isAvailable: Bool
    @State private var showingEditBook: Bool = false
    @State private var showMarkUnavailableAlert = false
    @State private var copiesToMarkUnavailable: String = ""
    @State private var errorMessage: String?
    
    init(viewModel: CatalogViewModel, book: Book) {
        self.viewModel = viewModel
        self.book = book
        self._isAvailable = State(initialValue: book.isAvailable)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CoverImageView(book: book, viewModel: viewModel)
                TitleAuthorSection(book: book)
                InfoButtonsSection(book: book)
                GenreTagsSection(book: book)
                AvailabilitySection(
                    book: book,
                    isAvailable: $isAvailable,
                    showMarkUnavailableAlert: $showMarkUnavailableAlert,
                    copiesToMarkUnavailable: $copiesToMarkUnavailable,
                    viewModel: viewModel,
                    errorMessage: $errorMessage
                )
                SummarySection(book: book)
                AdditionalDetailsSection(book: book)
                AuthorSection(book: book, viewModel: viewModel)
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        bookToEdit = book
                        showingEditBook = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                    }
                    .accessibilityLabel("Edit Book Details")
                }
            }
            .sheet(isPresented: $showingEditBook, onDismiss: {
                // Snapshot listener in viewModel will handle updates
            }) {
                if let bookToEdit = bookToEdit {
                    EditBookView(book: bookToEdit)
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct CoverImageView: View {
    let book: Book
    let viewModel: CatalogViewModel
    
    var body: some View {
        let _ = print("CoverImageURL for book \(book.title): \(String(describing: book.coverImageURL))")
        
        if let url = viewModel.getBookCoverImageURL(book) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 380, height: 480)
                    .cornerRadius(30)
                    .padding(.horizontal)
                    .padding(.vertical)
            } placeholder: {
                Image("PlaceholderImage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 380, height: 480)
                    .cornerRadius(30)
                    .padding(.horizontal)
                    .padding(.vertical)
            }
        } else {
            Image("PlaceholderImage")
                .resizable()
                .scaledToFill()
                .frame(width: 380, height: 480)
                .cornerRadius(30)
                .padding(.horizontal)
                .padding(.vertical)
        }
    }
}

struct TitleAuthorSection: View {
    let book: Book
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(book.author)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                if let illustrator = book.illustrator {
                    Text("Illustrated by \(illustrator)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { /* Share functionality */ }) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                    .frame(width: 60, height: 60)
            }
        }
        .padding(.horizontal)
    }
}

struct InfoButtonsSection: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            InfoButton(title: "Pages", value: book.pages > 0 ? String(book.pages) : "Unknown")
            InfoButton(title: "Language", value: book.language.isEmpty ? "Unknown" : book.language)
            InfoButton(title: "Format", value: book.bookFormat.isEmpty ? "Unknown" : book.bookFormat)
        }
        .padding(.horizontal)
    }
}

struct InfoButton: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 120, height: 75)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct GenreTagsSection: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 8) {
            let genreArray = book.genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if genreArray.isEmpty {
                Text("No genres")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            } else {
                ForEach(genreArray.prefix(4), id: \.self) { genre in
                    Text(genre)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct AvailabilitySection: View {
    let book: Book
    @Binding var isAvailable: Bool
    @Binding var showMarkUnavailableAlert: Bool
    @Binding var copiesToMarkUnavailable: String
    let viewModel: CatalogViewModel
    @Binding var errorMessage: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                showMarkUnavailableAlert = true
            }) {
                Text("Mark as Unavailable")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(book.numberOfCopies > 0 ? Color.orange : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(book.numberOfCopies <= 0)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .alert("Mark as Unavailable", isPresented: $showMarkUnavailableAlert) {
                TextField("Number of copies to mark unavailable (max \(book.numberOfCopies))", text: $copiesToMarkUnavailable)
                Button("All") { copiesToMarkUnavailable = String(book.numberOfCopies) }
                Button("OK", action: {
                    guard let count = Int(copiesToMarkUnavailable), count > 0 else {
                        errorMessage = "Please enter a valid number of copies."
                        copiesToMarkUnavailable = ""
                        return
                    }
                    guard count <= book.numberOfCopies else {
                        errorMessage = "Cannot mark more copies than available (\(book.numberOfCopies))."
                        copiesToMarkUnavailable = ""
                        return
                    }
                    viewModel.updateBookAvailability(book, isAvailable: false, copiesToChange: count)
                    // Snapshot listener will update the book in viewModel.books
                    copiesToMarkUnavailable = ""
                })
                Button("Cancel", role: .cancel) { copiesToMarkUnavailable = "" }
            } message: {
                Text("Enter the number of copies to mark as unavailable or select 'All'.")
            }
            
            VStack(spacing: 4) {
                Text("Copies")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(book.numberOfCopies)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 60)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

struct SummarySection: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.primary)
            Text(book.description.isEmpty ? "No summary available." : book.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(5)
                .truncationMode(.tail)
        }
        .padding(.horizontal)
    }
}

struct AdditionalDetailsSection: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !(book.edition.isEmpty || book.edition == "Unknown") {
                HStack {
                    Text("Edition:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(book.edition)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            if !(book.publisher.isEmpty || book.publisher == "Unknown") {
                HStack {
                    Text("Publisher:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(book.publisher)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            if !book.isbn.isEmpty {
                HStack {
                    Text("ISBN:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(book.isbn)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            if book.cost > 0 {
                HStack {
                    Text("Cost:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("$\(String(format: "%.2f", book.cost))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct AuthorSection: View {
    let book: Book
    let viewModel: CatalogViewModel
    @State private var author: Author?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About the Author")
                .font(.headline)
                .foregroundColor(.primary)
            if let author = author {
                HStack(spacing: 16) {
                    if let imageURL = author.image, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        } placeholder: {
                            Image("PlaceholderImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        }
                    } else {
                        Image("PlaceholderImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(author.bio ?? "No bio available.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        if let birthDate = author.birthDate, birthDate != "Unknown" {
                            Text("Born: \(birthDate)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        NavigationLink(destination: AuthorDetailView(viewModel: viewModel, author: author)) {
                            Text("See More")
                                .foregroundColor(.blue)
                            + Text(" →")
                        }
                    }
                }
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.red)
            } else {
                Text("Loading author details...")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            fetchAuthorDetails()
        }
    }

    private func fetchAuthorDetails() {
        guard let authorID = book.authorID else {
            errorMessage = "Author ID not found."
            return
        }

        let db = Firestore.firestore()
        db.collection("AuthorsData").document(authorID).getDocument { snapshot, error in
            if let error = error {
                errorMessage = "Failed to load author details: \(error.localizedDescription)"
                return
            }

            guard let data = snapshot?.data(), let name = data["name"] as? String else {
                errorMessage = "Author not found in database."
                return
            }

            author = Author(
                id: authorID,
                name: name,
                birthDate: data["birth_date"] as? String,
                bio: data["bio"] as? String,
                image: data["image"] as? String
            )
        }
    }
}

struct BookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BookDetailView(viewModel: CatalogViewModel(), book: Book(
            title: "Test Book",
            author: "Test Author",
            illustrator: nil,
            genres: "Fiction",
            isbn: "1234567890",
            language: "English",
            bookFormat: "Hardcover",
            edition: "1st",
            pages: 300,
            publisher: "Test Publisher",
            description: "A test book description.",
            isAvailable: true,
            createdAt: Timestamp(date: Date()),
            isFavorite: false,
            numberOfCopies: 5,
            unavailableCopies: 0,
            coverImageURL: nil,
            authorID: "OL12345A",
            cost: 29.99
        ))
    }
}
