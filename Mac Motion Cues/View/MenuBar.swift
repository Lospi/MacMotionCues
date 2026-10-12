import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBar: View {
    @Bindable var pipeline: MotionPipeline
    @Bindable var appState: AppState
    @Bindable var settings: DotsSettings
    let updater: SPUUpdater

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("Mac Motion Cues")
                .font(.headline)
                .padding(.top)

            Toggle("Enable Visual Cues", isOn: $appState.appEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal)

            Divider()

            GroupBox {
                Text("Visual Settings")
                    .font(.subheadline)
                    .padding(.bottom, 5)

                VStack(spacing: 10) {
                    HStack {
                        Text("Size")
                        Slider(value: $settings.dotSize, in: 10...30, step: 1)
                        Text("\(Int(settings.dotSize))")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Spacing")
                        Slider(
                            value: $settings.verticalSpacing,
                            in: 20...100,
                            step: 5
                        )
                        Text("\(Int(settings.verticalSpacing))")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            GroupBox {
                Text("Dot Style")
                    .font(.subheadline)
                    .padding(.bottom, 5)

                // Grid sizes the label column to its widest localized label.
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                    GridRow {
                        Text("Style")
                        Picker("Style", selection: $settings.dotStyle) {
                            Text("Solid").tag(DotStyle.solid)
                            Text("Dynamic").tag(DotStyle.dynamic)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        InfoButton(subject: "Style", text: "**Solid:** a plain dot in your chosen tint.\n**Dynamic:** a frosted-glass dot that blurs what's behind it and adapts to light and dark content.")
                    }

                    GridRow {
                        Text("Tint")
                        DotTintPicker(tint: $settings.dotTint, tintColor: settings.dotTintColor, owner: .dot)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Dot Tint")
                        InfoButton(subject: "Tint", text: "**Automatic** keeps the standard look: black for Solid, clear glass for Dynamic. A color fills a Solid dot and adds a light wash to a Dynamic one.")
                    }

                    GridRow {
                        Text("Opacity")
                        OpacitySlider(value: $settings.dotOpacity, label: "Dot Opacity")
                    }

                    Divider()

                    GridRow {
                        Text("Halo")
                        Picker("Halo", selection: $settings.haloStyle) {
                            Text("Off").tag(HaloStyle.off)
                            Text("Solid").tag(HaloStyle.solid)
                            Text("Dynamic").tag(HaloStyle.dynamic)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        InfoButton(subject: "Halo", text: "A thin ring around each dot that makes it easier to spot on busy backgrounds.\n**Solid:** a ring in your halo tint.\n**Dynamic:** a frosted ring that adapts to the background.")
                    }

                    Group {
                        GridRow {
                            Text("Tint")
                            DotTintPicker(tint: $settings.haloTint, tintColor: settings.haloTintColor, owner: .halo)
                                .accessibilityElement(children: .contain)
                                .accessibilityLabel("Halo Tint")
                        }

                        GridRow {
                            Text("Opacity")
                            OpacitySlider(value: $settings.haloOpacity, label: "Halo Opacity")
                        }
                    }
                    .disabled(settings.haloStyle == .off)
                    // Plain-style swatches don't dim on their own when disabled.
                    .opacity(settings.haloStyle == .off ? 0.4 : 1)
                }
            }
            .padding(.horizontal)

            Divider()

            GroupBox {
                Text("Motion Settings")
                    .font(.subheadline)
                    .padding(.bottom, 5)

                MotionStatusPanel(pipeline: pipeline, settings: settings)
            }
            .padding(.horizontal)

            Divider()

            GroupBox {
                VStack(alignment: .center, spacing: 5) {
                    Text("About")
                        .font(.subheadline)

                    Text("Mac Motion Cues")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("View Source Code", destination: URL(string: "https://github.com/Lospi/MacMotionCues")!)
                        .font(.caption)
                }
            }
            .padding(.horizontal)

            Divider()

            LaunchAtLogin.Toggle {
                Text("Launch at Login")
            }
            UpdateView(updater: updater)

            Button("Quit Mac Motion Cues") {
                NSApplication.shared.terminate(nil)
            }
            .padding()
        }
        .frame(width: 320)
        .padding(.vertical)
    }
}

/// Small ⓘ button that shows a short explanation in a popover on click.
private struct InfoButton: View {
    let subject: LocalizedStringResource
    let text: LocalizedStringKey
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "More info about \(String(localized: subject))"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)
                .padding(12)
        }
    }
}

private struct OpacitySlider: View {
    @Binding var value: Double
    let label: LocalizedStringKey

