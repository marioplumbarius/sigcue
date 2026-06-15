import AppKit
import Combine
import Foundation

@MainActor
protocol CalendarServiceProtocol: AnyObject {
    var events: [MeetingEvent] { get }
}

enum OverlayKind {
    case start
    case ending
}

@MainActor
final class MeetingMonitor: ObservableObject {
    @Published var activeOverlayEvent: MeetingEvent?
    @Published var shouldShowOverlay = false
    @Published var activeOverlayKind: OverlayKind = .start

    private var calendarService: any CalendarServiceProtocol
    private var checkTimer: Timer?
    private var shownEventIDs: Set<String> = []
    private var snoozedEvents: [String: Date] = [:]
    private var endReminderShownEventIDs: Set<String> = []
    private var endReminderSnoozes: [String: Date] = [:]
    private var lastCleanupDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    var reminderMinutes: Int {
        UserDefaults.standard.integer(forKey: "reminderMinutes").clamped(to: 1...30, default: 5)
    }

    var endReminderMinutes: Int {
        UserDefaults.standard.integer(forKey: "endReminderMinutes")
    }

    var endReminderEnabled: Bool {
        endReminderMinutes > 0
    }

    init(calendarService: any CalendarServiceProtocol) {
        self.calendarService = calendarService
    }

