//
//  BooksLibraryFAQBot.swift
//  Books Library
//
//  Created by admin100 on 08/05/25.
//

import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - UI Constants
enum UIConstants {
    static let accentColor = Color(red: 0.25, green: 0.35, blue: 0.55) // Deep blue for a scholarly vibe
    static let messageBubbleColorUser = Color(red: 0.1, green: 0.5, blue: 0.7) // Vibrant blue for user messages
    static let messageBubbleColorAI = Color(red: 0.95, green: 0.9, blue: 0.85) // Parchment-like for AI responses
    static let backgroundColor = Color.white // Changed to white background
    static let maxMessageLength = 500 // Maximum length for user input
}

// MARK: - Main Chat View
struct BooksLibraryFAQBotView: View {
    @StateObject private var viewModel = BooksLibraryFAQBotViewModel()
    @State private var userInput: String = ""
    @State private var isSending: Bool = false
    @State private var hasSelectedQuestion: Bool = false
    
    // Predefined questions for quick access
    private let predefinedQuestions = [
        ("When is the library open?", "clock.fill"),
        ("How can I borrow books?", "book.circle.fill"),
        ("Can I reserve a book?", "bookmark.fill"),
        ("How do I find a book?", "magnifyingglass"),
        ("What books are available?", "books.vertical.fill"),
        ("Suggest a book for me!", "star.fill")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(UIConstants.accentColor)
                    .font(.system(size: 28))
                Text("AnyBook Assistant")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(UIConstants.accentColor)
                Spacer()
                Button(action: {
                    viewModel.clearChat()
                    hasSelectedQuestion = false
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Circle().fill(.white).shadow(radius: 2))
                }
                .accessibilityLabel("Clear chat history")
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(UIConstants.backgroundColor)
            
            // Chat History or Empty State
            ScrollViewReader { scrollView in
                ScrollView {
                    if viewModel.messages.isEmpty && !hasSelectedQuestion {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Hi! I'm your Library Book Buddy. Pick a question or ask about books and library services! 📚")
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            ForEach(predefinedQuestions, id: \.0) { question, icon in
                                Button(action: {
                                    userInput = question
                                    sendMessage()
                                    hasSelectedQuestion = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: icon)
                                            .font(.system(size: 16))
                                        Text(question)
                                            .font(.system(size: 16, weight: .medium, design: .serif))
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(UIConstants.accentColor.opacity(0.1))
                                    .cornerRadius(10)
                                    .foregroundColor(UIConstants.accentColor)
                                }
                                .accessibilityLabel("Ask: \(question)")
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .padding(.top, 32)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typingIndicator")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                .onChange(of: viewModel.messages) { _ in
                    withAnimation {
                        if let lastMessage = viewModel.messages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) { _ in
                    if viewModel.isTyping {
                        withAnimation {
                            scrollView.scrollTo("typingIndicator", anchor: .bottom)
                        }
                    }
                }
            }
            .background(UIConstants.backgroundColor)
            
            // Input Area
            if hasSelectedQuestion {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask about books or the library...", text: $userInput)
                        .font(.system(size: 16, design: .serif))
                        .padding(12)
                        .background(.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(UIConstants.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(isSending)
                        .accessibilityLabel("Enter your library question")
                    
                    Button(action: sendMessage) {
                        Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(userInput.isEmpty || isSending ? .gray : UIConstants.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .disabled(userInput.isEmpty || isSending)
                    .accessibilityLabel("Send question")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(UIConstants.backgroundColor)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.2)),
                    alignment: .top
                )
            }
        }
        .background(UIConstants.backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(.red)
                        .padding()
                        .background(.white.opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .transition(.opacity)
                }
            }
        )
        .onAppear {
            viewModel.fetchBooks()
        }
    }
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            viewModel.showError("Please type a question to ask me! 😊")
            return
        }
        guard userInput.count <= UIConstants.maxMessageLength else {
            viewModel.showError("Message too long! Please keep it under \(UIConstants.maxMessageLength) characters.")
            return
        }
        
        let message = ChatMessage(id: UUID(), content: userInput, isUser: true)
        viewModel.addMessage(message)
        isSending = true
        
        Task {
            await viewModel.sendMessageToOpenRouter(userInput)
            isSending = false
        }
        
        userInput = ""
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .font(.system(size: 16, design: .serif))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(12)
                .background(message.isUser ? UIConstants.messageBubbleColorUser : UIConstants.messageBubbleColorAI)
                .cornerRadius(20)
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                .shadow(radius: 1)
            
            if !message.isUser { Spacer() }
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(message.isUser ? "Your" : "Book Buddy") message: \(message.content)")
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(UIConstants.accentColor.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(0.2 * Double(index)),
                        value: animationOffset
                    )
            }
        }
        .padding(12)
        .background(UIConstants.messageBubbleColorAI)
        .cornerRadius(20)
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - Data Models
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.isUser == rhs.isUser
    }
}

