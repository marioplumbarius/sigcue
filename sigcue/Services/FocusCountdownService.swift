import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let focusCountdownResetPosition = Notification.Name("focusCountdownResetPosition")
    static let focusCountdownAutoJoin = Notification.Name("focusCountdownAutoJoin")
}

enum UrgencyColor: String {
    case green
    case yellow
    case red
}

@MainActor
final class FocusCountdownService: ObservableObject {
    @Published private(set) var nextEvent: MeetingEvent?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var initialRemaining: TimeInterval = 0
    @Published private(set) var urgencyColor: UrgencyColor = .green
    @Published private(set) var currentOpacity: Double = 1.0
    @Published private(set) var breathingPhase: Double = 0
    @Published private(set) var autoJoinTime: Date?
    @Published private(set) var hasAutoJoined: Bool = false

    private let calendarService: any CalendarServiceProtocol
    private var timer: Timer?
    private var trackedKey: String?
    private var startTime: Date = Date()

    init(calendarService: any CalendarServiceProtocol) {
        self.calendarService = calendarService
    }

    /// Fraction of the free-time gap that has elapsed, 0 → 1.
    var progress: Double {
        guard initialRemaining > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / initialRemaining))
    }

    func start() {
        startTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setAutoJoin(inMinutes: Int) {
        guard let event = nextEvent else { return }
        let targetTime = event.startDate.addingTimeInterval(-Double(inMinutes) * 60)
        autoJoinTime = targetTime
        hasAutoJoined = false
    }

    func cancelAutoJoin() {
        autoJoinTime = nil
        hasAutoJoined = false
    }

    func joinNow() {
        guard let event = nextEvent, event.videoLink != nil else { return }
        hasAutoJoined = true
        NotificationCenter.default.post(
            name: .focusCountdownAutoJoin,
            object: event
        )
    }

    private func tick() {
        let now = Date()
        let allEvents = calendarService.events

        // A meeting in progress takes priority: count down to its end and keep
        // tracking it until it's over, even if a later meeting is already queued.
        let ongoing = allEvents
            .filter { $0.startDate <= now && $0.endDate > now }
            .min(by: { $0.endDate < $1.endDate })

        // Otherwise, count down to the start of the next upcoming meeting.
        let next = allEvents
            .filter { $0.startDate > now }
            .min(by: { $0.startDate < $1.startDate })

        let target = ongoing ?? next
        let isOngoing = ongoing != nil
        let targetDate = isOngoing ? target?.endDate : target?.startDate

        // Reset the baseline only when the tracked meeting (or its phase) changes,
        // so progress doesn't jump while counting down the same meeting.
        let key = target.map { "\($0.id)|\(isOngoing)" }
        if key != trackedKey {
            trackedKey = key
            if let target {
                if isOngoing {
                    initialRemaining = target.endDate.timeIntervalSince(target.startDate)
                } else {
                    let priorEnd = allEvents
                        .filter { $0.id != target.id && $0.endDate <= now }
                        .map { $0.endDate }
                        .max()
                    initialRemaining = target.startDate.timeIntervalSince(priorEnd ?? now)
                }
            } else {
                initialRemaining = 0
            }
        }

        nextEvent = target
        remaining = max(0, targetDate?.timeIntervalSince(now) ?? 0)

        checkAutoJoin(now: now)
        updateUrgency()
    }

    private func checkAutoJoin(now: Date) {
        guard !hasAutoJoined, let autoJoinTime = autoJoinTime, let event = nextEvent else { return }

        if now >= autoJoinTime && event.videoLink != nil {
            hasAutoJoined = true
            NotificationCenter.default.post(
                name: .focusCountdownAutoJoin,
                object: event
            )
        }
    }

    private func updateUrgency() {
        let now = Date()
        guard let target = nextEvent else {
            urgencyColor = .green
            currentOpacity = 1.0
            breathingPhase = 0
            return
        }

        let isOngoing = target.startDate <= now && target.endDate > now
        let targetTime = isOngoing ? target.endDate : target.startDate
        let timeUntilTarget = targetTime.timeIntervalSince(now)
        let minutesUntil = timeUntilTarget / 60

        // Color transitions: green → yellow at 10 min, yellow → red at 5 min
        let isRed = minutesUntil <= 5
        if isRed {
            urgencyColor = .red
        } else if minutesUntil <= 10 {
            urgencyColor = .yellow
        } else {
            urgencyColor = .green
        }

        // Opacity decreases as deadline approaches using notification threshold
        let notificationMinutes = Double(UserDefaults.standard.integer(forKey: "reminderMinutes"))
        if isOngoing {
            // For ongoing meetings, fade in based on minutes until end
            let notificationEnd = Double(UserDefaults.standard.integer(forKey: "endReminderMinutes"))
            let fadeStartMinutes = max(notificationEnd, 1)
            currentOpacity = max(0.2, min(1.0, minutesUntil / fadeStartMinutes))
        } else {
            // For upcoming meetings, fade in based on minutes until start
            let fadeStartMinutes = max(notificationMinutes, 1)
            currentOpacity = max(0.2, min(1.0, minutesUntil / fadeStartMinutes))
        }

        // Calculate breathing effect when red
        if isRed {
            let breathingSpeed = Double(UserDefaults.standard.integer(forKey: "breathingSpeed"))
            let speedValue = breathingSpeed > 0 ? breathingSpeed : 1.0
            let elapsed = now.timeIntervalSince(startTime)
            let cycleDuration = 60.0 / speedValue // Convert BPM to seconds per breath
            let cyclePosition = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
            breathingPhase = sin(cyclePosition * .pi * 2) * 0.5 + 0.5
        } else {
            breathingPhase = 0
        }
    }
}

@MainActor
final class FocusCountdownCoordinator: ObservableObject {
    static let enabledKey = "focusCountdownEnabled"

    private let service: FocusCountdownService
    private let windowController = FocusCountdownWindowController()
    private var cancellables = Set<AnyCancellable>()
    private var lastEnabled: Bool?

    init(calendarService: any CalendarServiceProtocol) {
        self.service = FocusCountdownService(calendarService: calendarService)
    }

    func start() {
        applyEnabledState()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyEnabledState() }
            .store(in: &cancellables)
    }

    private func applyEnabledState() {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        guard enabled != lastEnabled else { return }
        lastEnabled = enabled
        if enabled {
            service.start()
            windowController.show(service: service)
        } else {
            service.stop()
            windowController.close()
        }
    }
}
