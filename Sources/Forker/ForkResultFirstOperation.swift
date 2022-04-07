import Foundation

public protocol ForkResultFirstOperationProtocol {
    associatedtype Success
    associatedtype Failure: Error
    associatedtype PreviousOperation: ResultOperationProtocol
    
    typealias CurrentResult = Result<Success, Failure>
    
    var previousOperation: PreviousOperation { get }
    var result: Readonly<CurrentResult?>! { get }
}

public final class ForkResultFirstOperation<S, E, X>: AsyncOperation, ForkResultFirstOperationProtocol
where E: Error, X: ResultOperationProtocol & Operation {

    public typealias Success = S
    public typealias Failure = E
    public typealias PreviousOperation = X
    
    public typealias PreviousResult = PreviousOperation.CurrentResult
    public typealias CurrentResultOperationBlock = (@escaping (CurrentResult) -> Void) -> Void
    
    // MARK: - Private variables
    
    public private(set) var result: Readonly<CurrentResult?>!
    private var _result: CurrentResult?
    
    // MARK: - External dependency
    
    public let previousOperation: PreviousOperation
    private let operationQueue: OperationQueue
    private let operationBlock: CurrentResultOperationBlock
    
    // MARK: - Initializers
    
    public init(
        operationQueue: OperationQueue,
        previousOperation: PreviousOperation,
        operationBlock: @escaping CurrentResultOperationBlock
    ) {
        self.operationQueue = operationQueue
        self.previousOperation = previousOperation
        self.operationBlock = operationBlock
        super.init()
        
        result = Readonly { [weak self] in self?._result }
    }
    
    // MARK: - Override functions
    
    public override func main() {
        guard !isCancelled else { return }
        
        state = .executing
        
        operationBlock { [weak self] result in
            self?._result = result
            self?.state = .finished
        }
    }
    
}

public extension ForkResultFirstOperation {
    
    /// Returns and start execution a result operation with argument of the result of the previous `join` or `fork` operations
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the result from previous operation,
    ///                      after completing the execution of your operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a result operation
    ///
    /// Note:
    ///    - If you failed to "join", all subsequent operations will be canceled and will not be called, except `onCompletion`
    ///    - Start execution a result operation only after the previous `join` and `fork` operations
    @discardableResult
    func join<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (CurrentResult, (@escaping (Result<NewSuccess, NewFailure>) -> Void)) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: operationQueue) { [unowned self] resolve in
            do {
                let value = try ReadonlyResultMapper.map(self.result)
                makeOperation(value) { result in
                    let newResult = Result { try result.get() }
                    resolve(newResult)
                }
            } catch {
                self.operationQueue.cancelAllOperations()
                resolve(.failure(error))
            }
        }
        operation.addDependency(self)
        operationQueue.addOperation(operation)
        return operation
    }
    
    @discardableResult
    func join<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (CurrentResult, (@escaping (Result<NewSuccess, Error>) -> Void)) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    /// Returns and start execution a result operation with argument of the value of the previous `join` operation
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the value from previous operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a fork result SECOND operation
    ///
    /// Note: Start execution a result operation only after the previous `join` operation
    @discardableResult
    func fork<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (PreviousOperation.Success, @escaping (Result<NewSuccess, NewFailure>) -> Void) -> Void
    ) -> ForkResultSecondOperation<NewSuccess, Error, ForkResultFirstOperation> {
        let operation = ForkResultSecondOperation<NewSuccess, Error, ForkResultFirstOperation>(
            operationQueue: operationQueue,
            previousOperation: self,
            operationBlock: { [unowned self] resolve in
                do {
                    let value = try self.previousOperation.result.get()!.get()
                    makeOperation(value) { result in
                        let newResult = Result { try result.get() }
                        resolve(newResult)
                    }
                } catch {
                    resolve(.failure(error))
                }
            }
        )
        operation.addDependency(previousOperation)
        operationQueue.addOperation(operation)
        return operation
    }
    
    @discardableResult
    func fork<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (PreviousOperation.Success, @escaping (Result<NewSuccess, Error>) -> Void) -> Void
    ) -> ForkResultSecondOperation<NewSuccess, Error, ForkResultFirstOperation> {
        fork(type, Error.self, makeOperation: makeOperation)
    }

    func onCompletion(
        queue: OperationQueue = .main,
        completion: @escaping (CurrentResult) -> Void
    ) {
        let operation = AsyncBlockOperation { [weak self] completionAsyncBlock in
            if let result = self?.result.get() {
                completion(result)
            }
            completionAsyncBlock()
        }
        
        operation.addDependency(self)
        queue.addOperation(operation)
    }
    
}
