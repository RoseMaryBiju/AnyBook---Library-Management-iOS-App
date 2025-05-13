//
//  MemberBook.swift
//  lib ms
//
//  Created by admin86 on 06/05/25.
//

import Foundation
import FirebaseFirestore

struct MemberBook: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Firestore document ID (ISBN)
    var title: String
    var author: String
    var illustrator: String?
    var genres: String
    var isbn: String
    var language: String
    var bookFormat: String
    var edition: String
    var pages: Int
    var publisher: String
    var description: String
    var isAvailable: Bool
    var createdAt: Timestamp
    var isFavorite: Bool
    var numberOfCopies: Int
    var unavailableCopies: Int
    var coverImageURL: String?
    var authorID: String? // New field for author OLID
    var cost: Double // Added for fine calculations

    // Custom initializer to create a MemberBook instance with all properties except id
    init(
        title: String,
        author: String,
        illustrator: String?,
        genres: String,
        isbn: String,
        language: String,
        bookFormat: String,
        edition: String,
        pages: Int,
        publisher: String,
        description: String,
        isAvailable: Bool,
        createdAt: Timestamp,
        isFavorite: Bool,
        numberOfCopies: Int,
        unavailableCopies: Int,
        coverImageURL: String?,
        authorID: String? = nil,
        cost: Double = 20.0 // Default cost if not specified
    ) {
        self.title = title
        self.author = author
        self.illustrator = illustrator
        self.genres = genres
        self.isbn = isbn
        self.language = language
        self.bookFormat = bookFormat
        self.edition = edition
        self.pages = pages
        self.publisher = publisher
        self.description = description
        self.isAvailable = isAvailable
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.numberOfCopies = numberOfCopies
        self.unavailableCopies = unavailableCopies
        self.coverImageURL = coverImageURL
        self.authorID = authorID
        self.cost = cost
    }

    // CodingKeys to map Firestore fields to struct properties
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case illustrator
        case genres
        case isbn
        case language
        case bookFormat
        case edition
        case pages
        case publisher
        case description
        case isAvailable
        case createdAt
        case isFavorite
        case numberOfCopies
        case unavailableCopies
        case coverImageURL
        case authorID
        case cost // Added new field
    }

    // Custom initializer for decoding to handle missing or invalid fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id into a temporary variable first
        let decodedId = try container.decode(DocumentID<String>.self, forKey: .id)
        
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown Title"
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? "Unknown Author"
        self.illustrator = try container.decodeIfPresent(String.self, forKey: .illustrator)
        self.genres = try container.decodeIfPresent(String.self, forKey: .genres) ?? ""
        self.isbn = try container.decodeIfPresent(String.self, forKey: .isbn) ?? (decodedId.wrappedValue ?? "Unknown ISBN")
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? "Unknown"
        self.bookFormat = try container.decodeIfPresent(String.self, forKey: .bookFormat) ?? "Unknown"
        self.edition = try container.decodeIfPresent(String.self, forKey: .edition) ?? "Unknown"
        self.pages = try container.decodeIfPresent(Int.self, forKey: .pages) ?? 0
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher) ?? "Unknown"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
        self.createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) ?? Timestamp(date: Date())
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.numberOfCopies = try container.decodeIfPresent(Int.self, forKey: .numberOfCopies) ?? 0
        self.unavailableCopies = try container.decodeIfPresent(Int.self, forKey: .unavailableCopies) ?? 0
        self.coverImageURL = try container.decodeIfPresent(String.self, forKey: .coverImageURL)
        self.authorID = try container.decodeIfPresent(String.self, forKey: .authorID)
        self.cost = try container.decodeIfPresent(Double.self, forKey: .cost) ?? 20.0 // Default cost if not specified
        
        // Assign the decoded id to self._id after all other properties are initialized
        self._id = decodedId
    }
}
