//
//  AdminProfileView.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI

struct AdminProfileView: View {
    let name: String
    let email: String
    @Binding var isDarkMode: Bool
    let onLogout: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading) {
                        Text(name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                        Text(email)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)

                Toggle(isOn: $isDarkMode) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(isDarkMode ? .yellow : .gray)
                            .frame(width: 24, height: 24)
                        Text("Dark Mode")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)

                Button(action: onLogout) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                        Text("Log out")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(isDarkMode ? 0.2 : 0.1), radius: 5)
    }
}

struct AdminBooksManagementView: View {
    var body: some View {
        AdminCatalogManagementView()
    }
}
