// ReserveButton.swift
import SwiftUI
import FirebaseAuth

struct ReserveButton: View {
    let bookID: String
    @ObservedObject var catalogViewModel: MemberCatalogViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var isReserving = false
    @State private var errorMessage: String?
    @State private var showDatePicker = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(15 * 24 * 60 * 60) // 15 days from now
    @State private var showSuccessMessage = false
    
    private let buttonGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.3, green: 0.5, blue: 0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        Button(action: {
            if libraryViewModel.borrowedBooks.count >= 5 {
                errorMessage = "You have reached the maximum limit of 5 borrowed books. Please return some books before making new reservations."
            } else {
                showDatePicker = true
            }
        }) {
            HStack {
                Image(systemName: "book")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(isReserving ? "Reserving..." : "Reserve")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(buttonGradient)
            .cornerRadius(12)
            .shadow(radius: 2)
            .disabled(isReserving)
        }
        .sheet(isPresented: $showDatePicker) {
            DateSelectionView(
                startDate: $startDate,
                endDate: $endDate,
                isReserving: $isReserving,
                onSave: saveReservation
            )
        }
        .alert(isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Reservation Error"),
                message: Text(errorMessage ?? "An error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Reservation Request Sent", isPresented: $showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your reservation request for the period \(formatDate(startDate)) to \(formatDate(endDate)) has been sent to the library for approval. You will be notified once your request is reviewed.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func saveReservation() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to reserve a book."
            return
        }
        
        isReserving = true
        libraryViewModel.createBookRequest(
            memberID: userID,
            bookID: bookID,
            startDate: startDate,
            endDate: endDate
        )
        // Delay to simulate async operation (Firestore updates are handled by snapshot listeners)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isReserving = false
            showDatePicker = false
            showSuccessMessage = true
        }
    }
}

struct DateSelectionView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isReserving: Bool
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var maxEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 15, to: startDate) ?? startDate
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Reservation Period")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { newStartDate in
                            // If end date is before new start date, update it
                            if endDate < newStartDate {
                                endDate = newStartDate
                            }
                            // If end date is more than 15 days from new start date, cap it
                            if endDate > maxEndDate {
                                endDate = maxEndDate
                            }
                        }
                    
                    DatePicker("End Date", selection: $endDate, in: startDate...maxEndDate, displayedComponents: .date)
                }
                
                Section {
                    Button(action: {
                        if Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0 > 15 {
                            errorMessage = "Reservation period cannot exceed 15 days"
                            showError = true
                        } else {
                            onSave()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Confirm Reservation")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .disabled(isReserving)
                }
            }
            .navigationTitle("Reservation Period")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Invalid Date Range"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ReserveButton_Previews: PreviewProvider {
    static var previews: some View {
        ReserveButton(
            bookID: "123456",
            catalogViewModel: MemberCatalogViewModel(),
            libraryViewModel: LibraryViewModel()
        )
        .previewDevice("iPhone 14")
    }
}
