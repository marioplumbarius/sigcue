import SwiftUI

struct OverlayView: View {
    let event: MeetingEvent
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void
    let onJoin: () -> Void

    @AppStorage("overlayBackground") private var overlayBackground: String = "dark"
    @State private var appeared = false
    @State private var countdown: String = ""
    @State private var timer: Timer?
    @State private var snoozeOptions: [Int] = [1, 2, 5, 10]

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(currentBackground)

            VStack(spacing: 24) {
                Spacer()

                // Calendar icon
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))

                // Meeting title
                Text(event.title)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Time info
                Text(countdown)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text(event.formattedStartTime)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))

                // Calendar name
                Text(event.calendar)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, -8)

                Spacer()

                // Action buttons
                HStack(spacing: 20) {
                    if event.videoLink != nil {
                        Button(action: onJoin) {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                Text("Join \(videoServiceName)")
                            }
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    }

                    Menu {
                        ForEach(snoozeOptions, id: \.self) { minutes in
                            Button(snoozeLabel(minutes: minutes)) {
                                onSnooze(minutes)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Snooze")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button(action: onDismiss) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("Dismiss")
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                Spacer()
                    .frame(height: 80)
            }
            .scaleEffect(appeared ? 1.0 : 0.9)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
            loadSnoozeOptions()
            updateCountdown()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    updateCountdown()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var currentBackground: AnyShapeStyle {
        let bg = OverlayBackground(rawValue: overlayBackground) ?? .dark
        return bg.previewGradient
    }

    private var videoServiceName: String {
        guard let url = event.videoLink else { return "Meeting" }
        return VideoLinkDetector.serviceName(for: url)
    }

    private func snoozeLabel(minutes: Int) -> String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private func loadSnoozeOptions() {
        let stored = UserDefaults.standard.array(forKey: "snoozeOptions") as? [Int] ?? []
        snoozeOptions = stored.isEmpty ? [1, 2, 5, 10] : stored.sorted()
    }

    private func updateCountdown() {
        let seconds = Int(event.startDate.timeIntervalSinceNow)
        if seconds <= 0 {
            countdown = "Starting now!"
        } else if seconds < 60 {
            countdown = "Starting in \(seconds) seconds"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                countdown = "Starting in \(minutes) min"
            } else {
                countdown = "Starting in \(minutes)m \(remainingSeconds)s"
            }
        }
    }
}
