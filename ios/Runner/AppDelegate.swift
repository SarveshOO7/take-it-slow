import UIKit
import Flutter
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var blockerService: YouTubeBlockerService?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.takeitSlow/blocker",
            binaryMessenger: controller.binaryMessenger
        )

        blockerService = YouTubeBlockerService(channel: channel)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.blockerService?.handle(call, result: result)
        }

        // BGAppRefreshTask: re-block YouTube after the access window ends.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: YouTubeBlockerService.bgTaskId,
            using: nil
        ) { [weak self] task in
            self?.blockerService?.handleBackgroundUnblock(task as! BGAppRefreshTask)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
