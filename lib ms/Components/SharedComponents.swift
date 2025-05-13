//
//  StatCard.swift
//  AnyBook
//
//  Created by admin86 on 24/04/25.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isNavigable: Bool
    let isLoaded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Icon on left, Value on right
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(isLoaded ? 1 : 0)
                    .offset(y: isLoaded ? 0 : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2), value: isLoaded)
            }
            
            // Bottom row: Title on left, Chevron on right (if navigable)
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
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoaded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// Inventory Card Component
struct InventoryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let isLoaded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
                .opacity(isLoaded ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3), value: isLoaded)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: isLoaded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }
}

// Action Card Component
struct ActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isLoaded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(width: 160, height: 160)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(0.2)), value: isLoaded)
        .accessibilityLabel("\(title): \(description)")
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)
            
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.primary)
                .padding(.vertical, 8)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
            } else {
                Image(systemName: "mic")
                    .foregroundColor(.gray)
                    .padding(.trailing, 8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MultiSelectPicker: View {
    let items: [String]
    @Binding var selections: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Button(action: {
                    if selections.contains(item) {
                        selections.remove(item)
                    } else {
                        selections.insert(item)
                    }
                }) {
                    HStack {
                        Text(item)
                        Spacer()
                        if selections.contains(item) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Select Genres")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                self.parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
