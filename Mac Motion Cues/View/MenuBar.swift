import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBar: View {
    @Bindable var motionViewModel: MotionViewModel
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

                MotionStatusPanel(motionViewModel: motionViewModel, settings: settings)
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
    @Bindable var motionViewModel: MotionViewModel
    @Bindable var settings: DotsSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch motionViewModel.state {
            case .permissionNotDetermined:
                permissionNotDeterminedView
            case .permissionDenied:
                permissionDeniedView
            case .noAirPods:
                noAirPodsView
            case .connecting:
                connectingView
            case .streaming, .stale:
                activeView
            }
        }
    }

    private var permissionNotDeterminedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mac Motion Cues uses AirPods head-tracking to drive cue motion.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                motionViewModel.requestPermission()
            } label: {
                Text("Grant Motion Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var permissionDeniedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Motion access denied")
                    .font(.caption.weight(.semibold))
            }
            Text("Cues need Motion & Fitness to read AirPods movement.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                MotionViewModel.openSystemSettings()
            } label: {
                Text("Open System Settings…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Text("You may need to relaunch the app after granting access.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noAirPodsView: some View {
        HStack(spacing: 8) {
            Image(systemName: "airpods")
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Put on your AirPods")
                    .font(.caption.weight(.semibold))
                Text("Looking for compatible AirPods…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var connectingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
            Text("Connecting…")
                .font(.caption)
            Spacer()
        }
    }

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if motionViewModel.state == .stale {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("AirPods went to sleep")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Move your head or take them out and put them back in to reconnect.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack {
                    Image(systemName: "airpods")
                    Text("AirPods connected")
                        .font(.caption)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Spacer()
                }
            }

            HStack {
                Text("Sensitivity")
                Slider(value: $settings.motionSensitivity, in: 1...20, step: 1)
                Text("\(Int(settings.motionSensitivity))")
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }

            MotionReadout(motionViewModel: motionViewModel)

            Toggle("Enable X Motion (BETA)", isOn: $settings.xMotionEnabled)
                .toggleStyle(.switch)
        }
    }
}

private struct MotionReadout: View {
    @Bindable var motionViewModel: MotionViewModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("X:")
                Text(String(format: "%.2f", motionViewModel.motionX))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
            HStack(spacing: 4) {
                Text("Y:")
                Text(String(format: "%.2f", motionViewModel.motionY))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}
