import Foundation

/// Personal build defaults. Existing Atoll preferences are read only; the fork
/// has its own preference domain and keeps its settings across later launches.
enum EfficientBuild {
    static let bundleIdentifier = "com.chaseculbertson.AtollEfficient"
    static var isEnabled: Bool { Bundle.main.bundleIdentifier == bundleIdentifier }

    static func configure() {
        guard isEnabled else { return }
        let settings = UserDefaults.standard
        guard !settings.bool(forKey: "efficientBuildConfigured") else { return }
        let original = settings.persistentDomain(forName: "com.Ebullioscopic.Atoll") ?? [:]
        let appearancePrefixes = ["lockScreen", "music", "player", "visualizer", "notch", "sneakPeek"]
        let retainedKeys: Set<String> = [
            "mediaController", "enableMinimalisticUI", "openNotchOnHover", "minimumHoverDuration",
            "enableHaptics", "enableGestures", "enableHorizontalMusicGestures", "coloredSpectrogram",
            "useMusicVisualizer", "enableWaveformScrubber", "enableSneakPeek", "showSneakPeekOnTrackChange",
            "enableSystemHUD", "enableVolumeHUD", "enableBrightnessHUD", "enableKeyboardBacklightHUD",
            "enableCustomOSD", "enableVerticalHUD", "enableCircularHUD", "playVolumeChangeFeedback",
            "showStandardMediaControls", "showMediaOutputControl", "autoHideInactiveNotchMediaPlayer",
            "enableLockScreenMediaWidget", "enableLockScreenLiveActivity", "enableLockScreenTimerWidget",
            "enableLockScreenWeatherWidget", "enableLockScreenFocusWidget", "enableLockScreenReminderWidget"
        ]
        for (key, value) in original where retainedKeys.contains(key) || appearancePrefixes.contains(where: key.hasPrefix) {
            // Do not import histories, credentials, or serialized app data.
            if value is String || value is NSNumber || value is [String] {
                settings.set(value, forKey: key)
            }
        }
        applyLowPowerDefaults()
        settings.set(true, forKey: "efficientBuildConfigured")
    }

    /// Also used after onboarding, whose upstream profiles enable collectors.
    /// Run only at setup boundaries so later user choices remain persistent.
    static func applyLowPowerDefaults(to settings: UserDefaults = .standard) {
        let disabled = [
            "enableStatsFeature", "enableLLMUsageFeature", "enableClipboardManager",
            "enableDownloadListener", "enableSafariDownloads", "enableTerminalFeature",
            "enableScreenAssistant", "enableRealTimeWaveform", "showCalendar",
            "showAirPodsListeningModeChanges", "mirrorSystemTimer"
        ]
        disabled.forEach { settings.set(false, forKey: $0) }
        settings.set(true, forKey: "statsStopWhenNotchCloses")
        settings.set(false, forKey: "SUEnableAutomaticChecks")
        settings.set(false, forKey: "SUAutomaticallyUpdate")
    }
}
