import Cocoa
import SwiftUI
import Combine

// MARK: - Size Presets
enum TimerSize: Int, CaseIterable {
    case tiny = 0
    case small = 1
    case medium = 2
    case big = 3
    case huge = 4

    var label: String {
        switch self {
        case .tiny: return "T"
        case .small: return "S"
        case .medium: return "M"
        case .big: return "L"
        case .huge: return "XL"
        }
    }

    var scale: CGFloat {
        switch self {
        case .tiny: return 0.5
        case .small: return 0.75
        case .medium: return 1.0
        case .big: return 1.35
        case .huge: return 1.8
        }
    }

    var windowSize: NSSize {
        let baseWidth: CGFloat = 210
        let baseHeight: CGFloat = 150
        let padding: CGFloat = 10  // 5 * 2 for shadow padding
        return NSSize(width: baseWidth * scale + padding * scale, height: baseHeight * scale + padding * scale)
    }

    var expandedWindowSize: NSSize {
        let baseWidth: CGFloat = 210
        let baseHeight: CGFloat = 235
        let padding: CGFloat = 10
        return NSSize(width: baseWidth * scale + padding * scale, height: baseHeight * scale + padding * scale)
    }

    func next() -> TimerSize {
        let all = TimerSize.allCases
        let nextIndex = (self.rawValue + 1) % all.count
        return all[nextIndex]
    }

    func previous() -> TimerSize {
        let all = TimerSize.allCases
        let prevIndex = (self.rawValue - 1 + all.count) % all.count
        return all[prevIndex]
    }
}

// MARK: - Timer Model
class TimerModel: ObservableObject {
    @Published var timeRemaining: Int = 300
    @Published var isRunning: Bool = false
    @Published var initialTime: Int = 300
    @Published var customTimeInput: String = "05:00"
    @Published var currentSize: TimerSize = .medium
    @Published var tabPressedAt: Date?  // Triggers tab navigation in view
    @Published var timerFinished: Bool = false  // True when timer naturally reached 0
    @Published var alarmPlaying: Bool = false

    private var timer: Timer?
    private var alarmTimer: Timer?
    private var alarmSound: NSSound?
    weak var panelDelegate: PanelSizeDelegate?

    func triggerTab() {
        tabPressedAt = Date()
    }

    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        stopAlarm()
        isRunning = true
        timerFinished = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timerFinished = true
                self.stop()
                self.playAlert()
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stop()
        stopAlarm()
        timerFinished = false
        timeRemaining = initialTime
    }

    func setTime(minutes: Int) {
        stop()
        timerFinished = false
        initialTime = minutes * 60
        timeRemaining = initialTime
        updateInputFromTime()
    }

    func setTimeFromInput() {
        stop()
        timerFinished = false
        let parsed = parseTimeInput(customTimeInput)
        initialTime = parsed
        timeRemaining = parsed
    }

    func parseTimeInput(_ input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                return parts[0] * 60 + parts[1]
            } else if parts.count == 3 {
                return parts[0] * 3600 + parts[1] * 60 + parts[2]
            }
        } else if let minutes = Int(trimmed) {
            return minutes * 60
        }
        return 300
    }

    func updateInputFromTime() {
        let minutes = initialTime / 60
        let seconds = initialTime % 60
        customTimeInput = String(format: "%02d:%02d", minutes, seconds)
    }

    func addMinute() {
        timeRemaining += 60
        initialTime = timeRemaining
        updateInputFromTime()
    }

    func subtractMinute() {
        if timeRemaining >= 60 {
            timeRemaining -= 60
            initialTime = timeRemaining
            updateInputFromTime()
        }
    }

    func cycleSize() {
        currentSize = currentSize.next()
        panelDelegate?.updatePanelSize(expanded: false)
    }

    func increasSize() {
        if currentSize.rawValue < TimerSize.huge.rawValue {
            currentSize = TimerSize(rawValue: currentSize.rawValue + 1) ?? .medium
            panelDelegate?.updatePanelSize(expanded: false)
        }
    }

    func decreaseSize() {
        if currentSize.rawValue > TimerSize.tiny.rawValue {
            currentSize = TimerSize(rawValue: currentSize.rawValue - 1) ?? .medium
            panelDelegate?.updatePanelSize(expanded: false)
        }
    }

    private func playAlert() {
        NSApp.requestUserAttention(.criticalRequest)
        startAlarm()
    }

    func startAlarm() {
        alarmPlaying = true
        // Play sound immediately and repeat every 0.75 seconds (2X faster)
        playAlarmSound()
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.playAlarmSound()
        }
    }

    private func playAlarmSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        }
    }

    func stopAlarm() {
        alarmPlaying = false
        alarmTimer?.invalidate()
        alarmTimer = nil
        alarmSound?.stop()
        alarmSound = nil
    }
}

