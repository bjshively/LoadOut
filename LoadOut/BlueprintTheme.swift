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

// MARK: - Screen Preview (Mini window layout visualization)

struct ScreenPreviewView: View {
    let windows: [WindowInfo]
    let screenBounds: CGRect

    init(windows: [WindowInfo]) {
        self.windows = windows
        // Get main screen bounds for scaling
        if let screen = NSScreen.main {
            self.screenBounds = screen.frame
        } else {
            self.screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / screenBounds.width,
                geometry.size.height / screenBounds.height
            ) * 0.9

            ZStack {
                // Screen outline
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blueprintDeep)
                    )

                // Window rectangles
                ForEach(windows) { window in
                    let scaledX = CGFloat(window.x) * scale + (geometry.size.width - screenBounds.width * scale) / 2
                    let scaledY = CGFloat(window.y) * scale + (geometry.size.height - screenBounds.height * scale) / 2
                    let scaledW = CGFloat(window.width) * scale
                    let scaledH = CGFloat(window.height) * scale

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blueprintCyan.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.blueprintCyan.opacity(0.6), lineWidth: 1)
                        )
                        .frame(width: scaledW, height: scaledH)
                        .position(x: scaledX + scaledW / 2, y: scaledY + scaledH / 2)
                }

                // Corner markers
                CornerMarkers()
                    .stroke(Color.blueprintCyan.opacity(0.2), lineWidth: 0.5)
            }
        }
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

    static func show(presetName: String, windowCount: Int) {
        // Cancel any pending hide
        hideTask?.cancel()

        // Create toast content
        let toastView = ToastView(presetName: presetName, windowCount: windowCount)
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
}

struct ToastView: View {
    let presetName: String
    let windowCount: Int

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

                Text("\(windowCount) window\(windowCount == 1 ? "" : "s") arranged")
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
