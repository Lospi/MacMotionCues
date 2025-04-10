import Combine
import CoreMotion

@Observable
class MotionViewModel {
    var isMotionEnabled: Bool = false
    var motionX: Double = 0.0
    var motionY: Double = 0.0
    
    var motionSensitivity: Double = 1.0
    
    static let shared = MotionViewModel()
    
    private var motion = CMHeadphoneMotionManager()
    private var motionQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        motionQueue.name = "MotionQueue"
        motionQueue.qualityOfService = .userInteractive
    }
    
    func startDeviceMotion() async throws {
        guard !isMotionEnabled else { return }
        
        if motion.isDeviceMotionAvailable {
            motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
                guard let self = self, let motion = motion else {
                    if let error = error {
                        print("Motion error: \(error.localizedDescription)")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isMotionEnabled = true
                    self.motionX = motion.userAcceleration.x
                    self.motionY = motion.userAcceleration.y
                }
            }
        } else {
            print("Device motion is not available")
        }
    }
    
    func stopDeviceMotion() {
        motion.stopDeviceMotionUpdates()
        isMotionEnabled = false
    }
    
    deinit {
        stopDeviceMotion()
        cancellables.forEach { $0.cancel() }
    }
}
