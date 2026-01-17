//
//  BlueprintTheme.swift
//  LoadOut
//
//  Blueprint aesthetic theme for window layout management
//

import SwiftUI

// MARK: - Blueprint Color Palette

extension Color {
    // Primary backgrounds
    static let blueprintDeep = Color(red: 0.039, green: 0.086, blue: 0.157)      // #0a1628
    static let blueprintMid = Color(red: 0.059, green: 0.114, blue: 0.192)       // #0f1d31
    static let blueprintLight = Color(red: 0.078, green: 0.141, blue: 0.227)     // #14243a

    // Accent colors
    static let blueprintCyan = Color(red: 0.306, green: 0.804, blue: 0.769)      // #4ecdc4
    static let blueprintCyanDim = Color(red: 0.306, green: 0.804, blue: 0.769).opacity(0.4)
    static let blueprintAmber = Color(red: 1.0, green: 0.76, blue: 0.28)         // #ffc247
    static let blueprintRed = Color(red: 1.0, green: 0.42, blue: 0.42)           // #ff6b6b

    // Text colors
    static let blueprintText = Color(red: 0.94, green: 0.96, blue: 0.98)         // #f0f5fa
    static let blueprintTextDim = Color(red: 0.94, green: 0.96, blue: 0.98).opacity(0.5)
    static let blueprintGridLine = Color(red: 0.306, green: 0.804, blue: 0.769).opacity(0.08)
}

// MARK: - Blueprint Typography

struct BlueprintFont {
    // Using SF Mono for technical data (coordinates, counts)
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Using SF Pro for headers and labels
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Grid Background View

struct BlueprintGridBackground: View {
    let gridSize: CGFloat = 20
    let showCrosshair: Bool

    init(showCrosshair: Bool = false) {
        self.showCrosshair = showCrosshair
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [Color.blueprintDeep, Color.blueprintMid],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Grid pattern
                Canvas { context, size in
                    // Vertical lines
                    for x in stride(from: 0, to: size.width, by: gridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(Color.blueprintGridLine), lineWidth: 0.5)
                    }

                    // Horizontal lines
                    for y in stride(from: 0, to: size.height, by: gridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(Color.blueprintGridLine), lineWidth: 0.5)
                    }

                    // Major grid lines every 5 cells
                    let majorGridSize = gridSize * 5
                    for x in stride(from: 0, to: size.width, by: majorGridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(Color.blueprintCyan.opacity(0.15)), lineWidth: 0.5)
                    }
                    for y in stride(from: 0, to: size.height, by: majorGridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(Color.blueprintCyan.opacity(0.15)), lineWidth: 0.5)
                    }
                }

                // Optional crosshair at center
                if showCrosshair {
                    CrosshairView()
                        .opacity(0.3)
                }

                // Subtle vignette
                RadialGradient(
                    colors: [.clear, Color.blueprintDeep.opacity(0.4)],
                    center: .center,
                    startRadius: min(geometry.size.width, geometry.size.height) * 0.3,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.8
                )
            }
        }
    }
}

struct CrosshairView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2

                // Horizontal line
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))

                // Vertical line
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
            }
            .stroke(Color.blueprintCyan, style: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
        }
    }
}

// MARK: - Blueprint Panel Style

struct BlueprintPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.blueprintLight.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.blueprintCyan.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Coordinate Label

struct CoordinateLabel: View {
    let x: Double
    let y: Double
    let width: Double?
    let height: Double?

    init(x: Double, y: Double, width: Double? = nil, height: Double? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                Text("x:")
                    .foregroundColor(.blueprintTextDim)
                Text("\(Int(x))")
                    .foregroundColor(.blueprintCyan)
            }
            HStack(spacing: 2) {
                Text("y:")
                    .foregroundColor(.blueprintTextDim)
                Text("\(Int(y))")
                    .foregroundColor(.blueprintCyan)
            }
            if let w = width, let h = height {
                Text("•")
                    .foregroundColor(.blueprintTextDim)
                HStack(spacing: 2) {
                    Text("\(Int(w))")
                        .foregroundColor(.blueprintAmber)
                    Text("×")
                        .foregroundColor(.blueprintTextDim)
                    Text("\(Int(h))")
                        .foregroundColor(.blueprintAmber)
                }
            }
        }
        .font(BlueprintFont.mono(10))
    }
}

// MARK: - Section Header

struct BlueprintSectionHeader: View {
    let title: String
    let count: Int?
    let action: (() -> Void)?
    let actionIcon: String?

    init(_ title: String, count: Int? = nil, actionIcon: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.count = count
        self.action = action
        self.actionIcon = actionIcon
    }

    var body: some View {
        HStack(alignment: .center) {
            // Title with technical styling
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.blueprintCyan)
                    .frame(width: 3, height: 14)

                Text(title.uppercased())
                    .font(BlueprintFont.display(11, weight: .semibold))
                    .foregroundColor(.blueprintText)
                    .tracking(1.5)

                if let count = count {
                    Text("[\(count)]")
                        .font(BlueprintFont.mono(10))
                        .foregroundColor(.blueprintCyan)
                }
            }

