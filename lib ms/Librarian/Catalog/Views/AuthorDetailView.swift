//
//  AuthorDetailView.swift
//  AnyBook
//
//  Created by admin86 on 25/04/25.
//

import SwiftUI
import Kingfisher
import FirebaseCore
import FirebaseFirestore

struct AuthorDetailView: View {
    @ObservedObject var viewModel: CatalogViewModel
    let author: Author
    @State private var books: [Book] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Image
                GeometryReader { geometry in
                    if let imageURL = author.image, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 240, height: 240, alignment: .center)
                                .cornerRadius(120)
                                .padding(.horizontal)
                                .padding(.vertical)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 2)
                                )
                                .position(x: geometry.size.width/2, y: 120)
                            
                        } placeholder: {
                            Image("PlaceholderImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 240, height: 240, alignment: .center)
                                .cornerRadius(120)
                                .padding(.horizontal)
                                .padding(.vertical)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 2)
                                )
                                .position(x: geometry.size.width/2, y: 120)
                        }
                    } else {
                        Image("PlaceholderImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240, alignment: .center)
                            .cornerRadius(120)
                            .padding(.horizontal)
                            .padding(.vertical)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 2)
                            )
                            .position(x: geometry.size.width/2, y: 120)
                    }
                }
                .frame(height: 240)
                .padding(.horizontal)
                .padding(.vertical)
                
                // Author Name
                Text(author.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                // About Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(author.bio ?? "No bio available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                    if let birthDate = author.birthDate, birthDate != "Unknown" {
                        Text("Born: \(birthDate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Books Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Books")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        NavigationLink(destination: AuthorBooksListView(viewModel: viewModel, author: author.name)) {
                            Text("See All")
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal)
                    if books.isEmpty {
                        Text("No books found for this author.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(books.prefix(4), id: \.id) { book in
                                VStack {
                                    if let coverImageURL = book.coverImageURL {
                                        if coverImageURL.hasPrefix("http"), let url = URL(string: coverImageURL) {
                                            KFImage(url)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                        } else if let url = viewModel.getBookCoverImageURL(book) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: 100)
                                                    .cornerRadius(8)
                                            } placeholder: {
                                                Image("PlaceholderImage")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 100)
                                                    .cornerRadius(8)
                                            }
                                        } else {
                                            Image("PlaceholderImage")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                                .cornerRadius(8)
                                        }
                                    } else {
                                        Image("PlaceholderImage")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                            .cornerRadius(8)
                                    }
                                    Text(book.title)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Author Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchBooks()
            }
        }
    }

    private func fetchBooks() {
        books = viewModel.getBooksByAuthorID(author.id)
    }
}

struct AuthorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AuthorDetailView(
            viewModel: CatalogViewModel(),
            author: Author(
                id: "OL12345A",
                name: "Sample Author",
                birthDate: "1 January 1970",
                bio: "This is a sample bio.",
                image: "https://covers.openlibrary.org/a/olid/OL12345A-M.jpg"
            )
        )
    }
}

struct AuthorBooksListView: View {
    @ObservedObject var viewModel: CatalogViewModel
    let author: String
    
    var body: some View {
        List {
            ForEach(viewModel.getBooksByAuthor(author), id: \.id) { book in
                NavigationLink(destination: BookDetailView(viewModel: viewModel, book: book)) {
                    Text(book.title)
                }
            }
        }
        .navigationTitle("Books by \(author)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
