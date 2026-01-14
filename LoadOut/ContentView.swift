//
//  ContentView.swift
//  LoadOut
//
//  Blueprint-themed window layout management interface
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var presetName: String = ""
    @State private var showingSaveSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var hoveredPresetId: UUID?
    @State private var appearAnimation = false
    @State private var draggingPreset: Preset?

    var selectedCount: Int {
        windowManager.runningApps.filter { $0.isSelected }.count
    }

    var body: some View {
        ZStack {
            // Blueprint grid background
            BlueprintGridBackground(showCrosshair: false)
                .ignoresSafeArea()

            // Main content
            HStack(spacing: 0) {
                // Left panel - Running Apps
                VStack(spacing: 0) {
                    BlueprintSectionHeader(
                        "Running Apps",
                        count: windowManager.runningApps.count,
                        actionIcon: "arrow.clockwise"
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            windowManager.refreshRunningApps()
                        }
                    }

                    // Accessibility warning
                    if !windowManager.accessibilityEnabled {
                        AccessibilityWarningBanner {
                            windowManager.checkAccessibilityPermissions()
                        }
                    }

                    // App list
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(windowManager.runningApps.enumerated()), id: \.element.id) { index, app in
                                BlueprintAppRow(app: app) {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        windowManager.toggleSelection(for: app)
                                    }
                                }
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(x: appearAnimation ? 0 : -20)
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(index) * 0.02),
                                    value: appearAnimation
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }

                    // Footer with save action
                    BlueprintFooter(
                        selectedCount: selectedCount,
                        onSave: { showingSaveSheet = true }
                    )
                }
                .frame(minWidth: 300, idealWidth: 340)
                .background(Color.blueprintMid.opacity(0.3))

                // Divider
                Rectangle()
                    .fill(Color.blueprintCyan.opacity(0.2))
                    .frame(width: 1)

                // Right panel - Saved Presets
                VStack(spacing: 0) {
                    BlueprintSectionHeader(
                        "Saved Presets",
                        count: windowManager.presets.count,
                        actionIcon: "gearshape"
                    ) {
                        showingSettings = true
                    }

                    if windowManager.presets.isEmpty {
                        EmptyPresetsView()
                    } else {
                        // Drag hint
                        if windowManager.presets.count > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 9))
                                Text("DRAG TO REORDER")
                                    .font(BlueprintFont.mono(8, weight: .medium))
                                    .tracking(0.5)
                            }
                            .foregroundColor(.blueprintTextDim)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(windowManager.presets.enumerated()), id: \.element.id) { index, preset in
                                    BlueprintPresetCard(
                                        preset: preset,
                                        isHovered: hoveredPresetId == preset.id,
                                        isDragging: draggingPreset?.id == preset.id,
                                        onApply: {
                                            windowManager.applyPreset(preset)
                                        },
                                        onDelete: {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                windowManager.deletePreset(preset)
                                            }
                                        }
                                    )
                                    .onDrag {
                                        draggingPreset = preset
                                        return NSItemProvider(object: preset.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: PresetDropDelegate(
                                        item: preset,
                                        items: $windowManager.presets,
                                        draggingItem: $draggingPreset
                                    ))
                                    .onHover { hovering in
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            hoveredPresetId = hovering ? preset.id : nil
                                        }
                                    }
                                    .opacity(appearAnimation ? 1 : 0)
                                    .offset(x: appearAnimation ? 0 : 20)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                                        value: appearAnimation
                                    )
                                }
                            }
                            .padding(12)
                        }
                    }
                }
                .frame(minWidth: 320, idealWidth: 360)
                .background(Color.blueprintDeep.opacity(0.5))
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appearAnimation = true
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            BlueprintSaveSheet(
                presetName: $presetName,
                selectedApps: windowManager.runningApps.filter { $0.isSelected }
            ) {
                if !presetName.trimmingCharacters(in: .whitespaces).isEmpty {
                    windowManager.savePreset(name: presetName)
                    presetName = ""
                    showingSaveSheet = false
                }
            } onCancel: {
                presetName = ""
                showingSaveSheet = false
            }
        }
        .sheet(isPresented: $showingSettings) {
            BlueprintSettingsSheet(windowManager: windowManager) {
                showingSettings = false
            }
        }
    }
}

// MARK: - Drag & Drop Delegate

struct PresetDropDelegate: DropDelegate {
    let item: Preset
    @Binding var items: [Preset]
    @Binding var draggingItem: Preset?

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Accessibility Warning Banner

struct AccessibilityWarningBanner: View {
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.blueprintAmber)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("ACCESSIBILITY REQUIRED")
                    .font(BlueprintFont.mono(10, weight: .semibold))
                    .foregroundColor(.blueprintAmber)
                    .tracking(0.5)
                Text("Grant access to capture window positions")
                    .font(BlueprintFont.mono(9))
                    .foregroundColor(.blueprintTextDim)
            }

            Spacer()

            Button("GRANT", action: onGrant)
                .buttonStyle(BlueprintSecondaryButton())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blueprintAmber.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(Color.blueprintAmber)
                .frame(width: 3),
            alignment: .leading
        )
    }
}