            Spacer()

            // Decorative line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blueprintCyan.opacity(0.3), Color.blueprintCyan.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .frame(maxWidth: 60)

            if let action = action, let icon = actionIcon {
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blueprintCyan)
                        .frame(width: 24, height: 24)
                        .background(Color.blueprintCyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blueprintMid.opacity(0.8))
    }
}

// MARK: - Blueprint Button Styles

struct BlueprintPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BlueprintFont.mono(11, weight: .medium))
            .foregroundColor(isEnabled ? .blueprintDeep : .blueprintTextDim)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isEnabled ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blueprintCyan.opacity(0.5), lineWidth: 0.5)
            )
            .fixedSize()
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BlueprintSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BlueprintFont.mono(11, weight: .medium))
            .foregroundColor(.blueprintCyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blueprintCyan.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Screen Configuration

/// Represents the current display configuration
struct ScreenConfiguration {
    let screens: [ScreenInfo]
    let unifiedBounds: CGRect  // Bounding box containing all screens in accessibility coordinates

    struct ScreenInfo: Identifiable {
        let id: Int
        let frame: CGRect      // In accessibility coordinates (top-left origin)
        let isMain: Bool
    }

    /// Get the current screen configuration
    static var current: ScreenConfiguration {
        let nsScreens = NSScreen.screens
        guard !nsScreens.isEmpty else {
            return ScreenConfiguration(
                screens: [],
                unifiedBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        }

        // Get the main screen height for coordinate conversion
        let mainScreenHeight = nsScreens.first?.frame.height ?? 1080

        var screenInfos: [ScreenInfo] = []
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity

        for (index, screen) in nsScreens.enumerated() {
            let nsFrame = screen.frame

            // Convert from NSScreen coordinates (bottom-left origin) to
            // Accessibility coordinates (top-left origin)
            let accessibilityFrame = CGRect(
                x: nsFrame.origin.x,
                y: mainScreenHeight - nsFrame.origin.y - nsFrame.height,
                width: nsFrame.width,
                height: nsFrame.height
            )

            screenInfos.append(ScreenInfo(
                id: index,
                frame: accessibilityFrame,
                isMain: screen == NSScreen.main
            ))

            // Track unified bounds
            minX = min(minX, accessibilityFrame.minX)
            minY = min(minY, accessibilityFrame.minY)
            maxX = max(maxX, accessibilityFrame.maxX)
            maxY = max(maxY, accessibilityFrame.maxY)
        }

        let unifiedBounds = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        return ScreenConfiguration(screens: screenInfos, unifiedBounds: unifiedBounds)
    }
}

// MARK: - Multi-Screen Preview View

struct MultiScreenPreviewView: View {
    let windows: [WindowInfo]
    let config: ScreenConfiguration

    init(windows: [WindowInfo]) {
        self.windows = windows
        self.config = ScreenConfiguration.current
    }

    var body: some View {
        GeometryReader { geometry in
            let bounds = config.unifiedBounds
            let scale = min(
                geometry.size.width / bounds.width,
                geometry.size.height / bounds.height
            ) * 0.85

            let offsetX = (geometry.size.width - bounds.width * scale) / 2 - bounds.minX * scale
            let offsetY = (geometry.size.height - bounds.height * scale) / 2 - bounds.minY * scale

            ZStack {
                // Draw each screen
                ForEach(config.screens) { screen in
                    let screenX = screen.frame.minX * scale + offsetX
                    let screenY = screen.frame.minY * scale + offsetY
                    let screenW = screen.frame.width * scale
                    let screenH = screen.frame.height * scale

                    // Screen background and outline
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blueprintDeep)
                        .frame(width: screenW, height: screenH)
                        .position(x: screenX + screenW / 2, y: screenY + screenH / 2)

                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            screen.isMain ? Color.blueprintCyan.opacity(0.5) : Color.blueprintCyan.opacity(0.25),
                            lineWidth: screen.isMain ? 1 : 0.5
                        )
                        .frame(width: screenW, height: screenH)
                        .position(x: screenX + screenW / 2, y: screenY + screenH / 2)

                    // Screen label for multi-monitor
                    if config.screens.count > 1 {
                        Text(screen.isMain ? "Main" : "\(screen.id + 1)")
                            .font(BlueprintFont.mono(8))
                            .foregroundColor(.blueprintTextDim)
                            .position(x: screenX + 16, y: screenY + 10)
                    }
                }

                // Draw windows on top of screens
                ForEach(windows) { window in
                    let windowX = CGFloat(window.x) * scale + offsetX
                    let windowY = CGFloat(window.y) * scale + offsetY
                    let windowW = CGFloat(window.width) * scale
                    let windowH = CGFloat(window.height) * scale

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blueprintCyan.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.blueprintCyan.opacity(0.6), lineWidth: 1)
                        )
                        .frame(width: windowW, height: windowH)
                        .position(x: windowX + windowW / 2, y: windowY + windowH / 2)
                }
            }
        }
    }
}

