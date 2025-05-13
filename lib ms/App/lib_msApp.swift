//
//  lib_msApp.swift
//  lib ms
//
//  Created by admin100 on 22/04/25.
//

import SwiftUI
import FirebaseCore

@main
struct lib_msApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase configured: \(FirebaseApp.app() != nil)") // Debug confirmation
        return true
    }
}
