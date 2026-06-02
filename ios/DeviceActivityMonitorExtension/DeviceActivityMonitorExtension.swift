import DeviceActivity
import ManagedSettings
import UserNotifications

// This App Extension runs in a sandboxed process outside the main app.
// The system calls it when a DeviceActivityEvent threshold is reached —
// i.e., the moment the user opens YouTube for the first time in the blocked period.

@objc(DeviceActivityMonitorExtension)
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let shared = UserDefaults(suiteName: "group.com.takeitSlow")!

    // Called when the monitored app has been used for the threshold duration (1 s).
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard event == .youtubeThreshold else { return }

        // Only trigger the countdown once per idle period.
        let alreadyTriggered = shared.bool(forKey: "countdown_triggered")
        guard !alreadyTriggered else { return }

        shared.set(true, forKey: "countdown_triggered")
        shared.set(Date().timeIntervalSince1970, forKey: "youtube_first_open_ts")

        // Block using the stored selection.
        if let data = shared.data(forKey: "app_selection"),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: data)
        {
            store.application.blockedApplications = selection.applicationTokens
            store.webDomain.blockedDomains = selection.webDomainTokens
        }

        sendCountdownNotification()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Reset the trigger flag at the end of the 24-hour interval
        // so monitoring can fire again the next day.
        shared.set(false, forKey: "countdown_triggered")
    }

    // MARK: - Notification

    private func sendCountdownNotification() {
        let content = UNMutableNotificationContent()
        content.title = "YouTube is blocked"
        content.body = "Open Take It Slow to start your 10-minute wait, then unlock YouTube."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let req = UNNotificationRequest(
            identifier: "youtube-blocked-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - Shared name extensions (must match YouTubeBlockerService.swift)

extension DeviceActivityName {
    static let youtubeWatch = Self("youtubeWatch")
}

extension DeviceActivityEvent.Name {
    static let youtubeThreshold = Self("youtubeThreshold")
}
