import Foundation

@main
struct DesktopSetupChecks {
    static func main() {
        let suite = "com.kamihi.setup-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = DesktopSetupProgress(defaults: defaults)
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("FAIL: \(label)") }
            count += 1
            print("PASS: \(label)")
        }

        check(!progress.isComplete && progress.step == .welcome, "Fresh install starts at welcome")
        check(!progress.finish() && !progress.isComplete, "Cannot complete from an unfinished step")
        progress.goBack()
        check(progress.step == .welcome, "Back is bounded at welcome")
        progress.advance()
        check(progress.step == .connection, "Continue reaches connection")
        check(DesktopSetupProgress(defaults: defaults).step == .connection, "A relaunch resumes saved progress")
        check(!DesktopSetupProgress(defaults: defaults).isComplete, "Deferring does not mark setup complete")
        progress.goBack()
        check(progress.step == .welcome, "Back persists the earlier step")
        for expected in DesktopSetupStep.allCases.dropFirst() {
            progress.advance()
            check(progress.step == expected, "Forward step: \(expected.rawValue)")
        }
        progress.advance()
        check(progress.step == .ready, "Forward is bounded at ready")
        defaults.set("keep-this-note", forKey: "unrelated-user-data")
        check(progress.finish(), "Ready can finish without claiming display connectivity")
        check(progress.isComplete && progress.step == .welcome, "Completion persists and resets only guide position")
        progress.beginReview()
        check(progress.isComplete && progress.step == .welcome, "Review preserves prior completion")
        check(defaults.string(forKey: "unrelated-user-data") == "keep-this-note", "Setup does not erase other preferences")
        defaults.set("future-or-corrupt-step", forKey: DesktopSetupProgress.stepKey)
        check(progress.step == .welcome, "Unknown saved step recovers to welcome")
        defaults.set(DesktopSetupProgress.version + 5, forKey: DesktopSetupProgress.completedKey)
        check(progress.isComplete, "Newer completion versions are respected")
        progress.step = .ready
        check(progress.finish() && defaults.integer(forKey: DesktopSetupProgress.completedKey) == DesktopSetupProgress.version + 5, "Review cannot downgrade a newer completion")
        defaults.set(0, forKey: DesktopSetupProgress.completedKey)
        check(!progress.isComplete, "Older setup versions require the updated guide")
        print("Desktop setup regression checks: \(count) passed")
    }
}