// MARK: - OpenRouter Response Model
struct OpenRouterResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]?
    let error: APIError?
    
    struct APIError: Codable {
        let message: String
    }
}

// MARK: - ViewModel
@MainActor
class BooksLibraryFAQBotViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String = ""
    @Published var books: [AdminBook] = []
    @Published var isTyping: Bool = false
    
    private let openRouterURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "meta-llama/llama-3.1-8b-instruct:free"
    private let db = Firestore.firestore()
    private let maxRetries = 3
    private let cacheKey = "cachedBooks"
    private let systemPrompt = """
        You are Library Book Buddy, a friendly assistant for a books-only library. Answer questions about library services (hours, borrowing, reservations, renewals, fines) or book catalog (search, availability, genres, authors). Use a warm, concise tone like a librarian. Clarify unclear queries gently (e.g., "Could you share more? 😊"). Use the catalog for book details. If no match, suggest checking spelling or broadening search. Be enthusiastic for recommendations!

        Examples:
        - Hours: "Open Mon-Fri 9 AM-8 PM, Sat 10 AM-5 PM, closed Sun. Visit soon! 😊"
        - Borrowing: "Borrow 5 books for 3 weeks. One renewal unless reserved. Fines $1/day/book."
        - Reservations: "Reserve via catalog or desk; held for 48 hours."
        - Search: "'Pride and Prejudice' by Jane Austen is available! What's next? 📚"
        - Query: "'The Great Gatsby' (Fiction, Classics) has 2/3 copies available. Reserve?"
        - Recommendation: "Try '1984' by George Orwell—thrilling and available! 📖"
    """
    
    init() {
        loadMessages()
        loadCachedBooks()
    }
    
    // MARK: - Message Management
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        saveMessages()
    }
    
    func clearChat() {
        messages.removeAll()
        saveMessages()
    }
    
    func showError(_ message: String) {
        errorMessage = message
        print("Error: \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = ""
        }
    }
    
    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: "chatMessages")
        } catch {
            showError("Failed to save chat history: \(error.localizedDescription)")
        }
    }
    
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: "chatMessages") else { return }
        do {
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            showError("Failed to load chat history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Book Cache Management
    private func saveCachedBooks() {
        guard !books.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(books)
            UserDefaults.standard.set(data, forKey: cacheKey)
            print("Cached \(books.count) books")
        } catch {
            showError("Failed to cache books: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedBooks() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        do {
            let cachedBooks = try JSONDecoder().decode([AdminBook].self, from: data)
            if !cachedBooks.isEmpty {
                books = cachedBooks
                print("Loaded \(cachedBooks.count) cached books")
            }
        } catch {
            showError("Failed to load cached books: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firestore Book Fetching
    func fetchBooks() {
        Task {
            do {
                let snapshot = try await db.collection("BooksCatalog").getDocuments()
                guard !snapshot.documents.isEmpty else {
                    showError("No books found in the catalog.")
                    return
                }
                
                let newBooks = snapshot.documents.compactMap { document -> AdminBook? in
                    let data = document.data()
                    guard let title = data["title"] as? String, !title.isEmpty,
                          let author = data["author"] as? String, !author.isEmpty else {
                        print("Skipping book with missing title/author: \(document.documentID)")
                        return nil
                    }
                    
                    let coverImageURL = data["coverImageURL"] as? String ?? ""
                    let createdDate: String
                    if let timestamp = data["createdAt"] as? Timestamp {
                        let date = timestamp.dateValue()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a zzz"
                        formatter.timeZone = TimeZone(identifier: "UTC+05:30")
                        createdDate = formatter.string(from: date)
                    } else {
                        createdDate = data["createdAt"] as? String ?? "Unknown"
                    }
                    
                    let totalCopies = data["numberOfCopies"] as? Int ?? 0
                    let borrowedCopies = data["borrowedCopies"] as? Int ?? 0
                    let availableCopies = max(0, totalCopies - borrowedCopies)
                    let genresString = data["genres"] as? String ?? ""
                    let genresArray = genresString
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    
                    return AdminBook(
                        id: document.documentID,
                        title: title,
                        author: author,
                        genres: genresArray,
                        coverImageURL: coverImageURL,
                        description: data["summary"] as? String ?? "No description available.",
                        dueDate: data["dueDate"] as? String,
                        isAvailable: availableCopies > 0,
                        totalCopies: totalCopies,
                        borrowedCopies: borrowedCopies,
                        availableCopies: availableCopies,
                        createdDate: createdDate
                    )
                }
                
                if newBooks.isEmpty {
                    showError("No valid books found in the catalog.")
                    return
                }
                
                self.books = newBooks
                self.saveCachedBooks()
                print("Fetched \(newBooks.count) books from Firestore")
            } catch {
                showError("Failed to fetch books: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - OpenRouter API Integration
    func sendMessageToOpenRouter(_ message: String) async {
        guard let apiKey = loadAPIKey() else {
            showError("API setup issue. Please try again later.")
            return
        }
        
        isTyping = true
        
        var request = URLRequest(url: URL(string: openRouterURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Limit catalog to 50 books to reduce payload size
        let bookCatalogContext = books.prefix(50).map { book in
            """
            Title: \(book.title)
            Author: \(book.author)
            Genres: \(book.genres.joined(separator: ", "))
            Availability: \(book.isAvailable ? "\(book.availableCopies)/\(book.totalCopies) copies" : "Borrowed")
            """
        }.joined(separator: "\n")
        
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "\(systemPrompt)\n\n**Catalog (limited to 50 books)**:\n\(bookCatalogContext.isEmpty ? "No books." : bookCatalogContext)"],
                ["role": "user", "content": "Hi! I'm your Library Book Buddy. What's up? 📚"]
            ] + messages.map { ["role": $0.isUser ? "user" : "assistant", "content": $0.content] } +
              [["role": "user", "content": message]]
        ]
        
        for attempt in 1...maxRetries {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    showError("Network issue. Check your connection.")
                    return
                }
                
                if httpResponse.statusCode == 429 && attempt < maxRetries {
                    let delay = attempt * 2 // Exponential backoff: 2s, 4s, 6s
                    print("Rate limit hit, retrying after \(delay) seconds")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    showError("Server error (HTTP \(httpResponse.statusCode)). Try again!")
                    return
                }
                
                let jsonResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
                if let error = jsonResponse.error {
                    showError("API error: \(error.message)")
                    return
                }
                
                guard let content = jsonResponse.choices?.first?.message.content else {
                    showError("No response from API. Using fallback response.")
                    let fallback = "I couldn't fetch a response right now, but I can still help! Try asking about library hours or a book like 'Pride and Prejudice'. 😊"
                    let aiMessage = ChatMessage(id: UUID(), content: fallback, isUser: false)
                    addMessage(aiMessage)
                    return
                }
                
                print("Received response: \(content)")
                let aiMessage = ChatMessage(id: UUID(), content: content, isUser: false)
                addMessage(aiMessage)
                isTyping = false
                return
            } catch {
                showError("Failed to process API response: \(error.localizedDescription).")
                print("API error: \(error)")
                if attempt == maxRetries {
                    let fallback = "Sorry, I'm having trouble connecting. Try asking about library services or check the catalog later! 📚"
                    let aiMessage = ChatMessage(id: UUID(), content: fallback, isUser: false)
                    addMessage(aiMessage)
                    isTyping = false
                    return
                }
            }
        }
    }
    
    private func loadAPIKey() -> String? {
        let key = "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"
        return key.isEmpty ? nil : key
    }
}

// MARK: - Preview
struct BooksLibraryFAQBotView_Previews: PreviewProvider {
    static var previews: some View {
        BooksLibraryFAQBotView()
            .previewDevice("iPhone 14")
            .previewDisplayName("iPhone 14")
            .preferredColorScheme(.light)
    }
}
