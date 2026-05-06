import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBar: View {
    @Bindable var motionViewModel: MotionViewModel
    @Bindable var settings: DotsSettings
    let overlay: OverlayWindowController
    @AppStorage("appEnabled") private var appEnabled: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("Mac Motion Cues")
                .font(.headline)
                .padding(.top)

            Toggle("Enable Visual Cues", isOn: $appEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal)

            Divider()

            if appEnabled {
                GroupBox {
                    Text("Visual Settings")
                        .font(.subheadline)
                        .padding(.bottom, 5)

                    VStack(spacing: 10) {
                        HStack {
                            Text("Size")
                            Slider(value: $settings.dotSize, in: 10...30, step: 1)
                                .onChange(of: settings.dotSize) {
                                    settings.ensureSpacingFitsSize()
                                    overlay.notifySettingsChanged()
                                }
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
                            .onChange(of: settings.verticalSpacing) {
                                overlay.notifySettingsChanged()
                            }
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

                    VStack(spacing: 10) {
                        Button {
                            Task {
                                if motionViewModel.isMotionEnabled {
                                    motionViewModel.stopDeviceMotion()
                                } else {
                                    try await motionViewModel.startDeviceMotion()
                                }
                            }
                        } label: {
                            Text(motionViewModel.isMotionEnabled ? "Disable Motion" : "Enable Motion")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if motionViewModel.isMotionEnabled {
                            HStack {
                                Image(systemName: "airpods")
                                Text("AirPods connected")
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }

                            HStack {
                                Text("Sensitivity")
                                Slider(value: $settings.motionSensitivity, in: 1...20, step: 1)
                                Text("\(Int(settings.motionSensitivity))")
                                    .frame(width: 40, alignment: .trailing)
                                    .monospacedDigit()
                            }

                            MotionReadout(motionViewModel: motionViewModel)

                            HStack {
                                Toggle("Enable X Motion (BETA)", isOn: $settings.xMotionEnabled)
                                    .toggleStyle(.switch)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
            }

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
