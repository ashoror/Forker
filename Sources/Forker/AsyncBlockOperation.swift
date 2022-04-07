import Foundation

/// Provides an ability to perform asynchronous operation using closure.
///
/// For example, you need to load data from network using Operation,
/// but there is no Operation subclass to do that. Therefore this class was created.
/// Using this class you can easily create and perform an asynchronous operation.
/// ```
/// let loadOperation = AsyncBlockOperation { completion in
///     Network.load(completion: {
///         completion()
///     })
/// }
/// ```
public final class AsyncBlockOperation: AsyncOperation {
    
    private let operation: (@escaping () -> Void) -> Void
    
    /// Initializes AsyncBlockOperation with the operation closure.
    ///
    /// - Parameter operation: The operation closure.
    public init(operation: @escaping (@escaping  () -> Void) -> Void) {
        self.operation = operation
    }
    
    public override func main() {
        guard !isCancelled else { return }
        
        state = .executing
        
        operation { [weak self] in
            self?.state = .finished
        }
    }
    
}
