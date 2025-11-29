//
//  SharedListApp.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SharedListApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var listViewModel = ListViewModel()
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if !authViewModel.isAuthenticated {
                LoginView()
                    .environment(authViewModel)
            } else if !authViewModel.isNicknameSet {
                NicknameSetupView()
                    .environment(authViewModel)
            } else {
                SharedListView()
                    .environment(listViewModel)
                    .environment(authViewModel)
            }
        }
    }
}
