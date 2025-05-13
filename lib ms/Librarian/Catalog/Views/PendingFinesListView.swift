//
//  PendingFinesListView.swift
//  lib ms
//
//  Created by admin86 on 09/05/25.
//

import SwiftUI

struct PendingFinesListView: View {
    @StateObject private var catalogViewModel = CatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    private var pendingFines: [Fine] {
        libraryViewModel.fines.filter { $0.status == "pending" }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if pendingFines.isEmpty {
                        Text("No pending fines found.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(pendingFines) { fine in
                            PendingFineCard(
                                fine: fine,
                                catalogViewModel: catalogViewModel,
                                libraryViewModel: libraryViewModel
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Pending Fines")
            .onAppear {
                catalogViewModel.loadData()
                libraryViewModel.loadTransactions()
                libraryViewModel.loadFines()
            }
        }
    }
}

struct PendingFineCard: View {
    let fine: Fine
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    }

    private var transaction: Transaction? {
        libraryViewModel.transactions.first { $0.id == fine.transactionID }
    }

    private var book: Book? {
        guard let transaction = transaction else { return nil }
        return catalogViewModel.books.first { $0.isbn == transaction.bookID }
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

                Text("Member ID: \(fine.memberID)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text("Reason: \(fine.reason.capitalized)")
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

struct PendingFinesListView_Previews: PreviewProvider {
    static var previews: some View {
        PendingFinesListView()
            .environmentObject(CatalogViewModel())
            .environmentObject(LibraryViewModel())
    }
}
