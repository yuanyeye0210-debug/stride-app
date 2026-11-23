import SwiftUI
import UIKit
import UserNotifications

@main
struct StrideApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var ai = AISettings.shared
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var watch = WatchSession.shared
    @StateObject private var watchMotion = WatchMotionSessionController.shared
    @StateObject private var headphone = HeadphoneMotionManager.shared

    init() {
        // 深色到这个程度，系统控件也得跟着走
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.051, green: 0.051, blue: 0.055, alpha: 1)
        tab.shadowColor = UIColor(white: 1, alpha: 0.06)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UNUserNotificationCenter.current().delegate = HeadphoneNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(ai)
                .environmentObject(health)
                .environmentObject(watch)
                .environmentObject(watchMotion)
                .environmentObject(headphone)
                .preferredColorScheme(store.preferredColorSchemeOverride ?? .dark)
                .tint(Palette.green)
                .task {
                    headphone.startSessionTracking()
                    if LaunchFlags.simulateWatch {
                        watch.activate()
                    }
                }
        }
    }
}
