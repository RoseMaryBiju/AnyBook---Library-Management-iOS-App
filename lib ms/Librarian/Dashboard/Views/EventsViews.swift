import SwiftUI
import FirebaseFirestore
import _PhotosUI_SwiftUI

// Event Data Model
struct Event: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let date: Timestamp
    let eventDescription: String
    let bannerURL: String? // Added for event banner image
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case eventDescription = "description"
        case bannerURL
    }
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }
}


// Event Row View (used in LibrarianDashboardView)
struct EventRow: View {
    let event: Event
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Banner Image or Placeholder
            if let bannerURL = event.bannerURL, let url = URL(string: bannerURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    @unknown default:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 6)
                
                Text(dateFormatter.string(from: event.date.dateValue()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(event.eventDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(height: 76)
        .background(Color(.systemBackground))
        .onTapGesture {
            onTap()
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// Event Card View (used in EventsView)
struct EventCardView: View {
    let event: Event
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Banner Image or Placeholder
            if let bannerURL = event.bannerURL, let url = URL(string: bannerURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    @unknown default:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Event Details (Title, Date, and Chevron)
            HStack {
                Text(event.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text(dateFormatter.string(from: event.date.dateValue()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// Visual Effect View for Blur
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

struct EventDetailView: View {
    let event: Event
    let onDelete: () -> Void
    let onEdit: () -> Void
    @Environment(\.dismiss) var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Banner image
                    if let bannerURL = event.bannerURL, let url = URL(string: bannerURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .clipped()
                                //.clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                //.padding(.horizontal, 20)
                        } placeholder: {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .foregroundColor(.gray)
                                .background(Color.gray.opacity(0.1))
                                //.clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                //.padding(.horizontal, 20)
                        }
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            //.clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            //.padding(.horizontal, 20)
                    }

                    // Event details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .padding(.top, 4)

                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                            Text(dateFormatter.string(from: event.date.dateValue()))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Description
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 8)

                        Text(event.eventDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 20)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            onDelete()
                            dismiss()
                        }) {
                            Text("Delete")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 2)
                        }
                        .accessibilityLabel("Delete Event")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                )
                .padding(.top, 0)
            }
        }
    }
}

// Edit Event View
struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    let event: Event
    let onSave: () -> Void
    
    @State private var title: String
    @State private var date: Date
    @State private var description: String
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: Image?
    
    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty
    }
    
    init(event: Event, onSave: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _date = State(initialValue: event.date.dateValue())
        _description = State(initialValue: event.eventDescription)
        _selectedImage = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Image Picker Section
                    VStack {
                        if let selectedImage = selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                        } else if let bannerURL = event.bannerURL, let url = URL(string: bannerURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                case .failure, .empty:
                                    placeholderImage
                                @unknown default:
                                    placeholderImage
                                }
                            }
                        } else {
                            placeholderImage
                        }
                        
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose New Image")
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedPhoto) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = Image(uiImage: uiImage)
                                } else {
                                    errorMessage = "Failed to load the selected image."
                                }
                            }
                        }
                    }
                    
                    Form {
                        Section(header: Text("Event Details")) {
                            // Title and Date Picker Side by Side
                            HStack {
                                TextField("Event Title", text: $title)
                                    .autocapitalization(.words)
                                
                                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .frame(maxWidth: 150)
                            }
                            
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.vertical, 4)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            updateEvent()
                        }) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(isFormValid ? .blue : .gray)
                        .disabled(!isFormValid || isSaving)
                    }
                }
            }
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            VStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("Select Event Banner")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
    }
    
    private func updateEvent() {
        guard isFormValid else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            var bannerURL: String? = event.bannerURL
            if let selectedPhoto = selectedPhoto,
               let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                do {
                    bannerURL = try await uploadImageToCloudinary(imageData: data)
                } catch {
                    self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    self.isSaving = false
                    return
                }
            }
            
            let db = Firestore.firestore()
            var updatedEventData: [String: Any] = [
                "title": title,
                "date": Timestamp(date: date),
                "description": description
            ]
            
            if let bannerURL = bannerURL {
                updatedEventData["bannerURL"] = bannerURL
            }
            
            db.collection("EventsData").document(event.id).updateData(updatedEventData) { error in
                if let error = error {
                    self.errorMessage = "Failed to update event: \(error.localizedDescription)"
                    self.isSaving = false
                } else {
                    self.onSave()
                }
            }
        }
    }
    
    private func uploadImageToCloudinary(imageData: Data) async throws -> String {
        let cloudName = "di0fauucw"
        let uploadPreset = "book_upload_preset"
        let cloudinaryURL = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
        
        var request = URLRequest(url: URL(string: cloudinaryURL)!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"event_banner.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let secureURL = json?["secure_url"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return secureURL
    }
}

// Events View (Updated to use cards with search functionality)
struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @State private var selectedEvent: Event?
    @State private var searchText: String = ""

    // Filtered events based on search text
    private var filteredEvents: [Event] {
        if searchText.isEmpty {
            return viewModel.upcomingEvents
        } else {
            return viewModel.upcomingEvents.filter { event in
                event.title.lowercased().contains(searchText.lowercased()) ||
                event.eventDescription.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText)
                .padding(.top, 8)
                .padding(.horizontal)
                .background(Color(.systemBackground))
                .zIndex(1)

            ScrollView {
                VStack(spacing: 16) {
                    if filteredEvents.isEmpty {
                        Text(searchText.isEmpty ? "No upcoming events available" : "No events match your search")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(filteredEvents) { event in
                            EventCardView(
                                event: event,
                                onTap: {
                                    selectedEvent = event
                                },
                                onDelete: {
                                    viewModel.deleteEvent(event: event)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Upcoming Events")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchUpcomingEvents()
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                onDelete: {
                    viewModel.fetchUpcomingEvents()
                },
                onEdit: {
                    viewModel.fetchUpcomingEvents()
                }
            )
        }
    }
}


