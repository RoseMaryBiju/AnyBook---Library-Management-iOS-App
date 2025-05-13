//
//  OverdueBooksListView.swift
//  lib ms
//
//  Created by admin86 on 08/05/25.
//

import SwiftUI

struct OverdueBooksListView: View {
    @StateObject private var catalogViewModel = CatalogViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @State private var searchText = ""
    
    private var overdueTransactions: [Transaction] {
        let currentDate = Date()
        let transactions = libraryViewModel.transactions.filter {
            $0.status == "issued" && $0.dueDate.dateValue() < currentDate
        }
        if searchText.isEmpty {
            return transactions
        } else {
            return transactions.filter { transaction in
                // Find the book title
                let bookTitle = catalogViewModel.books.first { $0.isbn == transaction.bookID }?.title ?? ""
                return bookTitle.lowercased().contains(searchText.lowercased()) ||
                       transaction.memberID.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                TextField("Search by book title or member ID", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 12) {
                        if overdueTransactions.isEmpty {
                            Text(searchText.isEmpty ? "No overdue books found." : "No matching overdue books found.")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(overdueTransactions) { transaction in
                                OverdueBookCard(
                                    transaction: transaction,
                                    catalogViewModel: catalogViewModel,
                                    libraryViewModel: libraryViewModel
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Overdue Books")
            .onAppear {
                catalogViewModel.loadData()
                libraryViewModel.loadTransactions()
            }
        }
    }
}

struct OverdueBookCard: View {
    let transaction: Transaction
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var showReturnOptions = false
    @State private var showingIncreaseCopiesAlert = false

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
                        }
                    },
                    secondaryButton: .default(Text("No")) {
                        if let book = book {
                            libraryViewModel.markBookAsDamaged(transaction: transaction, book: book, increaseCopies: false)
                        }
                    }
                )
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

struct OverdueBooksListView_Previews: PreviewProvider {
    static var previews: some View {
        OverdueBooksListView()
            .environmentObject(CatalogViewModel())
            .environmentObject(LibraryViewModel())
    }
}