    func start() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingMeetings()
            }
        }
        // Also check immediately
        checkUpcomingMeetings()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func dismiss() {
        shouldShowOverlay = false
        activeOverlayEvent = nil
        activeOverlayKind = .start
    }

    func snooze(minutes: Int = 1) {
        guard let event = activeOverlayEvent else { return }
        let requested = Date().addingTimeInterval(TimeInterval(minutes * 60))
        switch activeOverlayKind {
        case .start:
            snoozedEvents[event.id] = requested
            shownEventIDs.remove(event.id)
        case .ending:
            // Never snooze past the meeting's end time.
            let until = min(requested, event.endDate)
            if until > Date() {
                endReminderSnoozes[event.id] = until
                endReminderShownEventIDs.remove(event.id)
            } else {
                // Meeting already ended — treat as acknowledge.
                endReminderShownEventIDs.insert(event.id)
            }
        }
        dismiss()
    }

    func previewOverlay() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-\(now.timeIntervalSince1970)",
            title: "Example Meeting",
            startDate: now.addingTimeInterval(2 * 60),
            endDate: now.addingTimeInterval(62 * 60),
            calendar: "Preview",
            videoLink: URL(string: "https://zoom.us/j/00000000000")
        )
        showPreviewOverlay(with: event)
    }

    func previewStartingWithVideo() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-start-\(now.timeIntervalSince1970)",
            title: "Team Standup",
            startDate: now.addingTimeInterval(2 * 60),
            endDate: now.addingTimeInterval(32 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://meet.google.com/abc-defg-hij")
        )
        showPreviewOverlay(with: event)
    }

    func previewStarted() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-started-\(now.timeIntervalSince1970)",
            title: "All Hands",
            startDate: now.addingTimeInterval(-2 * 60),
            endDate: now.addingTimeInterval(58 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/j/98765432100")
        )
        showPreviewOverlay(with: event)
    }

    func previewEnding() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-ending-\(now.timeIntervalSince1970)",
            title: "Design Review",
            startDate: now.addingTimeInterval(-28 * 60),
            endDate: now.addingTimeInterval(2 * 60),
            calendar: "Work",
            videoLink: nil
        )
        showPreviewOverlay(with: event, skipStartReminder: true)
    }

    func previewEnded() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-ended-\(now.timeIntervalSince1970)",
            title: "Sprint Planning",
            startDate: now.addingTimeInterval(-62 * 60),
            endDate: now.addingTimeInterval(-1 * 60),
            calendar: "Work",
            videoLink: nil
        )
        showPreviewOverlay(with: event, skipStartReminder: true)
    }

    private func showPreviewOverlay(with event: MeetingEvent, skipStartReminder: Bool = false) {
        class PreviewCalendarService: CalendarServiceProtocol {
            let events: [MeetingEvent]
            init(events: [MeetingEvent]) { self.events = events }
        }

        let mockService = PreviewCalendarService(events: [event])
        let tempMonitor = MeetingMonitor(calendarService: mockService)

        if skipStartReminder {
            tempMonitor.shownEventIDs.insert(event.id)
            UserDefaults.standard.set(2, forKey: "endReminderMinutes")
            tempMonitor.endReminderSnoozes[event.id] = Date().addingTimeInterval(-60)
        }

        tempMonitor.checkUpcomingMeetings()

        activeOverlayEvent = tempMonitor.activeOverlayEvent
        activeOverlayKind = tempMonitor.activeOverlayKind
        shouldShowOverlay = tempMonitor.shouldShowOverlay
    }

    func joinMeeting() {
        guard let event = activeOverlayEvent, let url = event.videoLink else { return }
        NSWorkspace.shared.open(url)
        dismiss()
    }

    private func checkUpcomingMeetings() {
        let now = Date()

        // Reset shown IDs at the start of a new day
        if !Calendar.current.isDate(now, inSameDayAs: lastCleanupDate) {
            shownEventIDs.removeAll()
            snoozedEvents.removeAll()
            endReminderShownEventIDs.removeAll()
            endReminderSnoozes.removeAll()
            lastCleanupDate = now
        }

        // Clean up expired snoozes
        snoozedEvents = snoozedEvents.filter { $0.value > now }

        checkStartReminders(now: now)

        guard !shouldShowOverlay else { return }

        checkEndReminders(now: now)
    }

    private func checkStartReminders(now: Date) {
        let reminderSeconds = TimeInterval(reminderMinutes * 60)

        for event in calendarService.events {
            let timeUntil = event.startDate.timeIntervalSince(now)

            // Skip if already shown
            guard !shownEventIDs.contains(event.id) else { continue }

            // Skip if snoozed and snooze hasn't expired
            if let snoozeUntil = snoozedEvents[event.id], now < snoozeUntil {
                continue
            }

            // Trigger overlay if event is within reminder window
            if timeUntil > 0 && timeUntil <= reminderSeconds {
                triggerOverlay(for: event, kind: .start)
                return
            }

            // Also trigger for events that are in progress (snoozed past start)
            if timeUntil <= 0 && event.endDate > now {
                triggerOverlay(for: event, kind: .start)
                return
            }
        }
    }

    private func checkEndReminders(now: Date) {
        guard endReminderEnabled else { return }

        let windowSeconds = TimeInterval(endReminderMinutes * 60)
        let preReminderSeconds = TimeInterval(reminderMinutes * 60)

        for event in calendarService.events {
            // Skip if user acknowledged this meeting's end-reminder
            if endReminderShownEventIDs.contains(event.id) { continue }

            // Skip if snoozed and snooze hasn't expired
            if let snoozeUntil = endReminderSnoozes[event.id], now < snoozeUntil {
                continue
            }

            let isInWindow = event.startDate <= now &&
                             event.endDate > now &&
                             event.endDate.timeIntervalSince(now) <= windowSeconds
            let hasExpiredSnooze = endReminderSnoozes[event.id].map { now >= $0 } ?? false

            guard isInWindow || hasExpiredSnooze else { continue }

            // Suppress if another upcoming meeting's pre-meeting reminder would fire
            // before or at this meeting's end — the regular start-reminder will cover the transition.
            let hasBackToBack = calendarService.events.contains { other in
                other.id != event.id &&
                other.startDate > now &&
                other.startDate.addingTimeInterval(-preReminderSeconds) <= event.endDate
            }

            if hasBackToBack { continue }

            triggerOverlay(for: event, kind: .ending)
            return
        }
    }

    private func triggerOverlay(for event: MeetingEvent, kind: OverlayKind) {
        switch kind {
        case .start:
            shownEventIDs.insert(event.id)
        case .ending:
            endReminderShownEventIDs.insert(event.id)
        }
        activeOverlayKind = kind
        activeOverlayEvent = event
        shouldShowOverlay = true

        if UserDefaults.standard.object(forKey: "soundEnabled") == nil ||
           UserDefaults.standard.bool(forKey: "soundEnabled") {
            NSSound.beep()
        }
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
