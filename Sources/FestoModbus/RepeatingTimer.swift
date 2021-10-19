/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
import Foundation

class RepeatingTimer {

    let timeInterval: TimeInterval
    let timerQueue: DispatchQueue?
    var eventHandler: (() -> Void)?

    private var isSuspended = true

    init(timeInterval: TimeInterval, queue: DispatchQueue? = nil) {
        self.timeInterval = timeInterval
        self.timerQueue = queue
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        timer.resume()
    }

    func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        timer.suspend()
    }
}
