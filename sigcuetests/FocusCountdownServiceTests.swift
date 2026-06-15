import XCTest
@testable import sigcue

final class FocusCountdownServiceTests: XCTestCase {

    var mockCalendarService: MockCalendarService!
    var service: FocusCountdownService!

    override func setUp() {
        super.setUp()
        mockCalendarService = MockCalendarService()
        service = FocusCountdownService(calendarService: mockCalendarService)
    }

    override func tearDown() {
        service.stop()
        super.tearDown()
    }

    // MARK: - Auto-Join Tests

    func testSetAutoJoinSchedulesCorrectTime() {
        let meetingStart = Date().addingTimeInterval(10 * 60)
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: meetingStart,
            endDate: meetingStart.addingTimeInterval(30 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/test")
        )
        mockCalendarService.events = [event]

        service.nextEvent = event
        service.setAutoJoin(inMinutes: 5)

        XCTAssertNotNil(service.autoJoinTime)
        let expectedTime = meetingStart.addingTimeInterval(-5 * 60)
        XCTAssertEqual(service.autoJoinTime?.timeIntervalSince(expectedTime), 0, accuracy: 1)
    }

    func testSetAutoJoinWithDifferentMinutes() {
        let meetingStart = Date().addingTimeInterval(20 * 60)
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: meetingStart,
            endDate: meetingStart.addingTimeInterval(30 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/test")
        )

        service.nextEvent = event
        service.setAutoJoin(inMinutes: 2)

        let expectedTime = meetingStart.addingTimeInterval(-2 * 60)
        XCTAssertEqual(service.autoJoinTime?.timeIntervalSince(expectedTime), 0, accuracy: 1)
    }

    func testCancelAutoJoinClearsTime() {
        let meetingStart = Date().addingTimeInterval(10 * 60)
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: meetingStart,
            endDate: meetingStart.addingTimeInterval(30 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/test")
        )

        service.nextEvent = event
        service.setAutoJoin(inMinutes: 5)
        XCTAssertNotNil(service.autoJoinTime)

        service.cancelAutoJoin()
        XCTAssertNil(service.autoJoinTime)
        XCTAssertFalse(service.hasAutoJoined)
    }

    func testAutoJoinResetOnEventChange() {
        let event1 = MeetingEvent(
            id: "test1",
            title: "Meeting 1",
            startDate: Date().addingTimeInterval(10 * 60),
            endDate: Date().addingTimeInterval(40 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/test1")
        )

        service.nextEvent = event1
        service.setAutoJoin(inMinutes: 5)
        XCTAssertNotNil(service.autoJoinTime)

        // Change to a different event
        let event2 = MeetingEvent(
            id: "test2",
            title: "Meeting 2",
            startDate: Date().addingTimeInterval(60 * 60),
            endDate: Date().addingTimeInterval(90 * 60),
            calendar: "Work",
            videoLink: URL(string: "https://zoom.us/test2")
        )

        service.nextEvent = event2
        // Auto-join time should remain from event1 (not automatically cleared)
        // but hasAutoJoined should reset
        XCTAssertFalse(service.hasAutoJoined)
    }

    // MARK: - Urgency Color Tests

    func testUrgencyColorGreen() {
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: Date().addingTimeInterval(15 * 60),
            endDate: Date().addingTimeInterval(45 * 60),
            calendar: "Work"
        )
        mockCalendarService.events = [event]
        service.nextEvent = event
        service.remaining = 15 * 60

        XCTAssertEqual(service.urgencyColor, .green)
    }

    func testUrgencyColorYellow() {
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: Date().addingTimeInterval(7 * 60),
            endDate: Date().addingTimeInterval(37 * 60),
            calendar: "Work"
        )
        mockCalendarService.events = [event]
        service.nextEvent = event
        service.remaining = 7 * 60

        XCTAssertEqual(service.urgencyColor, .yellow)
    }

    func testUrgencyColorRed() {
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: Date().addingTimeInterval(3 * 60),
            endDate: Date().addingTimeInterval(33 * 60),
            calendar: "Work"
        )
        mockCalendarService.events = [event]
        service.nextEvent = event
        service.remaining = 3 * 60

        XCTAssertEqual(service.urgencyColor, .red)
    }

    // MARK: - Breathing Phase Tests

    func testBreathingPhaseZeroWhenGreen() {
        let event = MeetingEvent(
            id: "test",
            title: "Test",
            startDate: Date().addingTimeInterval(15 * 60),
            endDate: Date().addingTimeInterval(45 * 60),
            calendar: "Work"
        )
        service.nextEvent = event
        service.remaining = 15 * 60

        XCTAssertEqual(service.breathingPhase, 0)
    }

    func testBreathingPhaseZeroWhenNoEvent() {
        service.nextEvent = nil
        XCTAssertEqual(service.breathingPhase, 0)
    }
}

// MARK: - Mock Calendar Service

class MockCalendarService: CalendarServiceProtocol {
    var authorizationStatus: EventKit.EKAuthorizationStatus = .authorized
    var events: [MeetingEvent] = []
    var availableCalendars: [EventKit.EKCalendar] = []

    func requestAccess() async -> Bool {
        return true
    }

    func fetchEvents() {
        // Mock implementation
    }
}
