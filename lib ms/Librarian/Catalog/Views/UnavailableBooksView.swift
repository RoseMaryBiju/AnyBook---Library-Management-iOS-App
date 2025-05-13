//
//  UnavailableBooksView.swift
//  AnyBook
//
//  Created by admin86 on 28/04/25.
//

import SwiftUI
import Kingfisher
import FirebaseFirestore

struct UnavailableBooksView: View {
    @ObservedObject var viewModel: CatalogViewModel
    @State private var unavailableBooks: [Book] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(unavailableBooks, id: \.id) { book in
                    NavigationLink(destination: UnavailableBookDetailView(viewModel: viewModel, book: book)) {
                        VStack(alignment: .leading) {
                            Text(book.title)
                                .font(.headline)
                            Text("Unavailable Copies: \(book.unavailableCopies)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Unavailable Books")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadData()
                updateUnavailableBooks()
            }
            .onChange(of: viewModel.books) { _ in
                updateUnavailableBooks()
            }
        }
    }

    private func updateUnavailableBooks() {
        unavailableBooks = viewModel.books.filter { $0.unavailableCopies > 0 }
    }
}

struct BookCoverImageView: View {
    let book: Book
    let viewModel: CatalogViewModel

    var body: some View {
        if let coverImageURL = book.coverImageURL, coverImageURL.hasPrefix("http"), let url = URL(string: coverImageURL) {
            KFImage(url)
                .resizable()
                .scaledToFill()
                .frame(width: 380, height: 480)
                .cornerRadius(30)
                .padding(.horizontal)
                .padding(.vertical)
        } else if let url = viewModel.getBookCoverImageURL(book) {
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
                    .scaledToFit()
                    .frame(width: 50, height: 50)
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

struct UnavailableBookDetailView: View {
    @ObservedObject var viewModel: CatalogViewModel
    let book: Book
    @State private var showMarkAvailableAlert = false
    @State private var copiesToMarkAvailable: String = ""
    @State private var errorMessage: String?
    @State private var author: Author?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BookCoverImageView(book: book, viewModel: viewModel)

                // Title, Author, Illustrator, and Share
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

                // Info Buttons
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("Pages")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(book.pages > 0 ? String(book.pages) : "Unknown")
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

                    VStack(spacing: 4) {
                        Text("Language")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(book.language.isEmpty ? "Unknown" : book.language)
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

                    VStack(spacing: 4) {
                        Text("Format")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(book.bookFormat.isEmpty ? "Unknown" : book.bookFormat)
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
                .padding(.horizontal)

                // Genre Tags
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

                // Mark as Available Button and Copies Card
                HStack(spacing: 12) {
                    Button(action: {
                        showMarkAvailableAlert = true
                    }) {
                        Text("Mark as Available")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(book.unavailableCopies > 0 ? Color.green : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(book.unavailableCopies <= 0)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .alert("Mark as Available", isPresented: $showMarkAvailableAlert) {
                        TextField("Number of copies to mark available (max \(book.unavailableCopies))", text: $copiesToMarkAvailable)
                        Button("All") { copiesToMarkAvailable = String(book.unavailableCopies) }
                        Button("OK", action: {
                            guard let count = Int(copiesToMarkAvailable), count > 0 else {
                                errorMessage = "Please enter a valid number of copies."
                                copiesToMarkAvailable = ""
                                return
                            }
                            guard count <= book.unavailableCopies else {
                                errorMessage = "Cannot mark more copies than unavailable (\(book.unavailableCopies))."
                                copiesToMarkAvailable = ""
                                return
                            }
                            viewModel.updateBookAvailability(book, isAvailable: true, copiesToChange: count)
                            copiesToMarkAvailable = ""
                        })
                        Button("Cancel", role: .cancel) { copiesToMarkAvailable = "" }
                    } message: {
                        Text("Enter the number of copies to mark as available or select 'All'.")
                    }

                    VStack(spacing: 4) {
                        Text("Unavailable Copies")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(book.unavailableCopies)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .frame(width: 120, height: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Summary Section
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

                // Additional Details
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

                // About the Author Section
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
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
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

struct UnavailableBooksView_Previews: PreviewProvider {
    static var previews: some View {
        UnavailableBooksView(viewModel: CatalogViewModel())
    }
}
