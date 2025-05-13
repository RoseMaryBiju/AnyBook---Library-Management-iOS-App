//
//  RequestedBooksListView.swift
//  lib ms
//
//  Created by admin86 on 08/05/25.
//

import SwiftUI

struct RequestedBooksListView: View {
    @StateObject private var catalogViewModel = CatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if libraryViewModel.bookRequests.isEmpty {
                        Text("No book requests found.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(libraryViewModel.bookRequests) { request in
                            RequestedBookCard(
                                request: request,
                                catalogViewModel: catalogViewModel,
                                libraryViewModel: libraryViewModel
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Requested Books")
            .onAppear {
                catalogViewModel.loadData()
                libraryViewModel.loadBookRequests()
            }
        }
    }
}

struct RequestedBookCard: View {
    let request: BookRequest
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    }

    private var book: Book? {
        catalogViewModel.books.first { $0.isbn == request.bookID }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Load book cover image or use a fallback
            if let coverImageURL = book?.coverImageURL, let url = URL(string: coverImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 80)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "book.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .foregroundColor(Constants.accentColor)
                            .padding(.bottom, 4)
                    @unknown default:
                        Image(systemName: "book.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .foregroundColor(Constants.accentColor)
                            .padding(.bottom, 4)
                    }
                }
            } else {
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .foregroundColor(Constants.accentColor)
                    .padding(.bottom, 4)
            }

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

struct RequestedBooksListView_Previews: PreviewProvider {
    static var previews: some View {
        RequestedBooksListView()
            .environmentObject(CatalogViewModel())
            .environmentObject(LibraryViewModel())
    }
}
