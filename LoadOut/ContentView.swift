//
//  ContentView.swift
//  LoadOut
//
//  Blueprint-themed window layout management interface
//

import ApplicationServices
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var presetName: String = ""
    @State private var showingSaveSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingOnboarding: Bool = false
    @State private var editingPreset: Preset?
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
                        totalCount: windowManager.runningApps.count,
                        onSave: { showingSaveSheet = true },
                        onSaveAll: {
                            // Select all apps then show save sheet
                            windowManager.selectAllApps()
                            showingSaveSheet = true
                        }
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
                                        onEdit: {
                                            editingPreset = preset
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
            // Show onboarding on first launch
            if !windowManager.hasSeenOnboarding {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            BlueprintOnboardingSheet(windowManager: windowManager) {
                showingOnboarding = false
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            BlueprintSaveSheet(
                presetName: $presetName,
                selectedApps: windowManager.runningApps.filter { $0.isSelected }
            ) { launchItems in
                if !presetName.trimmingCharacters(in: .whitespaces).isEmpty {
                    windowManager.savePreset(name: presetName, launchItems: launchItems)
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
            } onShowSetup: {
                // Small delay to let settings sheet dismiss first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingOnboarding = true
                }
            }
        }
        .sheet(item: $editingPreset) { preset in
            BlueprintEditPresetSheet(
                preset: preset,
                windowManager: windowManager
            ) {
                editingPreset = nil
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
    let totalCount: Int
    let onSave: () -> Void
    let onSaveAll: () -> Void

    var body: some View {
        HStack {
            // Selection count with visual indicator
            HStack(spacing: 8) {
                if selectedCount > 0 {
                    StatusDot(status: .active)
                }

                Text(selectedCount > 0 ? "\(selectedCount) SELECTED" : "SELECT APPS OR SAVE ALL")
                    .font(BlueprintFont.mono(10, weight: .medium))
                    .foregroundColor(selectedCount > 0 ? .blueprintCyan : .blueprintTextDim)
                    .tracking(0.5)
            }

            Spacer()

            HStack(spacing: 10) {
                // Save All button
                Button {
                    onSaveAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 10))
                        Text("SAVE ALL")
                            .font(BlueprintFont.mono(10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.blueprintCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blueprintCyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 0.5)
                    )
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(totalCount == 0)
                .help("Save all running apps as a preset")

                // Save Selected button
                Button("SAVE SELECTED") {
                    onSave()
                }
                .buttonStyle(BlueprintPrimaryButton())
                .disabled(selectedCount == 0)
            }
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
    let onEdit: () -> Void
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
                    HStack(spacing: 6) {
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

                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(.blueprintCyan)
                                .frame(width: 28, height: 28)
                                .background(Color.blueprintCyan.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Edit preset")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.blueprintRed)
                                .frame(width: 28, height: 28)
                                .background(Color.blueprintRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Delete preset")
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
    let onShowSetup: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("SETTINGS")
                        .font(BlueprintFont.display(16, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(2)

                    Text("Configure LoadOut behavior")
                        .font(BlueprintFont.mono(11))
                        .foregroundColor(.blueprintTextDim)
                }

                VStack(spacing: 12) {
                    // Launch at Login
                    BlueprintSettingsToggle(
                        title: "LAUNCH AT LOGIN",
                        description: "Start automatically when you log in",
                        icon: "power",
                        isOn: $windowManager.launchAtLogin
                    )

                    // Hide Dock Icon
                    BlueprintSettingsToggle(
                        title: "MENU BAR ONLY",
                        description: "Hide dock icon, access via menu bar",
                        icon: "menubar.rectangle",
                        isOn: $windowManager.hideDockIcon
                    )
                }

                Spacer()

                // Setup button
                Button {
                    onDismiss()
                    onShowSetup()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                        Text("SHOW SETUP GUIDE")
                            .font(BlueprintFont.mono(10, weight: .medium))
                    }
                    .foregroundColor(.blueprintTextDim)
                }
                .buttonStyle(.plain)

                // Close button
                Button("DONE") {
                    onDismiss()
                }
                .buttonStyle(BlueprintPrimaryButton())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(width: 340, height: 300)
    }
}

struct BlueprintSettingsToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isOn ? .blueprintCyan : .blueprintTextDim)
                .frame(width: 20)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BlueprintFont.mono(10, weight: .semibold))
                    .foregroundColor(.blueprintText)
                    .tracking(0.5)

                Text(description)
                    .font(BlueprintFont.mono(9))
                    .foregroundColor(.blueprintTextDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Toggle
            BlueprintToggle(isOn: $isOn)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
    let onSave: ([LaunchItem]) -> Void
    let onCancel: () -> Void

    @State private var launchItems: [LaunchItem] = []
    @State private var newLaunchItem: String = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isLaunchItemFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("SAVE PRESET")
                        .font(BlueprintFont.display(16, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(2)

                    Text("Capture window positions for \(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s")")
                        .font(BlueprintFont.mono(11))
                        .foregroundColor(.blueprintTextDim)
                }
                .padding(.bottom, 16)

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
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 16) {
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
                                            isNameFocused ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.3),
                                            lineWidth: isNameFocused ? 1.5 : 0.5
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .focused($isNameFocused)
                        }

                        // Launch Items section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("LAUNCH ITEMS")
                                    .font(BlueprintFont.mono(9, weight: .semibold))
                                    .foregroundColor(.blueprintCyan)
                                    .tracking(1)

                                Spacer()

                                Text("Optional")
                                    .font(BlueprintFont.mono(8))
                                    .foregroundColor(.blueprintTextDim)
                            }

                            Text("Add URLs or file paths to open with this preset")
                                .font(BlueprintFont.mono(9))
                                .foregroundColor(.blueprintTextDim)

                            // Add new item
                            HStack(spacing: 8) {
                                TextField("", text: $newLaunchItem, prompt: Text("https://... or ~/path/to/file")
                                    .foregroundColor(.blueprintTextDim))
                                    .textFieldStyle(.plain)
                                    .font(BlueprintFont.mono(11))
                                    .foregroundColor(.blueprintText)
                                    .padding(10)
                                    .background(Color.blueprintLight.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                isLaunchItemFocused ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.2),
                                                lineWidth: 0.5
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .focused($isLaunchItemFocused)
                                    .onSubmit {
                                        addLaunchItem()
                                    }

                                Button {
                                    addLaunchItem()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blueprintDeep)
                                        .frame(width: 32, height: 32)
                                        .background(Color.blueprintCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .disabled(newLaunchItem.trimmingCharacters(in: .whitespaces).isEmpty)
                            }

                            // List of added launch items
                            if !launchItems.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(launchItems) { item in
                                        HStack(spacing: 10) {
                                            Image(systemName: item.icon)
                                                .font(.system(size: 11))
                                                .foregroundColor(.blueprintCyan)
                                                .frame(width: 16)

                                            Text(item.displayName)
                                                .font(BlueprintFont.mono(10, weight: .medium))
                                                .foregroundColor(.blueprintText)
                                                .lineLimit(1)

                                            Spacer()

                                            Button {
                                                launchItems.removeAll { $0.id == item.id }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(.blueprintRed)
                                                    .frame(width: 20, height: 20)
                                                    .background(Color.blueprintRed.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.blueprintLight.opacity(0.3))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blueprintMid.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blueprintCyan.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .frame(width: 340)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button("CANCEL") {
                        onCancel()
                    }
                    .buttonStyle(BlueprintSecondaryButton())
                    .keyboardShortcut(.cancelAction)

                    Button("SAVE PRESET") {
                        onSave(launchItems)
                    }
                    .buttonStyle(BlueprintPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 20)
            }
            .padding(28)
        }
        .frame(width: 420, height: 520)
        .onAppear {
            isNameFocused = true
        }
    }

    private func addLaunchItem() {
        let trimmed = newLaunchItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        launchItems.append(LaunchItem(path: trimmed))
        newLaunchItem = ""
    }
}

// MARK: - Edit Preset Sheet

struct BlueprintEditPresetSheet: View {
    let preset: Preset
    @ObservedObject var windowManager: WindowManager
    let onDismiss: () -> Void

    @State private var editedName: String = ""
    @State private var newLaunchItem: String = ""
    @State private var showingUpdateConfirmation = false
    @State private var availableApps: [RunningApp] = []
    @FocusState private var isNameFocused: Bool
    @FocusState private var isLaunchItemFocused: Bool

    // Get the current preset from windowManager to reflect changes
    var currentPreset: Preset {
        windowManager.presets.first { $0.id == preset.id } ?? preset
    }

    private func updateAvailableApps() {
        let existingBundleIds = Set(currentPreset.windows.map { $0.bundleIdentifier })
        availableApps = windowManager.runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            // Exclude apps already in preset and apps without visible windows
            return !existingBundleIds.contains(bundleId) && windowManager.appHasWindows(app)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("EDIT PRESET")
                        .font(BlueprintFont.display(16, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(2)

                    Text("Configure preset settings and launch items")
                        .font(BlueprintFont.mono(11))
                        .foregroundColor(.blueprintTextDim)
                }
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRESET NAME")
                                .font(BlueprintFont.mono(9, weight: .semibold))
                                .foregroundColor(.blueprintCyan)
                                .tracking(1)

                            TextField("", text: $editedName)
                                .textFieldStyle(.plain)
                                .font(BlueprintFont.display(14))
                                .foregroundColor(.blueprintText)
                                .padding(12)
                                .background(Color.blueprintLight.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            isNameFocused ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.3),
                                            lineWidth: isNameFocused ? 1.5 : 0.5
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .focused($isNameFocused)
                        }

                        // Update positions button
                        Button {
                            windowManager.updatePresetPositions(preset)
                            showingUpdateConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showingUpdateConfirmation = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: showingUpdateConfirmation ? "checkmark" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                Text(showingUpdateConfirmation ? "POSITIONS UPDATED" : "UPDATE WINDOW POSITIONS")
                                    .font(BlueprintFont.mono(10, weight: .medium))
                            }
                            .foregroundColor(showingUpdateConfirmation ? .blueprintCyan : .blueprintText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(showingUpdateConfirmation ? Color.blueprintCyan.opacity(0.2) : Color.blueprintLight.opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blueprintCyan.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)

                        // Launch Items section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("LAUNCH ITEMS")
                                    .font(BlueprintFont.mono(9, weight: .semibold))
                                    .foregroundColor(.blueprintCyan)
                                    .tracking(1)

                                Spacer()

                                Text("URLs & files to open")
                                    .font(BlueprintFont.mono(8))
                                    .foregroundColor(.blueprintTextDim)
                            }

                            // Add new item
                            HStack(spacing: 8) {
                                TextField("", text: $newLaunchItem, prompt: Text("https://... or ~/path/to/file")
                                    .foregroundColor(.blueprintTextDim))
                                    .textFieldStyle(.plain)
                                    .font(BlueprintFont.mono(11))
                                    .foregroundColor(.blueprintText)
                                    .padding(10)
                                    .background(Color.blueprintLight.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                isLaunchItemFocused ? Color.blueprintCyan : Color.blueprintCyan.opacity(0.2),
                                                lineWidth: 0.5
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .focused($isLaunchItemFocused)
                                    .onSubmit {
                                        addLaunchItem()
                                    }

                                Button {
                                    addLaunchItem()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blueprintDeep)
                                        .frame(width: 32, height: 32)
                                        .background(Color.blueprintCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .disabled(newLaunchItem.trimmingCharacters(in: .whitespaces).isEmpty)
                            }

                            // List of launch items
                            if currentPreset.launchItems.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No launch items")
                                        .font(BlueprintFont.mono(10))
                                        .foregroundColor(.blueprintTextDim)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(currentPreset.launchItems) { item in
                                        HStack(spacing: 10) {
                                            Image(systemName: item.icon)
                                                .font(.system(size: 11))
                                                .foregroundColor(.blueprintCyan)
                                                .frame(width: 16)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.displayName)
                                                    .font(BlueprintFont.mono(10, weight: .medium))
                                                    .foregroundColor(.blueprintText)
                                                    .lineLimit(1)

                                                Text(item.path)
                                                    .font(BlueprintFont.mono(8))
                                                    .foregroundColor(.blueprintTextDim)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Button {
                                                windowManager.removeLaunchItem(from: preset, item: item)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(.blueprintRed)
                                                    .frame(width: 20, height: 20)
                                                    .background(Color.blueprintRed.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.blueprintLight.opacity(0.3))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blueprintMid.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blueprintCyan.opacity(0.15), lineWidth: 0.5)
                        )

                        // Windows in preset (with remove capability)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WINDOWS IN PRESET")
                                .font(BlueprintFont.mono(9, weight: .semibold))
                                .foregroundColor(.blueprintCyan)
                                .tracking(0.5)

                            if currentPreset.windows.isEmpty {
                                Text("No windows")
                                    .font(BlueprintFont.mono(10))
                                    .foregroundColor(.blueprintTextDim)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(currentPreset.windows) { window in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color.blueprintCyan.opacity(0.5))
                                                .frame(width: 6, height: 6)
                                            Text(window.appName)
                                                .font(BlueprintFont.mono(10))
                                                .foregroundColor(.blueprintText)
                                            Spacer()
                                            Text("\(Int(window.width))×\(Int(window.height))")
                                                .font(BlueprintFont.mono(9))
                                                .foregroundColor(.blueprintTextDim)

                                            // Remove button (only show if more than 1 window)
                                            if currentPreset.windows.count > 1 {
                                                Button {
                                                    windowManager.removeWindowFromPreset(preset, window: window)
                                                    updateAvailableApps()
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundColor(.blueprintRed)
                                                        .frame(width: 20, height: 20)
                                                        .background(Color.blueprintRed.opacity(0.1))
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blueprintLight.opacity(0.3))
                        )

                        // Add windows section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ADD WINDOWS")
                                    .font(BlueprintFont.mono(9, weight: .semibold))
                                    .foregroundColor(.blueprintCyan)
                                    .tracking(1)

                                Spacer()

                                Button {
                                    windowManager.refreshRunningApps()
                                    updateAvailableApps()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blueprintTextDim)
                                }
                                .buttonStyle(.plain)
                                .help("Refresh app list")
                            }

                            if availableApps.isEmpty {
                                Text("All running apps are in this preset")
                                    .font(BlueprintFont.mono(10))
                                    .foregroundColor(.blueprintTextDim)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(availableApps) { app in
                                        HStack(spacing: 10) {
                                            // App icon
                                            if let icon = app.icon {
                                                Image(nsImage: icon)
                                                    .resizable()
                                                    .frame(width: 20, height: 20)
                                            } else {
                                                Image(systemName: "app.fill")
                                                    .frame(width: 20, height: 20)
                                                    .foregroundColor(.blueprintTextDim)
                                            }

                                            Text(app.name)
                                                .font(BlueprintFont.mono(10))
                                                .foregroundColor(.blueprintText)
                                                .lineLimit(1)

                                            Spacer()

                                            // Add button
                                            Button {
                                                windowManager.addWindowToPreset(preset, from: app)
                                                updateAvailableApps()
                                            } label: {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.blueprintCyan)
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.blueprintCyan.opacity(0.15))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blueprintMid.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blueprintCyan.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .frame(width: 340)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button("CANCEL") {
                        onDismiss()
                    }
                    .buttonStyle(BlueprintSecondaryButton())
                    .keyboardShortcut(.cancelAction)

                    Button("DONE") {
                        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
                        if !trimmedName.isEmpty && trimmedName != preset.name {
                            windowManager.renamePreset(preset, to: trimmedName)
                        }
                        onDismiss()
                    }
                    .buttonStyle(BlueprintPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 20)
            }
            .padding(28)
        }
        .frame(width: 420, height: 700)
        .onAppear {
            editedName = preset.name
            isNameFocused = true
            windowManager.refreshRunningApps()
            updateAvailableApps()
        }
    }

    private func addLaunchItem() {
        let trimmed = newLaunchItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        windowManager.addLaunchItem(to: preset, path: trimmed)
        newLaunchItem = ""
    }
}

// MARK: - Onboarding Sheet

struct BlueprintOnboardingSheet: View {
    @ObservedObject var windowManager: WindowManager
    let onComplete: () -> Void

    @State private var permissionGranted = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background
            Color.blueprintDeep
                .ignoresSafeArea()

            BlueprintGridBackground(showCrosshair: false)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon and title
                VStack(spacing: 16) {
                    // Stylized window icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blueprintCyan, lineWidth: 2)
                            .frame(width: 70, height: 50)

                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blueprintCyan.opacity(0.3))
                                .frame(width: 28, height: 36)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blueprintCyan.opacity(0.5))
                                .frame(width: 28, height: 36)
                        }
                    }

                    Text("LOADOUT")
                        .font(BlueprintFont.display(28, weight: .bold))
                        .foregroundColor(.blueprintText)
                        .tracking(4)

                    Text("Save and restore your window layouts")
                        .font(BlueprintFont.mono(12))
                        .foregroundColor(.blueprintTextDim)
                }

                // Permission section
                VStack(spacing: 20) {
                    Text("SETUP REQUIRED")
                        .font(BlueprintFont.mono(10, weight: .semibold))
                        .foregroundColor(.blueprintCyan)
                        .tracking(1)

                    // Permission status card
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            // Status icon
                            ZStack {
                                Circle()
                                    .fill(permissionGranted ? Color.green.opacity(0.2) : Color.blueprintAmber.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: permissionGranted ? "checkmark.circle.fill" : "hand.raised.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(permissionGranted ? .green : .blueprintAmber)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accessibility Permission")
                                    .font(BlueprintFont.mono(12, weight: .semibold))
                                    .foregroundColor(.blueprintText)

                                Text(permissionGranted ? "Permission granted" : "Required to read and set window positions")
                                    .font(BlueprintFont.mono(10))
                                    .foregroundColor(permissionGranted ? .green : .blueprintTextDim)
                            }

                            Spacer()

                            if permissionGranted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blueprintLight.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(permissionGranted ? Color.green.opacity(0.5) : Color.blueprintCyan.opacity(0.2), lineWidth: 1)
                        )

                        if !permissionGranted {
                            Button {
                                openAccessibilitySettings()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gear")
                                        .font(.system(size: 12))
                                    Text("OPEN SYSTEM SETTINGS")
                                        .font(BlueprintFont.mono(11, weight: .semibold))
                                }
                                .foregroundColor(.blueprintDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blueprintCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            Text("Enable LoadOut in Privacy & Security → Accessibility")
                                .font(BlueprintFont.mono(9))
                                .foregroundColor(.blueprintTextDim)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(width: 340)
                }

                Spacer()

                // Continue button
                Button {
                    windowManager.hasSeenOnboarding = true
                    onComplete()
                } label: {
                    Text(permissionGranted ? "GET STARTED" : "CONTINUE WITHOUT PERMISSION")
                        .font(BlueprintFont.mono(11, weight: .semibold))
                        .foregroundColor(permissionGranted ? .blueprintDeep : .blueprintTextDim)
                        .frame(width: 280)
                        .padding(.vertical, 12)
                        .background(permissionGranted ? Color.blueprintCyan : Color.blueprintLight.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(permissionGranted ? Color.clear : Color.blueprintCyan.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                if !permissionGranted {
                    Text("You can grant permission later from the app")
                        .font(BlueprintFont.mono(9))
                        .foregroundColor(.blueprintTextDim)
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding(32)
        }
        .frame(width: 440, height: 520)
        .onAppear {
            permissionGranted = windowManager.accessibilityEnabled
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let granted = AXIsProcessTrusted()
            if granted != permissionGranted {
                withAnimation(.easeOut(duration: 0.3)) {
                    permissionGranted = granted
                    windowManager.accessibilityEnabled = granted
                }
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView(windowManager: WindowManager())
}
