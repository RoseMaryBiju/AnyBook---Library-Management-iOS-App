//
//  CatalogStatsView.swift
//  AnyBook
//
//  Created by admin86 on 24/04/25.
//

import SwiftUI

struct CatalogStatsView: View {
    @ObservedObject var catalogViewModel: CatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @Binding var showingImportModal: Bool // Binding to control modal presentation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Total Books
                NavigationLink(destination: BooksListView(viewModel: catalogViewModel)) {
                    CatalogStatCard(
                        title: "Total Books",
                        value: "\(catalogViewModel.totalBooks)",
                        icon: "book.fill",
                        color: .blue,
                        isNavigable: true
                    )
                }
                
                // Unavailable Books
                NavigationLink(destination: UnavailableBooksView(viewModel: catalogViewModel)) {
                    CatalogStatCard(
                        title: "Unavailable Books",
                        value: "\(catalogViewModel.unavailableBooks)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        isNavigable: true
                    )
                }
                
                // Issued Books
                NavigationLink(destination: IssuedBooksListView()) {
                    CatalogStatCard(
                        title: "Issued Books",
                        value: "\(libraryViewModel.issuedBooksCount)",
                        icon: "arrow.up.doc.fill",
                        color: .indigo,
                        isNavigable: true
                    )
                }
                
                // Overdue Books
                NavigationLink(destination: OverdueBooksListView()) {
                    CatalogStatCard(
                        title: "Overdue Books",
                        value: "\(libraryViewModel.overdueBooksCount)",
                        icon: "clock.fill",
                        color: .orange,
                        isNavigable: true
                    )
                }
                
                // Total Authors
                NavigationLink(destination: AuthorsListView(viewModel: catalogViewModel)) {
                    CatalogStatCard(
                        title: "Total Authors",
                        value: "\(catalogViewModel.totalAuthors)",
                        icon: "person.fill",
                        color: .purple,
                        isNavigable: true
                    )
                }
                
                // Requested Books
                NavigationLink(destination: RequestedBooksListView()) {
                    CatalogStatCard(
                        title: "Requested Books",
                        value: "\(libraryViewModel.bookRequests.count)",
                        icon: "hand.raised.fill",
                        color: .green,
                        isNavigable: true
                    )
                }
                
                // Pending Fines
                NavigationLink(destination: PendingFinesListView()) {
                    CatalogStatCard(
                        title: "Pending Fines",
                        value: "\(libraryViewModel.pendingFinesCount)",
                        icon: "exclamationmark.circle.fill",
                        color: .pink,
                        isNavigable: true
                    )
                }
                
                // Upload from CSV
                Button(action: {
                    showingImportModal = true
                }) {
                    CatalogStatCard(
                        title: "Upload from CSV",
                        value: "", // No value for this card
                        icon: "square.and.arrow.up.fill",
                        color: .teal,
                        isNavigable: false
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CatalogStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isNavigable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isNavigable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(height: 100)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(value.isEmpty ? "" : ": \(value)")")
    }
}
