//
//  CheckOutView.swift
//  lib ms
//
//  Created by admin86 on 07/05/25.
//

import SwiftUI

struct CheckOutView: View {
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    let memberID: String
    @State private var acceptedRequests: [BookRequest] = []
    @State private var issuedStates: [String: Bool] = [:] // Tracks issuance state for each request

    var body: some View {
        VStack(spacing: 16) {
            if acceptedRequests.isEmpty {
                Text("No accepted requests found for Member ID: \(memberID)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("Book Check-Out")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    ForEach(acceptedRequests) { request in
                        if let book = catalogViewModel.books.first(where: { $0.isbn == request.bookID }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title)
                                    .font(.headline)
                                Text("Author: \(book.author)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if issuedStates[request.id] == true {
                                    Text("Issued")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(8)
                                } else {
                                    Button(action: {
                                        libraryViewModel.issueBook(request: request)
                                        issuedStates[request.id] = true
                                        fetchAcceptedRequests() // Refresh the list
                                    }) {
                                        Text("Issue Book")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text("Book not found (ISBN: \(request.bookID))")
                                .foregroundColor(.red)
                        }
                    }
                }

                Button(action: {
                    libraryViewModel.issueAllBooks(for: memberID)
                    acceptedRequests.forEach { request in
                        issuedStates[request.id] = true
                    }
                    fetchAcceptedRequests() // Refresh the list
                }) {
                    Text("Issue All Books")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding()
                .disabled(acceptedRequests.isEmpty || acceptedRequests.allSatisfy { issuedStates[$0.id] == true })
            }
        }
        .navigationTitle("Check-Out")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            fetchAcceptedRequests()
        }
    }

    private func fetchAcceptedRequests() {
        acceptedRequests = libraryViewModel.bookRequests.filter { $0.memberID == memberID && $0.status == "accepted" }
        // Update issuedStates for requests that have already been issued
        for request in acceptedRequests {
            if libraryViewModel.transactions.contains(where: { $0.requestID == request.id && $0.status == "issued" }) {
                issuedStates[request.id] = true
            }
        }
    }
}

struct CheckOutView_Previews: PreviewProvider {
    static var previews: some View {
        CheckOutView(catalogViewModel: CatalogViewModel(), libraryViewModel: LibraryViewModel(), memberID: "sampleMemberID")
    }
}