// MARK: - Panel Size Delegate
protocol PanelSizeDelegate: AnyObject {
    func updatePanelSize(expanded: Bool)
}

// MARK: - Timer View
struct TimerView: View {
    @ObservedObject var model: TimerModel
    @State private var editingMinutes = false
    @State private var editingSeconds = false
    @State private var minutesInput = ""
    @State private var secondsInput = ""
    @State private var flashOn = false
    @State private var closeHovered = false
    @FocusState private var minutesFocused: Bool
    @FocusState private var secondsFocused: Bool

    var scale: CGFloat { model.currentSize.scale }

    // Background color based on time remaining
    var backgroundColor: Color {
        if model.timeRemaining <= 5 && model.timeRemaining > 0 && model.isRunning {
            // At 5 seconds: alternate red bg / white bg
            return flashOn ? Color(red: 0.7, green: 0.0, blue: 0.0) : Color.white
        } else if model.timeRemaining <= 10 && model.timeRemaining > 0 && model.isRunning {
            // At 10 seconds: flashing red background
            return flashOn ? Color(red: 0.7, green: 0.0, blue: 0.0) : Color(red: 0.4, green: 0.0, blue: 0.0)
        } else if model.timeRemaining <= 30 && model.timeRemaining > 0 && model.isRunning {
            // Deep dark vivid red at 30 seconds
            return Color(red: 0.45, green: 0.0, blue: 0.05)
        } else {
            return Color.black.opacity(0.57)
        }
    }

    // Text color - red only in play mode, white in time-setting mode
    var timerTextColor: Color {
        if model.timeRemaining == 0 && model.timerFinished {
            // At 00:00 after timer finished: blinking red text
            return flashOn ? .red : .red.opacity(0.3)
        } else if model.timeRemaining <= 5 && model.timeRemaining > 0 && model.isRunning {
            // At 5 seconds while running: alternate white font / red font
            return flashOn ? .white : .red
        } else if model.timeRemaining <= 30 && model.timeRemaining > 0 && model.isRunning {
            return .white
        } else if model.timeRemaining <= 60 && model.timeRemaining > 0 && model.isRunning {
            // Red only when running
            return .red
        } else {
            return .white
        }
    }

    var minutesString: String {
        String(format: "%02d", model.timeRemaining / 60)
    }

    var secondsString: String {
        String(format: "%02d", model.timeRemaining % 60)
    }

    func commitMinutes() {
        if let mins = Int(minutesInput), mins >= 0 && mins <= 99 {
            let currentSeconds = model.timeRemaining % 60
            model.timeRemaining = mins * 60 + currentSeconds
            model.initialTime = model.timeRemaining
            model.timerFinished = false
        }
        editingMinutes = false
    }

    func commitSeconds() {
        if let secs = Int(secondsInput), secs >= 0 && secs <= 59 {
            let currentMinutes = model.timeRemaining / 60
            model.timeRemaining = currentMinutes * 60 + secs
            model.initialTime = model.timeRemaining
            model.timerFinished = false
        }
        editingSeconds = false
    }

    func cancelEditing() {
        // Discard changes - just close without saving
        editingMinutes = false
        editingSeconds = false
        minutesFocused = false
        secondsFocused = false
    }

    func commitAndClose() {
        // Save valid values then close
        if editingMinutes {
            commitMinutes()
        }
        if editingSeconds {
            commitSeconds()
        }
    }

