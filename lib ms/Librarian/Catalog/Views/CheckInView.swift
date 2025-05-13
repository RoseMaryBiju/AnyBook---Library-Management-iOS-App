import SwiftUI

struct CheckInView: View {
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    let memberID: String
    @State private var issuedTransactions: [Transaction] = []

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 16) {
            if issuedTransactions.isEmpty {
                Text("No issued books found for Member ID: \(memberID)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("Book Check-In")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(issuedTransactions) { transaction in
                            CheckInTransactionCard(
                                transaction: transaction,
                                catalogViewModel: catalogViewModel,
                                libraryViewModel: libraryViewModel,
                                onAction: {
                                    fetchIssuedTransactions()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Check-In")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            fetchIssuedTransactions()
        }
    }

    private func fetchIssuedTransactions() {
        issuedTransactions = libraryViewModel.transactions.filter { $0.memberID == memberID && $0.status == "issued" }
    }
}

struct CheckInTransactionCard: View {
    let transaction: Transaction
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var showingIncreaseCopiesAlert = false
    let onAction: () -> Void

    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var book: Book? {
        catalogViewModel.books.first { $0.isbn == transaction.bookID }
    }

    private var fine: Fine? {
        if let fineID = transaction.fineID {
            return libraryViewModel.fines.first { $0.id == fineID }
        }
        return nil
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

                Text("Member ID: \(transaction.memberID)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text("Due: \(dateFormatter.string(from: transaction.dueDate.dateValue()))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.red)

                if transaction.status != "issued", let fine = fine {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fine: $\(String(format: "%.2f", fine.amount))")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.black)

                        HStack {
                            Text("Status: \(fine.status.capitalized)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(fine.status == "pending" ? .orange : .green)

                            Spacer()

                            Button(action: {
                                libraryViewModel.toggleFineStatus(fine: fine)
                            }) {
                                Text(fine.status == "pending" ? "Mark as Paid" : "Mark as Pending")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(fine.status == "pending" ? Color.blue : Color.orange)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }

            Spacer()

            if transaction.status == "issued" {
                VStack(spacing: 8) {
                    Button(action: {
                        if let book = book {
                            libraryViewModel.returnBook(transaction: transaction, book: book)
                            onAction()
                        }
                    }) {
                        Text("Return")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        showingIncreaseCopiesAlert = true
                    }) {
                        Text("Mark Damaged")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        if let book = book {
                            libraryViewModel.markBookAsLost(transaction: transaction, book: book)
                            onAction()
                        }
                    }) {
                        Text("Mark Lost")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            } else {
                Text(transaction.status == "lost" ? "Marked as lost" : "Accepted return")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(transaction.status == "lost" ? Color.red : Color.green)
                    .cornerRadius(8)
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
}

struct CheckInView_Previews: PreviewProvider {
    static var previews: some View {
        CheckInView(catalogViewModel: CatalogViewModel(), libraryViewModel: LibraryViewModel(), memberID: "sampleMemberID")
    }
}
