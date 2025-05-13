//
//  EventsViewModel.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI
import FirebaseFirestore
import _PhotosUI_SwiftUI

class EventsViewModel: ObservableObject {
    @Published var upcomingEvents: [Event] = []
    private let db = Firestore.firestore()
    
    func fetchUpcomingEvents() {
        let now = Timestamp(date: Date())
        db.collection("EventsData")
            .whereField("date", isGreaterThanOrEqualTo: now)
            .order(by: "date", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching upcoming events: \(error.localizedDescription)")
                    self.upcomingEvents = []
                    return
                }
                
                self.upcomingEvents = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let date = data["date"] as? Timestamp,
                          let description = data["description"] as? String else {
                        return nil
                    }
                    let bannerURL = data["bannerURL"] as? String
                    return Event(id: doc.documentID, title: title, date: date, eventDescription: description, bannerURL: bannerURL)
                } ?? []
            }
    }
    
    func deleteEvent(event: Event) {
        db.collection("EventsData").document(event.id).delete { error in
            if let error = error {
                print("Error deleting event: \(error.localizedDescription)")
            } else {
                self.fetchUpcomingEvents()
            }
        }
    }
}