    func tabToSeconds() {
        // Commit minutes and move to seconds
        commitMinutes()
        secondsInput = String(format: "%02d", model.timeRemaining % 60)
        editingSeconds = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            secondsFocused = true
        }
    }

    func tabToMinutes() {
        // Commit seconds and move to minutes
        commitSeconds()
        minutesInput = String(format: "%02d", model.timeRemaining / 60)
        editingMinutes = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            minutesFocused = true
        }
    }

    var body: some View {
        VStack(spacing: 6 * scale) {
            // Size indicator + controls (top row)
            HStack {
                // Quit button (top left)
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10 * scale, weight: .semibold))
                        .frame(width: 18 * scale, height: 18 * scale)
                }
                .buttonStyle(.plain)
                .foregroundColor(closeHovered ? .red : .white.opacity(0.6))
                .onHover { hovering in
                    closeHovered = hovering
                }
                .help("Quit")

                Spacer().frame(maxWidth: .infinity)

                // Size controls (top right)
                Button(action: { model.decreaseSize() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .frame(width: 22 * scale, height: 22 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .disabled(model.currentSize == .tiny)

                Button(action: { model.increasSize() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .frame(width: 22 * scale, height: 22 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .disabled(model.currentSize == .huge)
            }

            // Timer display - minutes and seconds separately editable
            HStack(spacing: 0) {
                // Minutes
                ZStack {
                    if editingMinutes {
                        TextField("", text: $minutesInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 36 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 56 * scale)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                            .focused($minutesFocused)
                            .onSubmit { commitMinutes() }
                            .onExitCommand { cancelEditing() }
                            .onChange(of: minutesFocused) { focused in
                                if !focused && !editingSeconds { commitMinutes() }
                            }
                    } else {
                        Button(action: {
                            model.stopAlarm()
                            if !model.isRunning {
                                minutesInput = String(format: "%02d", model.timeRemaining / 60)
                                editingMinutes = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    minutesFocused = true
                                }
                            }
                        }) {
                            Text(minutesString)
                                .font(.system(size: 36 * scale, weight: .bold, design: .monospaced))
                                .foregroundColor(timerTextColor)
                                .frame(width: 56 * scale)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Colon
                Text(":")
                    .font(.system(size: 36 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(timerTextColor)
                    .frame(width: 16 * scale)

                // Seconds
                ZStack {
                    if editingSeconds {
                        TextField("", text: $secondsInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 36 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 56 * scale)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                            .focused($secondsFocused)
                            .onSubmit { commitSeconds() }
                            .onExitCommand { cancelEditing() }
                            .onChange(of: secondsFocused) { focused in
                                if !focused { commitSeconds() }
                            }
                    } else {
                        Button(action: {
                            model.stopAlarm()
                            if !model.isRunning {
                                secondsInput = String(format: "%02d", model.timeRemaining % 60)
                                editingSeconds = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    secondsFocused = true
                                }
                            }
                        }) {
                            Text(secondsString)
                                .font(.system(size: 36 * scale, weight: .bold, design: .monospaced))
                                .foregroundColor(timerTextColor)
                                .frame(width: 56 * scale)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .animation(.easeInOut, value: model.timeRemaining <= 60)

            // Control buttons
            HStack(spacing: 12 * scale) {
                Button(action: {
                    model.stopAlarm()
                    if model.isRunning {
                        model.stop()
                    } else {
                        commitAndClose()  // Remove any highlight before starting
                        model.start()
                    }
                }) {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16 * scale))
                        .frame(width: 33 * scale, height: 33 * scale)
                }
                .buttonStyle(.plain)
                .background(model.isRunning ? (model.timeRemaining <= 30 ? Color.black : Color.black.opacity(0.5)) : Color.green)
                .foregroundColor(.white)
                .cornerRadius(16.5 * scale)
                .focusable(false)

                Button(action: { model.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16 * scale))
                        .frame(width: 33 * scale, height: 33 * scale)
                }
                .buttonStyle(.plain)
                .background(Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(16.5 * scale)
                .focusable(false)
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.top, 12 * scale)
        .padding(.bottom, 25 * scale)
        .background(
            RoundedRectangle(cornerRadius: 12 * scale)
                .fill(backgroundColor)
                .onTapGesture {
                    // Stop alarm if playing
                    if model.alarmPlaying {
                        model.stopAlarm()
                    }
                    // Clicking outside saves valid value
                    if editingMinutes || editingSeconds {
                        commitAndClose()
                    }
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
        .shadow(color: .black.opacity(0.3), radius: 8 * scale, x: 0, y: 4 * scale)
        .padding(5 * scale)  // Room for shadow
        .animation(.easeInOut(duration: 0.2), value: backgroundColor)
        .animation(.easeInOut(duration: 0.2), value: timerTextColor)
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            if (model.timeRemaining == 0 && model.timerFinished) || (model.timeRemaining <= 10 && model.timeRemaining > 0 && model.isRunning) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    flashOn.toggle()
                }
            } else if flashOn {
                withAnimation(.easeOut(duration: 0.15)) {
                    flashOn = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: flashOn)
        .onChange(of: model.tabPressedAt) { _ in
            // Handle Tab key: move between mm and ss fields
            if editingMinutes {
                tabToSeconds()
            } else if editingSeconds {
                tabToMinutes()
            }
        }
    }
}

// MARK: - Floating Panel Window
class FloatingPanel: NSPanel {
    var allowClose = false  // Only set true when we explicitly want to quit

    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backing, defer: flag)

        // NUCLEAR: Use Int32.max - highest possible window level
        self.level = NSWindow.Level(rawValue: Int(Int32.max) - 1)
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false  // We draw our own shadow in SwiftUI
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true  // Enable dragging
        // Critical combination to appear over Keynote fullscreen presentation
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenDisallowsTiling, .stationary, .ignoresCycle, .transient]
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false  // CRITICAL: Don't release on close

        // Hide standard window buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Block ALL close attempts unless explicitly allowed
    override func close() {
        if allowClose {
            super.close()
        }
        // Otherwise do nothing
    }

    override func performClose(_ sender: Any?) {
        // Block close from any UI action
    }

    override func orderOut(_ sender: Any?) {
        if allowClose {
            super.orderOut(sender)
        }
        // Otherwise do nothing - prevent window from hiding
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, PanelSizeDelegate {
    var panel: FloatingPanel!
    var timerModel = TimerModel()
    var hostingView: NSHostingView<TimerView>!
    var localEventMonitor: Any?
    var stayOnTopTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerModel.panelDelegate = self

        let size = timerModel.currentSize.windowSize
        let contentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        panel = FloatingPanel(contentRect: contentRect, backing: .buffered, defer: false)

        let timerView = TimerView(model: timerModel)
        hostingView = NSHostingView(rootView: timerView)

        // Make hosting view fully transparent
        let clearView = NSView(frame: hostingView.bounds)
        clearView.wantsLayer = true
        clearView.layer?.backgroundColor = .clear
        clearView.autoresizingMask = [.width, .height]

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.isOpaque = false

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = .clear

        if let screen = NSScreen.main {
            let screenFrame = screen.frame  // Full screen, including menu bar area
            let padding = 5 * timerModel.currentSize.scale  // Account for shadow padding in view
            let x = screenFrame.maxX - size.width + padding
            let y = screenFrame.maxY - size.height + padding
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        NSApp.setActivationPolicy(.accessory)

        // Aggressively keep window on top (helps with Keynote fullscreen)
        stayOnTopTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let panel = self?.panel else { return }
            panel.level = NSWindow.Level(rawValue: Int(Int32.max) - 1)
            panel.orderFrontRegardless()
        }

        // Keyboard shortcuts for resizing and tab navigation
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.panel.isKeyWindow else { return event }

            switch event.keyCode {
            case 48: // Tab key
                self.timerModel.triggerTab()
                return nil
            case 123, 27: // Left arrow or minus key
                self.timerModel.decreaseSize()
                return nil
            case 124, 24: // Right arrow or plus/equals key
                self.timerModel.increasSize()
                return nil
            default:
                return event
            }
        }
    }

    func updatePanelSize(expanded: Bool) {
        let size = expanded ? timerModel.currentSize.expandedWindowSize : timerModel.currentSize.windowSize

        // Animate size change, keeping top-right corner anchored
        let currentFrame = panel.frame
        let newOrigin = NSPoint(
            x: currentFrame.maxX - size.width,
            y: currentFrame.maxY - size.height
        )
        let newFrame = NSRect(origin: newOrigin, size: size)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // We control termination explicitly
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        stayOnTopTimer?.invalidate()
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
