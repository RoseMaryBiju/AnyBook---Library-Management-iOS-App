//
//  SettingsView.swift
//  AnyBook
//
//  Created by admin86 on 24/04/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SettingsView: View {
    @State private var reservationDuration: Int = 6 // Default: 6 hours
    @State private var maxBorrowingDays: Int = 7 // Default: 7 days
    @State private var lateReturnFine: Double = 1.0
    @State private var damagedBookPercentage: Double = 50.0
    @State private var lostBookPercentage: Double = 100.0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    private let db = Firestore.firestore()
    private let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    private let loadingGradient = LinearGradient(gradient: Gradient(colors: [Color.gray, Color.gray]), startPoint: .leading, endPoint: .trailing)
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Library Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Reservation Duration
                        settingCard(
                            title: "Reservation Duration",
                            description: "Number of hours a book can be reserved",
                            value: Binding(
                                get: { Double(reservationDuration) },
                                set: { reservationDuration = Int($0) }
                            ),
                            icon: "calendar.badge.clock",
                            color: .blue,
                            isPercentage: false,
                            isInteger: true,
                            unit: "hours",
                            range: 3...48,
                            step: 1
                        )
                        
                        // Max Borrowing Days
                        settingCard(
                            title: "Max Borrowing Days",
                            description: "Maximum days a book can be borrowed",
                            value: Binding(
                                get: { Double(maxBorrowingDays) },
                                set: { maxBorrowingDays = Int($0) }
                            ),
                            icon: "calendar",
                            color: .green,
                            isPercentage: false,
                            isInteger: true,
                            unit: "days",
                            range: 7...60,
                            step: 1
                        )
                        
                        // Late Return Fine
                        settingCard(
                            title: "Late Return Fine",
                            description: "Daily fine for overdue books",
                            value: $lateReturnFine,
                            icon: "clock.fill",
                            color: .orange,
                            isPercentage: false,
                            isInteger: false,
                            unit: "rupees",
                            range: 0...100,
                            step: 0.5
                        )
                        
                        // Damaged Book Fine
                        settingCard(
                            title: "Damaged Book Fine",
                            description: "Percentage of book value for damaged books",
                            value: $damagedBookPercentage,
                            icon: "exclamationmark.triangle.fill",
                            color: .red,
                            isPercentage: true,
                            isInteger: false,
                            unit: "percent",
                            range: 0...100,
                            step: 1
                        )
                        
                        // Lost Book Fine
                        settingCard(
                            title: "Lost Book Fine",
                            description: "Percentage of book value for lost books",
                            value: $lostBookPercentage,
                            icon: "book.closed.fill",
                            color: .purple,
                            isPercentage: true,
                            isInteger: false,
                            unit: "percent",
                            range: 0...100,
                            step: 1
                        )
                        
                        // Save Button
                        Button(action: saveSettings) {
                            Text(isLoading ? "Saving..." : "Save Settings")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isLoading ? loadingGradient : buttonGradient)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .disabled(isLoading)
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14, design: .rounded))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .transition(.opacity)
                        }
                        
                        // Success Message
                        if showSuccessMessage {
                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.system(size: 14, design: .rounded))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(.systemBackground))
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchSettings()
            }
        }
    }
    
    private func settingCard(
        title: String,
        description: String,
        value: Binding<Double>,
        icon: String,
        color: Color,
        isPercentage: Bool,
        isInteger: Bool,
        unit: String,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 22))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // HStack to hold TextField and unit symbol
                HStack(spacing: 4) {
                    TextField("", value: value, formatter: NumberFormatter())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .keyboardType(isInteger ? .numberPad : .decimalPad)
                        .frame(width: 70) // Adjust width for better fit
                        .multilineTextAlignment(.trailing)
                        .onChange(of: value.wrappedValue) { newValue in
                            // Clamp the value to the specified range
                            value.wrappedValue = max(range.lowerBound, min(range.upperBound, newValue))
                        }
                    
                    // Display the unit symbol
                    Text({
                        switch unit {
                        case "percent":
                            return "%"
                        case "rupees":
                            return "/-"
                        case "hours":
                            return "hours"
                        case "days":
                            return "days"
                        default:
                            return ""
                        }
                    }())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                }
            }
            
            Text(description)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
            
            if isInteger {
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                    .accentColor(color)
            } else {
                Slider(value: value, in: range, step: step)
                    .accentColor(color)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func fetchSettings() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to manage settings."
            isLoading = false
            return
        }
        
        isLoading = true
        db.collection("settings").document("library").getDocument { document, error in
            isLoading = false
            if let error = error {
                print("Fetch error: \(error)")
                errorMessage = "Failed to fetch settings: \(error.localizedDescription)"
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                errorMessage = "Settings not found. Please save settings to initialize."
                return
            }
            
            reservationDuration = data["reservationDuration"] as? Int ?? 6
            maxBorrowingDays = data["maxBorrowingDays"] as? Int ?? 7
            lateReturnFine = data["lateReturnFine"] as? Double ?? 1.0
            damagedBookPercentage = data["damagedBookPercentage"] as? Double ?? 50.0
            lostBookPercentage = data["lostBookPercentage"] as? Double ?? 100.0
        }
    }
    
    private func saveSettings() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to save settings."
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = ""
        showSuccessMessage = false
        
        let settingsData: [String: Any] = [
            "reservationDuration": reservationDuration,
            "maxBorrowingDays": maxBorrowingDays,
            "lateReturnFine": lateReturnFine,
            "damagedBookPercentage": damagedBookPercentage,
            "lostBookPercentage": lostBookPercentage,
            "lastUpdated": Date()
        ]
        
        db.collection("settings").document("library").setData(settingsData) { error in
            isLoading = false
            if let error = error {
                print("Save error: \(error)")
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                return
            }
            
            successMessage = "Settings updated successfully!"
            showSuccessMessage = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessMessage = false
            }
        }
    }
}
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