// MARK: - App Row

struct BlueprintAppRow: View {
    let app: RunningApp
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            SelectionIndicator(isSelected: app.isSelected)

            // App icon
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blueprintTextDim)
                        .frame(width: 28, height: 28)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blueprintLight.opacity(0.5))
            )

            // App info
            Text(app.name)
                .font(BlueprintFont.display(12, weight: .medium))
                .foregroundColor(.blueprintText)
                .lineLimit(1)

            Spacer()

            // PID indicator
            Text("PID:\(app.id)")
                .font(BlueprintFont.mono(8))
                .foregroundColor(.blueprintTextDim)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    app.isSelected
                        ? Color.blueprintCyan.opacity(0.1)
                        : (isHovered ? Color.blueprintLight.opacity(0.3) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    app.isSelected ? Color.blueprintCyan.opacity(0.3) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Footer

struct BlueprintFooter: View {
    let selectedCount: Int
    let onSave: () -> Void

    var body: some View {
        HStack {
            // Selection count with visual indicator
            HStack(spacing: 8) {
                if selectedCount > 0 {
                    StatusDot(status: .active)
                }

                Text(selectedCount > 0 ? "\(selectedCount) SELECTED" : "SELECT APPS TO CREATE PRESET")
                    .font(BlueprintFont.mono(10, weight: .medium))
                    .foregroundColor(selectedCount > 0 ? .blueprintCyan : .blueprintTextDim)
                    .tracking(0.5)
            }

            Spacer()

            Button("SAVE PRESET") {
                onSave()
            }
            .buttonStyle(BlueprintPrimaryButton())
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.blueprintMid.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(Color.blueprintCyan.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Empty State

struct EmptyPresetsView: View {
    @State private var glowAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Schematic icon
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blueprintCyan.opacity(glowAnimation ? 0.3 : 0.1), lineWidth: 1)
                    .frame(width: 80, height: 60)
                    .scaleEffect(glowAnimation ? 1.1 : 1.0)

                // Inner rectangles representing windows
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.blueprintCyan.opacity(0.5), lineWidth: 0.5)
                            .frame(width: 30, height: 20)
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.blueprintCyan.opacity(0.5), lineWidth: 0.5)
                            .frame(width: 30, height: 20)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.blueprintCyan.opacity(0.5), lineWidth: 0.5)
                        .frame(width: 64, height: 24)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }

            VStack(spacing: 8) {
                Text("NO PRESETS SAVED")
                    .font(BlueprintFont.display(13, weight: .semibold))
                    .foregroundColor(.blueprintText)
                    .tracking(1)

                Text("Select apps from the left panel and save\na preset to quickly restore your workspace")
                    .font(BlueprintFont.mono(10))
                    .foregroundColor(.blueprintTextDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preset Card

struct BlueprintPresetCard: View {
    let preset: Preset
    let isHovered: Bool
    var isDragging: Bool = false
    let onApply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(BlueprintFont.display(13, weight: .semibold))
                        .foregroundColor(.blueprintText)

                    Text("\(preset.windows.count) WINDOW\(preset.windows.count == 1 ? "" : "S")")
                        .font(BlueprintFont.mono(9, weight: .medium))
                        .foregroundColor(.blueprintCyan)
                        .tracking(0.5)
                }

                Spacer()

                // Action buttons (visible on hover)
                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: onApply) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("APPLY")
                                    .font(BlueprintFont.mono(9, weight: .medium))
                            }
                            .foregroundColor(.blueprintDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blueprintCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.blueprintRed)
                                .frame(width: 28, height: 28)
                                .background(Color.blueprintRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(12)

            // Divider
            Rectangle()
                .fill(Color.blueprintCyan.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Mini preview + app list
            HStack(spacing: 12) {
                // Screen preview
                ScreenPreviewView(windows: preset.windows)
                    .frame(width: 100, height: 60)

                // App names with coordinates
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preset.windows.prefix(3)) { window in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.blueprintCyan.opacity(0.6))
                                .frame(width: 4, height: 4)

                            Text(window.appName)
                                .font(BlueprintFont.mono(9))
                                .foregroundColor(.blueprintText)
                                .lineLimit(1)
                        }
                    }

                    if preset.windows.count > 3 {
                        Text("+\(preset.windows.count - 3) more")
                            .font(BlueprintFont.mono(8))
                            .foregroundColor(.blueprintTextDim)
                    }
                }

                Spacer()
            }
            .padding(12)

            // Coordinate bar (visible on hover)
            if isHovered, let firstWindow = preset.windows.first {
                HStack {
                    CoordinateLabel(
                        x: firstWindow.x,
                        y: firstWindow.y,
                        width: firstWindow.width,
                        height: firstWindow.height
                    )
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blueprintLight.opacity(isHovered ? 0.6 : 0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isDragging ? Color.blueprintCyan.opacity(0.8) :
                    (isHovered ? Color.blueprintCyan.opacity(0.4) : Color.blueprintCyan.opacity(0.15)),
                    lineWidth: isDragging ? 2 : (isHovered ? 1 : 0.5)
                )
        )
        .opacity(isDragging ? 0.6 : 1.0)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Settings Sheet

struct BlueprintSettingsSheet: View {
    @ObservedObject var windowManager: WindowManager
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("SETTINGS")
                        .font(BlueprintFont.display(16, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(2)

                    Text("Configure LoadOut behavior")
                        .font(BlueprintFont.mono(11))
                        .foregroundColor(.blueprintTextDim)
                }

                VStack(spacing: 16) {
                    // Launch at Login
                    BlueprintSettingsToggle(
                        title: "LAUNCH AT LOGIN",
                        description: "Start LoadOut automatically when you log in",
                        icon: "power",
                        isOn: $windowManager.launchAtLogin
                    )

                    // Hide Dock Icon
                    BlueprintSettingsToggle(
                        title: "MENU BAR ONLY",
                        description: "Hide dock icon — use menu bar icon to reopen",
                        icon: "menubar.rectangle",
                        isOn: $windowManager.hideDockIcon
                    )
                }
                .padding(.horizontal, 8)

                // Info about reordering
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                        .foregroundColor(.blueprintCyan)

                    Text("Drag presets to reorder them")
                        .font(BlueprintFont.mono(10))
                        .foregroundColor(.blueprintTextDim)
                }
                .padding(.top, 8)

                Spacer()

                // Close button
                Button("DONE") {
                    onDismiss()
                }
                .buttonStyle(BlueprintPrimaryButton())
                .keyboardShortcut(.defaultAction)
            }
            .padding(32)
        }
        .frame(width: 380, height: 340)
    }
}

