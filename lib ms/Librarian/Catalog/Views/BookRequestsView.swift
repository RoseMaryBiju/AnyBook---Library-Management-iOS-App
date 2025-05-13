//
//  BookRequestsView.swift
//  lib ms
//
//  Created by admin86 on 07/05/25.
//

import SwiftUI
import FirebaseFirestore
import CodeScanner

// Data Model for Individual Book Request
struct SingleBookRequest: Identifiable, Equatable {
    let id: String
    let bookID: String
    let bookTitle: String
    let reservationDate: Date
    let status: String
    
    static func == (lhs: SingleBookRequest, rhs: SingleBookRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

// Data Model for Grouped Book Requests by User
struct UserBookRequest: Identifiable {
    let id: String // userId
    let userName: String
    let bookRequests: [SingleBookRequest]
}

struct BookRequestsView: View {
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var searchText = ""
    @State private var selectedStatus: String = "pending"
    @State private var isShowingScanner = false
    @State private var scanError: String?
    @State private var userNames: [String: String] = [:] // Cache for user names

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.systemBackground), Color(UIColor.systemGray6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Text("Book Requests")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    TextField("Search by Book Title or User Name", text: $searchText)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

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
                    .accessibilityLabel("Scan QR Code")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Picker("Request Status", selection: $selectedStatus) {
                    Text("Pending").tag("pending")
                    Text("Rejected").tag("rejected")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        let userRequests = computeUserRequests()
                        if userRequests.isEmpty {
                            Text("No \(selectedStatus) requests found.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(userRequests) { userRequest in
                                BookRequestRow(
                                    userRequest: userRequest,
                                    onAccept: { request in
                                        if let book = catalogViewModel.books.first(where: { $0.isbn == request.bookID }),
                                           let libRequest = libraryViewModel.bookRequests.first(where: { $0.id == request.id }) {
                                            libraryViewModel.acceptBookRequest(libRequest, book: book)
                                        }
                                    },
                                    onReject: { request in
                                        if let libRequest = libraryViewModel.bookRequests.first(where: { $0.id == request.id }) {
                                            libraryViewModel.rejectBookRequest(libRequest)
                                        }
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingScanner) {
            CodeScannerView(
                codeTypes: [.qr],
                completion: { result in
                    isShowingScanner = false
                    switch result {
                    case .success(let details):
                        searchText = details.string
                    case .failure(let error):
                        scanError = error.localizedDescription
                    }
                }
            )
        }
        .alert(isPresented: Binding<Bool>(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Alert(
                title: Text("Scan Error"),
                message: Text(scanError ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            fetchUserNames()
        }
    }

    // Compute UserBookRequest objects by grouping book requests by memberID
    private func computeUserRequests() -> [UserBookRequest] {
        // Filter requests by selected status
        let filteredRequests = libraryViewModel.bookRequests.filter { $0.status == selectedStatus }

        // Map to SingleBookRequest
        let singleRequests: [SingleBookRequest] = filteredRequests.compactMap { request in
            guard let book = catalogViewModel.books.first(where: { $0.isbn == request.bookID }) else {
                return nil
            }
            return SingleBookRequest(
                id: request.id,
                bookID: request.bookID,
                bookTitle: book.title,
                reservationDate: request.createdAt.dateValue(),
                status: request.status
            )
        }

        // Filter by search text
        let searchedRequests = singleRequests.filter { request in
            searchText.isEmpty ||
            request.bookTitle.lowercased().contains(searchText.lowercased()) ||
            (userNames[request.bookID]?.lowercased().contains(searchText.lowercased()) ?? false)
        }

        // Group by memberID
        let grouped = Dictionary(grouping: searchedRequests) { request in
            libraryViewModel.bookRequests.first(where: { $0.id == request.id })?.memberID ?? ""
        }

        // Map to UserBookRequest
        return grouped.map { memberID, requests in
            UserBookRequest(
                id: memberID,
                userName: userNames[memberID] ?? "Member \(memberID)",
                bookRequests: requests
            )
        }.sorted { $0.userName < $1.userName }
    }

    // Fetch user names from Firestore
    private func fetchUserNames() {
        let db = Firestore.firestore()
        let memberIDs = Set(libraryViewModel.bookRequests.map { $0.memberID })
        for memberID in memberIDs {
            db.collection("users").document(memberID).getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching user name for \(memberID): \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data(),
                      let name = data["name"] as? String else {
                    return
                }
                DispatchQueue.main.async {
                    userNames[memberID] = name
                }
            }
        }
    }
}

struct BookRequestRow: View {
    let userRequest: UserBookRequest
    let onAccept: (SingleBookRequest) -> Void
    let onReject: (SingleBookRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(userRequest.userName)
                .font(.headline)
                .foregroundColor(.primary)

            Divider()
                .background(Color.gray)

            ForEach(userRequest.bookRequests) { request in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.bookTitle)
                            .font(.body)
                            .foregroundColor(.primary)

                        Text("Requested: \(dateFormatter.string(from: request.reservationDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Status: \(request.status.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(request.status == "pending" ? .orange : .red)
                    }

                    Spacer()

                    if request.status == "pending" {
                        HStack(spacing: 12) {
                            Button(action: { onAccept(request) }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Accept request for \(request.bookTitle)")

                            Button(action: { onReject(request) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Reject request for \(request.bookTitle)")
                        }
                    }
                }
                .padding(.vertical, 4)

                if request != userRequest.bookRequests.last {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct BookRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        BookRequestsView(catalogViewModel: CatalogViewModel(), libraryViewModel: LibraryViewModel())
    }
}