// MARK: - Screen Preview (Mini window layout visualization)

struct ScreenPreviewView: View {
    let windows: [WindowInfo]

    init(windows: [WindowInfo]) {
        self.windows = windows
    }

    var body: some View {
        // Use multi-screen preview to properly handle all display configurations
        MultiScreenPreviewView(windows: windows)
    }
}

struct CornerMarkers: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let markerLength: CGFloat = 8

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + markerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + markerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - markerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + markerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - markerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - markerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + markerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - markerLength))

        return path
    }
}

// MARK: - Animated Selection Indicator

struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 1)
                .frame(width: 20, height: 20)

            if isSelected {
                Circle()
                    .fill(Color.blueprintCyan)
                    .frame(width: 12, height: 12)

                Circle()
                    .fill(Color.blueprintCyan.opacity(0.3))
                    .frame(width: 20, height: 20)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Status Indicator

struct StatusDot: View {
    enum Status {
        case active, warning, inactive

        var color: Color {
            switch self {
            case .active: return .blueprintCyan
            case .warning: return .blueprintAmber
            case .inactive: return .blueprintTextDim
            }
        }
    }

    let status: Status
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 6, height: 6)
            .shadow(color: status.color.opacity(0.5), radius: isPulsing ? 4 : 2)
            .onAppear {
                if status == .active {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
    }
}

// MARK: - Toast Window

class ToastWindow {
    private static var window: NSWindow?
    private static var hideTask: DispatchWorkItem?

    static func show(presetName: String, windowCount: Int, launchItemCount: Int = 0) {
        // Cancel any pending hide
        hideTask?.cancel()

        // Create toast content
        let toastView = ToastView(presetName: presetName, windowCount: windowCount, launchItemCount: launchItemCount)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 80)

        // Create or reuse window
        if window == nil {
            let toast = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            toast.isOpaque = false
            toast.backgroundColor = .clear
            toast.level = .floating
            toast.collectionBehavior = [.canJoinAllSpaces, .transient]
            toast.ignoresMouseEvents = true
            window = toast
        }

        window?.contentView = hostingView

        // Position at top center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140
            let y = screenFrame.maxY - 120
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show with animation
        window?.alphaValue = 0
        window?.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }

        // Schedule hide
        let task = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window?.animator().alphaValue = 0
            }, completionHandler: {
                window?.orderOut(nil)
            })
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }

    static func showError(title: String, message: String) {
        // Cancel any pending hide
        hideTask?.cancel()

        // Create toast content
        let toastView = ErrorToastView(title: title, message: message)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 80)

        // Create or reuse window
        if window == nil {
            let toast = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            toast.isOpaque = false
            toast.backgroundColor = .clear
            toast.level = .floating
            toast.collectionBehavior = [.canJoinAllSpaces, .transient]
            toast.ignoresMouseEvents = true
            window = toast
        }

        window?.contentView = hostingView

        // Position at top center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140
            let y = screenFrame.maxY - 120
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show with animation
        window?.alphaValue = 0
        window?.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }

        // Schedule hide (longer for errors so user can read)
        let task = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window?.animator().alphaValue = 0
            }, completionHandler: {
                window?.orderOut(nil)
            })
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: task)
    }
}

struct ToastView: View {
    let presetName: String
    let windowCount: Int
    var launchItemCount: Int = 0

    var statusText: String {
        var parts: [String] = []
        if windowCount > 0 {
            parts.append("\(windowCount) window\(windowCount == 1 ? "" : "s")")
        }
        if launchItemCount > 0 {
            parts.append("\(launchItemCount) item\(launchItemCount == 1 ? "" : "s") opened")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.blueprintCyan.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blueprintCyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("PRESET APPLIED")
                    .font(BlueprintFont.mono(9, weight: .semibold))
                    .foregroundColor(.blueprintCyan)
                    .tracking(1)

                Text(presetName)
                    .font(BlueprintFont.display(15, weight: .semibold))
                    .foregroundColor(.blueprintText)
                    .lineLimit(1)

                Text(statusText)
                    .font(BlueprintFont.mono(10))
                    .foregroundColor(.blueprintTextDim)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blueprintDeep)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorToastView: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.blueprintAmber.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blueprintAmber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(BlueprintFont.mono(9, weight: .semibold))
                    .foregroundColor(.blueprintAmber)
                    .tracking(1)

                Text(message)
                    .font(BlueprintFont.display(13, weight: .medium))
                    .foregroundColor(.blueprintText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blueprintDeep)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blueprintAmber.opacity(0.3), lineWidth: 1)
        )
    }
}