struct BlueprintSettingsToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isOn ? .blueprintCyan : .blueprintTextDim)
                .frame(width: 24)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BlueprintFont.mono(10, weight: .semibold))
                    .foregroundColor(.blueprintText)
                    .tracking(0.5)

                Text(description)
                    .font(BlueprintFont.mono(9))
                    .foregroundColor(.blueprintTextDim)
            }

            Spacer()

            // Toggle
            BlueprintToggle(isOn: $isOn)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blueprintLight.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blueprintCyan.opacity(isOn ? 0.3 : 0.1), lineWidth: 0.5)
        )
    }
}

struct BlueprintToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.blueprintCyan : Color.blueprintLight)
                    .frame(width: 44, height: 24)

                Circle()
                    .fill(isOn ? Color.blueprintDeep : Color.blueprintTextDim)
                    .frame(width: 18, height: 18)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save Sheet

struct BlueprintSaveSheet: View {
    @Binding var presetName: String
    let selectedApps: [RunningApp]
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("SAVE PRESET")
                        .font(BlueprintFont.display(16, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(2)

                    Text("Capture current window positions for \(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s")")
                        .font(BlueprintFont.mono(11))
                        .foregroundColor(.blueprintTextDim)
                }

                // Selected apps preview
                HStack(spacing: -8) {
                    ForEach(selectedApps.prefix(5)) { app in
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .background(Color.blueprintMid)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blueprintDeep, lineWidth: 2)
                                )
                        }
                    }

                    if selectedApps.count > 5 {
                        Text("+\(selectedApps.count - 5)")
                            .font(BlueprintFont.mono(10, weight: .semibold))
                            .foregroundColor(.blueprintCyan)
                            .frame(width: 32, height: 32)
                            .background(Color.blueprintMid)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blueprintDeep, lineWidth: 2)
                            )
                    }
                }

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRESET NAME")
                        .font(BlueprintFont.mono(9, weight: .semibold))
                        .foregroundColor(.blueprintCyan)
                        .tracking(1)

                    TextField("", text: $presetName, prompt: Text("e.g., Development, Design, Communication")
                        .foregroundColor(.blueprintTextDim))
                        .textFieldStyle(.plain)
                        .font(BlueprintFont.display(14))
                        .foregroundColor(.blueprintText)
                        .padding(12)
                        .background(Color.blueprintLight.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    isTextFieldFocused ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.3),
                                    lineWidth: isTextFieldFocused ? 1.5 : 0.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .focused($isTextFieldFocused)
                }
                .frame(width: 320)

                // Buttons
                HStack(spacing: 12) {
                    Button("CANCEL") {
                        onCancel()
                    }
                    .buttonStyle(BlueprintSecondaryButton())
                    .keyboardShortcut(.cancelAction)

                    Button("SAVE PRESET") {
                        onSave()
                    }
                    .buttonStyle(BlueprintPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(32)
        }
        .frame(width: 420, height: 340)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    ContentView(windowManager: WindowManager())
}