    var body: some View {
        HStack {
            Slider(value: $value, in: 0.2...1, step: 0.05)
                .accessibilityLabel(label)
            Text(value, format: .percent.precision(.fractionLength(0)))
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

private struct DotTintPicker: View {
    @Binding var tint: DotTint
    let tintColor: Color?
    let owner: ColorPanelBridge.Owner

    // Picked to stay legible over both light and dark content.
    private static let presets: [(name: LocalizedStringKey, tint: DotTint)] = [
        ("Black", DotTint(rgb: 0x000000)),
        ("White", DotTint(rgb: 0xFFFFFF)),
        ("Red", DotTint(rgb: 0xFF3B30)),
        ("Orange", DotTint(rgb: 0xFF9500)),
        ("Green", DotTint(rgb: 0x34C759)),
        ("Blue", DotTint(rgb: 0x0A84FF)),
    ]

    private var isCustomSelected: Bool {
        tint != .automatic && !Self.presets.contains { $0.tint == tint }
    }

    var body: some View {
        HStack(spacing: 4) {
            swatch("Automatic", isSelected: tint == .automatic) {
                tint = .automatic
                ColorPanelBridge.shared.sync(nil, for: owner)
            } content: {
                // Half filled, half clear: the untinted solid / vibrant default.
                // `.primary` keeps the split visible in dark mode, unlike the Black preset.
                Circle()
                    .fill(LinearGradient(
                        stops: [.init(color: .primary, location: 0.5), .init(color: .clear, location: 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay { Circle().strokeBorder(Color.secondary, lineWidth: 0.5) }
            }

            ForEach(Self.presets.indices, id: \.self) { index in
                let preset = Self.presets[index]
                swatch(preset.name, isSelected: tint == preset.tint) {
                    tint = preset.tint
                    ColorPanelBridge.shared.sync(preset.tint.nsColor, for: owner)
                } content: {
                    Circle()
                        .fill(preset.tint.color ?? .clear)
                        .overlay { Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5) }
                }
            }

            swatch("Custom Color…", isSelected: isCustomSelected) {
                // The popover usually closes once the panel takes focus; the
                // bridge is a long-lived target, so changes still land here.
                let initial = tint.nsColor ?? .white
                ColorPanelBridge.shared.open(initial: initial, for: owner) { [$tint] color in
                    if let picked = DotTint(nsColor: color), picked != $tint.wrappedValue {
                        $tint.wrappedValue = picked
                    }
                }
            } content: {
                Circle()
                    .fill(AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    ))
                    .overlay {
                        if isCustomSelected, let color = tintColor {
                            Circle()
                                .fill(color)
                                .padding(3)
                        }
                    }
            }

            Spacer(minLength: 0)
        }
    }

    private func swatch<Content: View>(
        _ name: LocalizedStringKey,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .padding(3)
                .frame(width: 18, height: 18)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Drives the shared `NSColorPanel` for the custom tint. A SwiftUI
/// `ColorPicker` is unreliable inside a `.window` MenuBarExtra of an agent
/// app (the popover closes as soon as the panel takes focus, tearing the
/// well's binding down with it), so the panel targets this singleton instead.
@MainActor
private final class ColorPanelBridge: NSObject {
    /// Which tint the shared panel is currently editing.
    enum Owner { case dot, halo }

    static let shared = ColorPanelBridge()
    private var owner: Owner?
    private var onChange: ((NSColor) -> Void)?
    private var closeObserver: NSObjectProtocol?

    func open(initial: NSColor, for owner: Owner, onChange: @escaping (NSColor) -> Void) {
        self.owner = owner
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        setColor(initial, on: panel)
        panel.level = .floating
        observeClose(of: panel)
        NSApp.activate()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    /// Keeps an open panel in step with a tint picked elsewhere (preset or
    /// Automatic), so a later nudge of the panel can't override that choice.
    /// No-op unless the panel is currently editing `owner`'s tint.
    func sync(_ color: NSColor?, for owner: Owner) {
        let panel = NSColorPanel.shared
        guard panel.isVisible, owner == self.owner else { return }
        guard let color else {
            panel.orderOut(nil)
            return
        }
        setColor(color, on: panel)
    }

    private func setColor(_ color: NSColor, on panel: NSColorPanel) {
        // Detach before seeding the color so it doesn't fire a stale action.
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.color = color
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
    }

    /// `open` activates the agent app so the panel can become key; hand focus
    /// back to the previous app once the panel is closed. (`NSApp.hide` would
    /// also hide the overlay window, so deactivate instead.)
    private func observeClose(of panel: NSColorPanel) {
        guard closeObserver == nil else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { NSApp.deactivate() }
        }
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

private struct MotionStatusPanel: View {
    @Bindable var pipeline: MotionPipeline
    @Bindable var settings: DotsSettings

    private var activeState: MotionSourceState? {
        pipeline.activeMotionSource?.state
    }

    private var isStreamingOrStale: Bool {
        activeState == .streaming || activeState == .stale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(pipeline.motionSources.indices, id: \.self) { idx in
                let source = pipeline.motionSources[idx]
                MotionSourceRow(source: source, pipeline: pipeline)
                if idx < pipeline.motionSources.count - 1 {
                    Divider()
                }
            }

            if !pipeline.detectionSources.isEmpty {
                Divider()
                HStack(spacing: 4) {
                    Text("Auto-enable when in vehicle")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    InfoButton(subject: "Auto-enable when in vehicle", text: "Shows cues only while you're traveling at vehicle speed, and hides them again shortly after you stop.")
                }
                ForEach(pipeline.detectionSources.indices, id: \.self) { idx in
                    let source = pipeline.detectionSources[idx]
                    DetectionSourceRow(source: source, pipeline: pipeline)
                }
            }

            if isStreamingOrStale {
                Divider()
                activeSettingsView
            }
        }
    }

    private var activeSettingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sensitivity")
                Slider(value: $settings.motionSensitivity, in: 1...20, step: 1)
                Text("\(Int(settings.motionSensitivity))")
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
                // One info button covers both controls in this block.
                InfoButton(subject: "Sensitivity", text: "**Sensitivity:** how far the dots move for a given motion. Higher means stronger reactions.\n**X Motion:** also moves the dots sideways when the vehicle turns. It's in beta because turning your head can move the dots too.")
            }

            MotionReadout(pipeline: pipeline)

            Toggle("Enable X Motion (BETA)", isOn: $settings.xMotionEnabled)
                .toggleStyle(.switch)
        }
    }
}

private struct MotionSourceRow: View {
    let source: any MotionSource
    @Bindable var pipeline: MotionPipeline

    private var isEnabled: Bool {
        pipeline.enabledMotionSourceIDs.contains(source.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Toggle(isOn: Binding(
                    get: { isEnabled },
                    set: { pipeline.setMotionSource(source.id, enabled: $0) }
                )) {
                    Text(LocalizedStringKey(type(of: source).displayName))
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.switch)

                if source is AirPodsMotionSource {
                    Spacer()
                    InfoButton(subject: "AirPods", text: "Moves the dots using the motion sensors in compatible AirPods (Pro, Max, or 3rd generation and later), so they must be worn for the cues to work.")
                }
            }

            if isEnabled {
                if let airpods = source as? AirPodsMotionSource {
                    AirPodsSourceDetail(source: airpods)
                }
            }
        }
    }
}

private struct DetectionSourceRow: View {
    let source: any VehicleDetectionSource
    @Bindable var pipeline: MotionPipeline

    private var isEnabled: Bool {
        pipeline.enabledDetectionSourceIDs.contains(source.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { pipeline.setDetectionSource(source.id, enabled: $0) }
            )) {
                Text(LocalizedStringKey(type(of: source).displayName))
                    .font(.caption.weight(.semibold))
            }
            .toggleStyle(.switch)

            if isEnabled {
                if let location = source as? CoreLocationDetectionSource {
                    CoreLocationSourceDetail(source: location)
                }
            }
        }
    }
}

private struct CoreLocationSourceDetail: View {
    @Bindable var source: CoreLocationDetectionSource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch source.state {
            case .permissionNotDetermined:
                Text("Asking for location permission…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .permissionDenied, .unavailable, .error:
                permissionDeniedView
            case .idle, .connecting:
                Text("Setting up…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .streaming, .stale:
                statusView
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Location access denied")
                    .font(.caption2.weight(.semibold))
            }
            Button {
                CoreLocationDetectionSource.openSystemSettings()
            } label: {
                Text("Open System Settings…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var statusView: some View {
        HStack(spacing: 6) {
            if source.inVehicle {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("In vehicle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Circle().fill(Color.secondary).frame(width: 6, height: 6)
                Text("Stationary")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct AirPodsSourceDetail: View {
    @Bindable var source: AirPodsMotionSource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch source.state {
            case .permissionNotDetermined:
                permissionNotDeterminedView
            case .permissionDenied, .unavailable, .error:
                permissionDeniedView
            case .idle:
                lookingForAirPodsView
            case .connecting:
                connectingView
            case .streaming:
                streamingView
            case .stale:
                staleView
            }
        }
    }

    private var permissionNotDeterminedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Uses AirPods head-tracking to drive cue motion.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                source.requestPermission()
            } label: {
                Text("Grant Motion Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var permissionDeniedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Motion access denied")
                    .font(.caption2.weight(.semibold))
            }
            Text("Cues need Motion & Fitness to read AirPods movement.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                AirPodsMotionSource.openSystemSettings()
            } label: {
                Text("Open System Settings…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Text("You may need to relaunch the app after granting access.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lookingForAirPodsView: some View {
        HStack(spacing: 6) {
            Image(systemName: "airpods")
                .foregroundColor(.secondary)
            Text("Looking for compatible AirPods…")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var connectingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 14, height: 14)
            Text("Connecting…")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var streamingView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("AirPods connected")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var staleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("AirPods went to sleep")
                    .font(.caption2.weight(.semibold))
            }
            Text("Move your head or take them out and put them back in to reconnect.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MotionReadout: View {
    @Bindable var pipeline: MotionPipeline

    var body: some View {
        let lateralAccel = pipeline.latestSample?.lateralAccel ?? 0
        let longitudinalAccel = pipeline.latestSample?.longitudinalAccel ?? 0
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("X:")
                Text(String(format: "%.2f", lateralAccel))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
            HStack(spacing: 4) {
                Text("Y:")
                Text(String(format: "%.2f", longitudinalAccel))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}
