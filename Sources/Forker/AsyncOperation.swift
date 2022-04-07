import Foundation

/// Provides an ability to perform an asynchronous operation.
///
/// For example, you need to load data from network using Operation,
/// but there is no Operation subclass to do that. Therefore this class was created.
/// Using this class you can make your own subclass and perform an asynchronous operation.
/// ```
/// class MyOperation: AsyncOperation {
///     public override func main() {
///         super.main()
///         guard !isCancelled else { return }
///         state = .executing
///         Network.load(completion: { [weak self] in
///             self?.state = .finished
///         })
///     }
/// }
/// ```
open class AsyncOperation: Operation {
    
    /// The state of an operation.
    ///
    /// - waiting: An operation is waiting for execution.
    /// - ready: An operation is ready for execution.
    /// - executing: An operation is executing.
    /// - finished: An operation is finished.
    /// - cancelled: An operation is cancelled.
    public enum State: String {
        case waiting = "isWaiting"
        case ready = "isReady"
        case executing = "isExecuting"
        case finished = "isFinished"
        case cancelled = "isCancelled"
    }
    
    /// The current operation state.
    open var state: State = .waiting {
        willSet {
            switch newValue {
            case .waiting:
                willChangeValue(forKey: State.waiting.rawValue)
            case .ready:
                willChangeValue(forKey: State.ready.rawValue)
            case .executing:
                willChangeValue(forKey: State.executing.rawValue)
            case .finished:
                willChangeValue(forKey: State.finished.rawValue)
            case .cancelled:
                willChangeValue(forKey: State.cancelled.rawValue)
            }
        }
        didSet {
            switch state {
            case .waiting:
                didChangeValue(forKey: State.waiting.rawValue)
            case .ready:
                didChangeValue(forKey: State.ready.rawValue)
            case .executing:
                didChangeValue(forKey: State.executing.rawValue)
            case .finished:
                didChangeValue(forKey: State.finished.rawValue)
            case .cancelled:
                wasTriedCancel = true
                didChangeValue(forKey: State.cancelled.rawValue)
            }
        }
    }

    /// There was an attempt to cancel the operation.
    /// Some operations are not explicitly canceled, but it is important to know that such an attempt was made
    public var wasTriedCancel = false
    
    open override var isReady: Bool {
        if self.state == .waiting {
            return super.isReady
        } else {
            return state == .ready
        }
    }
    
    open override var isExecuting: Bool {
        if self.state == .waiting {
            return super.isExecuting
        } else {
            return state == .executing
        }
    }
    
    open override var isFinished: Bool {
        if self.state == .waiting {
            return super.isFinished
        } else {
            return state == .finished
        }
    }
    
    open override var isCancelled: Bool {
        if self.state == .waiting {
            return super.isCancelled
        } else {
            return state == .cancelled
        }
    }
    
    open override var isAsynchronous: Bool {
        true
    }
    
    open override func cancel() {
        state = .cancelled
        super.cancel()
    }
    
}
