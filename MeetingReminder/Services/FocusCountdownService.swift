import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let focusCountdownResetPosition = Notification.Name("focusCountdownResetPosition")
}

@MainActor
final class FocusCountdownService: ObservableObject {
    @Published private(set) var nextEvent: MeetingEvent?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var initialRemaining: TimeInterval = 0

    private let calendarService: any CalendarServiceProtocol
    private var timer: Timer?
    private var trackedEventID: String?

    init(calendarService: any CalendarServiceProtocol) {
        self.calendarService = calendarService
    }

    /// Fraction of the free-time gap that has elapsed, 0 → 1.
    var progress: Double {
        guard initialRemaining > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / initialRemaining))
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let allEvents = calendarService.events

        let next = allEvents
            .filter { $0.startDate > now }
            .min(by: { $0.startDate < $1.startDate })

        if next?.id != trackedEventID {
            trackedEventID = next?.id
            if let next {
                let priorEnd = allEvents
                    .filter { $0.id != next.id && $0.endDate <= now }
                    .map { $0.endDate }
                    .max()
                initialRemaining = next.startDate.timeIntervalSince(priorEnd ?? now)
            } else {
                initialRemaining = 0
            }
        }

        nextEvent = next
        remaining = max(0, next?.startDate.timeIntervalSince(now) ?? 0)
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
