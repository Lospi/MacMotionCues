import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBar: View {
    @Bindable var dotsViewModel: DotsViewModel
    @Bindable var motionViewModel: MotionViewModel
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
                            Slider(value: $dotsViewModel.dotSize, in: 10...30, step: 1)
                                .onChange(of: dotsViewModel.dotSize) {
                                    dotsViewModel.updateDotSize()
                                }
                            Text("\(Int(dotsViewModel.dotSize))")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Text("Spacing")
                            Slider(
                                value: $dotsViewModel.verticalSpacing,
                                in: 20...100,
                                step: 5
                            )
                            .onChange(of: dotsViewModel.verticalSpacing) {
                                dotsViewModel.updateSpacing()
                            }
                            Text("\(Int(dotsViewModel.verticalSpacing))")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
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
                                Slider(value: $dotsViewModel.motionSensitivity, in: 1...20, step: 1)
                                Text("\(Int(dotsViewModel.motionSensitivity))")
                                    .frame(width: 40, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Text("X: \(String(format: "%.2f", motionViewModel.motionX))")
                                Text("Y: \(String(format: "%.2f", motionViewModel.motionY))")
                            }
                            
                            HStack {
                                Toggle("Enable X Motion (BETA)", isOn: $dotsViewModel.xMotionEnabled)
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
