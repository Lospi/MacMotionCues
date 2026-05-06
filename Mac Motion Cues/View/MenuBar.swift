import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBar: View {
    @Bindable var pipeline: MotionPipeline
    @Bindable var appState: AppState
    @Bindable var settings: DotsSettings

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

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Style")
                            .frame(width: 50, alignment: .leading)
                        Picker("Style", selection: $settings.dotStyle) {
                            Text("Solid").tag(DotStyle.solid)
                            Text("Dynamic").tag(DotStyle.dynamic)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    HStack {
                        Text("Halo")
                            .frame(width: 50, alignment: .leading)
                        Picker("Halo", selection: $settings.haloStyle) {
                            Text("Off").tag(HaloStyle.off)
                            Text("Solid").tag(HaloStyle.solid)
                            Text("Dynamic").tag(HaloStyle.dynamic)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
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
            UpdateView()

            Button("Quit Mac Motion Cues") {
                NSApplication.shared.terminate(nil)
            }
            .padding()
        }
        .frame(width: 300)
        .padding(.vertical)
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
                Text("Auto-enable when in vehicle")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
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
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { pipeline.setMotionSource(source.id, enabled: $0) }
            )) {
                Text(LocalizedStringKey(type(of: source).displayName))
                    .font(.caption.weight(.semibold))
            }
            .toggleStyle(.switch)

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
