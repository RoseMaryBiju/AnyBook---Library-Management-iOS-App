//
//  MyBooks.swift
//  lib ms
//
//  Created by admin100 on 08/05/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct MyBooksTabView: View {
    @State private var selectedTab: Tab = .borrowed
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var darkModeManager = DarkModeManager.shared
    
    enum Tab: String, CaseIterable {
        case borrowed = "Borrowed"
        case wishlist = "WishList"
        case completed = "Completed"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Sections", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
                
                switch selectedTab {
                case .borrowed:
                    BorrowedBooksView(libraryViewModel: libraryViewModel)
                case .wishlist:
                    WishListBooksView()
                case .completed:
                    CompletedBooksView(libraryViewModel: libraryViewModel)
                }
            }
            .navigationTitle("My Books")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                libraryViewModel.fetchBorrowedBooks()
                libraryViewModel.fetchCompletedBooks()
            }
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
}

struct BorrowedBooksView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @StateObject private var darkModeManager = DarkModeManager.shared
    @State private var searchText = ""
    
    var filteredBooks: [BorrowedBook] {
        if searchText.isEmpty {
            return libraryViewModel.borrowedBooks
        } else {
            return libraryViewModel.borrowedBooks.filter { $0.book.title.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        List {
            if filteredBooks.isEmpty {
                EmptyStateView(
                    icon: "book.closed",
                    title: "No books currently borrowed",
                    message: "Your borrowed books will appear here"
                )
            } else {
                ForEach(filteredBooks) { borrowedBook in
                    BookCardView(
                        title: borrowedBook.book.title,
                        subtitle: "Due: \(formatDate(borrowedBook.transaction.dueDate.dateValue()))",
                        status: getDueStatus(dueDate: borrowedBook.transaction.dueDate.dateValue())
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            // Add return book functionality here
                        } label: {
                            Label("Return", systemImage: "arrow.uturn.down")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search Borrowed Books")
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func getDueStatus(dueDate: Date) -> String {
        let calendar = Calendar.current
        let today = Date()
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
        
        if daysUntilDue < 0 {
            return "Overdue"
        } else if daysUntilDue <= 2 {
            return "Due Soon"
        }
        return ""
    }
}

struct WishListBooksView: View {
    @State private var books: [Book] = []
    @State private var searchText = ""
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        } else {
            return books.filter { $0.title.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredBooks) { book in
                BookCardView(
                    title: book.title,
                    subtitle: nil
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        if let index = books.firstIndex(where: { $0.id == book.id }) {
                            books.remove(at: index)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search WishList")
    }
}

struct CompletedBooksView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @StateObject private var darkModeManager = DarkModeManager.shared
    @State private var searchText = ""
    
    var filteredBooks: [BorrowedBook] {
        if searchText.isEmpty {
            return libraryViewModel.completedBooks
        } else {
            return libraryViewModel.completedBooks.filter { $0.book.title.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        List {
            if filteredBooks.isEmpty {
                EmptyStateView(
                    icon: "book.closed",
                    title: "No completed books yet",
                    message: "Your completed books will appear here"
                )
            } else {
                ForEach(filteredBooks) { borrowedBook in
                    BookCardView(
                        title: borrowedBook.book.title,
                        subtitle: "Returned: \(formatDate(borrowedBook.transaction.returnDate?.dateValue() ?? Date()))",
                        status: borrowedBook.transaction.status.capitalized
                    )
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search Completed Books")
        .onAppear {
            libraryViewModel.fetchCompletedBooks()
        }
        .preferredColorScheme(darkModeManager.isDarkMode ? .dark : .light)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct BookCardView: View {
    let title: String
    let subtitle: String?
    let status: String?
    
    init(title: String, subtitle: String?, status: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let status = status {
                    StatusBadge(status: status)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    
    var statusColor: Color {
        switch status.lowercased() {
        case "returned":
            return .green
        case "damaged":
            return .orange
        case "lost":
            return .red
        case "due soon":
            return .yellow
        case "overdue":
            return .red
        default:
            return .blue
        }
    }
    
    var body: some View {
        Text(status.capitalized)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
            )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.8))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .listRowBackground(Color.clear)
    }
}

struct MyBooksTabView_Previews: PreviewProvider {
    static var previews: some View {
        MyBooksTabView()
    }
}

