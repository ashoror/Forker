import Foundation

// swiftlint:disable force_unwrapping

public enum AsyncResultOperationError: Swift.Error {
    case resultNotAssigned
}

public protocol ResultOperationProtocol {
    associatedtype Success
    associatedtype Failure: Error
    
    typealias CurrentResult = Result<Success, Failure>
    
    var result: Readonly<CurrentResult?>! { get }
}

public class ResultOperation<S, E>: AsyncOperation, ResultOperationProtocol where E: Error {

    public typealias Success = S
    public typealias Failure = E
    
    public typealias CurrentResultOperationBlock = (@escaping (CurrentResult) -> Void) -> Void

    // MARK: - Private variables
    
    public private(set) var result: Readonly<CurrentResult?>!
    private var _result: CurrentResult?

    // MARK: - External dependencies
    
    public let operationQueue: OperationQueue
    private let operationBlock: CurrentResultOperationBlock

    // MARK: - Initializers
    
    public init(operationQueue: OperationQueue, operationBlock: @escaping CurrentResultOperationBlock) {
        self.operationQueue = operationQueue
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

public extension ResultOperation {

    /// Returns and start execution a result operation with argument of the value of the previous `join` or `fork` operations
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the value from previous operation,
    ///                      after completing the execution of your operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a result operation
    ///
    /// Note:
    ///    - If you failed to "join", all subsequent operations will be canceled and will not be called, except `onCompletion`
    ///    - Start execution a result operation only after the previous `join` and `fork` operations
    @discardableResult
    func join<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (Success, (@escaping (Result<NewSuccess, NewFailure>) -> Void)) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: self.operationQueue) { [unowned self] resolve in
            do {
                let value = try ReadonlyResultMapper.map(self.result).get()
                makeOperation(value) { result in
                    let newResult = Result { try result.get() }
                    resolve(newResult)
                }
            } catch {
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
        makeOperation: @escaping (Success, (@escaping (Result<NewSuccess, Error>) -> Void)) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    /// Returns and start execution a result operation with argument of the value of the previous `join` operations
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the value from previous operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a fork result operation
    ///
    /// Note: Start execution a result operation only after the previous `join` operations
    @discardableResult
    func fork<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (Success, @escaping (Result<NewSuccess, NewFailure>) -> Void) -> Void
    ) -> ForkResultFirstOperation<NewSuccess, Error, ResultOperation> {
        let operation = ForkResultFirstOperation<NewSuccess, Error, ResultOperation>(
            operationQueue: self.operationQueue,
            previousOperation: self,
            operationBlock: { [unowned self] resolve in
                do {
                    let value = try self.result.get()!.get()
                    makeOperation(value) { result in
                        let newResult = Result { try result.get() }
                        resolve(newResult)
                    }
                } catch {
                    resolve(.failure(error))
                }
            }
        )
        operation.addDependency(self)
        operationQueue.addOperation(operation)
        return operation
    }
    
    @discardableResult
    func fork<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (Success, @escaping (Result<NewSuccess, Error>) -> Void) -> Void
    ) -> ForkResultFirstOperation<NewSuccess, Error, ResultOperation> {
        fork(type, Error.self, makeOperation: makeOperation)
    }
    
    func onCompletion(
        queue: OperationQueue = .main,
        completion: @escaping (Result<Success, Failure>) -> Void
    ) {
        let operation = AsyncBlockOperation { [unowned self] completionAsyncBlock in
            if let result = self.result.get() {
                completion(result)
            }
            completionAsyncBlock()
        }
        
        operation.addDependency(self)
        queue.addOperation(operation)
    }

}

public extension OperationQueue {

    /// Returns and start execution a result operation
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation, after completing the execution of your operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a result operation
    @discardableResult
    func join<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (@escaping (Result<NewSuccess, NewFailure>) -> Void) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: self) { resolve in
            makeOperation { result in
                let newResult = Result { try result.get() }
                resolve(newResult)
            }
        }
        addOperation(operation)
        return operation
    }
    
    @discardableResult
    func join<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (@escaping (Result<NewSuccess, Error>) -> Void) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    /// Returns and start execution a fork result operation
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation, after completing the execution of your operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a fork result FIRST operation
    @discardableResult
    func fork<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (@escaping (Result<NewSuccess, NewFailure>) -> Void) -> Void
    ) -> ForkResultFirstOperation<NewSuccess, Error, ResultOperation<Void, Error>> {
        let fakeOperation = ResultOperation<Void, Error>(operationQueue: self) {resolve in
            resolve(.success(()))
        }
        let operation = ForkResultFirstOperation<NewSuccess, Error, ResultOperation<Void, Error>>(
            operationQueue: self,
            previousOperation: fakeOperation,
            operationBlock: { resolve in
                makeOperation { result in
                    let newResult = Result { try result.get() }
                    resolve(newResult)
                }
            }
        )
        operation.addDependency(fakeOperation)
        addOperation(fakeOperation)
        addOperation(operation)
        return operation
    }
    
    @discardableResult
    func fork<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (@escaping (Result<NewSuccess, Error>) -> Void) -> Void
    ) -> ForkResultFirstOperation<NewSuccess, Error, ResultOperation<Void, Error>> {
        fork(type, Error.self, makeOperation: makeOperation)
    }
    
}
