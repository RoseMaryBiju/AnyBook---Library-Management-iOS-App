//
//  ReservedBooksView.swift
//  AnyBook
//
//  Created by admin86 on 24/04/25.
//

import SwiftUI

struct ReservedBooksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reserved & Requested Books")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: Text("Reserved Books Detail")) {
                    CatalogStatCard(
                        title: "Reserved Books",
                        value: "4",
                        icon: "bookmark.fill",
                        color: .purple,
                        isNavigable: true // Navigable
                    )
                }
                
                NavigationLink(destination: Text("Requested Books Detail")) {
                    CatalogStatCard(
                        title: "Requested Books",
                        value: "2",
                        icon: "person.crop.circle.badge.questionmark",
                        color: .teal,
                        isNavigable: true // Navigable
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
