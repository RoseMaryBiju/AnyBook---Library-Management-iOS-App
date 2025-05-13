//
//  MemberEventsViewModel.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI
import FirebaseFirestore

class MemberEventsViewModel: ObservableObject {
    @Published var upcomingEvents: [Event] = []
    private let db = Firestore.firestore()
    
    func fetchUpcomingEvents() {
        let now = Timestamp(date: Date())
        print("Fetching upcoming events with date >= \(now.dateValue())") // Debug: Log the timestamp being queried
        
        db.collection("EventsData")
            .whereField("date", isGreaterThanOrEqualTo: now)
            .order(by: "date", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching upcoming events: \(error.localizedDescription)")
                    print("Check Firestore security rules for 'EventsData' collection access.")
                    self.upcomingEvents = []
                    return
                }
                
                print("Fetched \(snapshot?.documents.count ?? 0) documents from EventsData") // Debug: Log the number of documents fetched
                
                self.upcomingEvents = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    print("Document data: \(data)") // Debug: Log the raw document data
                    
                    guard let title = data["title"] as? String,
                          let date = data["date"] as? Timestamp else {
                        print("Failed to parse document \(doc.documentID): Missing or invalid 'title' or 'date'")
                        return nil
                    }
                    
                    // Make description optional
                    let description = data["description"] as? String ?? "No description available"
                    let bannerURL = data["bannerURL"] as? String
                    
                    let event = Event(id: doc.documentID, title: title, date: date, eventDescription: description, bannerURL: bannerURL)
                    print("Parsed event: \(event.title) on \(event.date.dateValue())") // Debug: Log the parsed event
                    return event
                } ?? []
                
                print("Total upcoming events after parsing: \(self.upcomingEvents.count)") // Debug: Log the final count
            }
    }
}
