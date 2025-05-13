//
//  BooksIssuedData.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI

struct BooksIssuedData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct NewMembershipData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct GenreData: Identifiable {
    let id = UUID()
    let genre: String
    let count: Int
}

struct ActiveMember: Identifiable {
    let id: String
    let name: String
    let email: String
    let borrowedBooksCount: Int
}
