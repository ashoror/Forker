import Foundation

public protocol ForkResultSecondOperationProtocol {
    associatedtype Success
    associatedtype Failure: Error
    associatedtype PreviousOperation: ForkResultFirstOperationProtocol
    
    typealias CurrentResult = Result<Success, Failure>
    
    var previousOperation: PreviousOperation { get }
    var result: Readonly<CurrentResult?>! { get }
}

public final class ForkResultSecondOperation<S, E, X>: AsyncOperation, ForkResultSecondOperationProtocol
where E: Error, X: ForkResultFirstOperationProtocol & Operation {
    
    public typealias Success = S
    public typealias Failure = E
    public typealias PreviousOperation = X
    
    public typealias PreviousResult = PreviousOperation.CurrentResult
    public typealias CurrentResultOperationBlock = (@escaping (CurrentResult) -> Void) -> Void
    
    // MARK: - Private variables
    
    public private(set) var result: Readonly<CurrentResult?>!
    private var _result: CurrentResult?
    
    // MARK: - External dependencies
    
    public let previousOperation: PreviousOperation
    private let operationQueue: OperationQueue
    private let operationBlock: CurrentResultOperationBlock
    
    // MARK: - Initiaizers
    
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

public extension ForkResultSecondOperation {
    
    /// Returns and start execution a result operation with arguments of the result of the previous `join`
    /// or the previous / pre-previous`fork` operations
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the result from previous and pre-previous operations,
    ///                      after completing the execution of your operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a fork result operation
    ///
    /// Note:
    ///    - If you failed to "join", all subsequent operations will be canceled and will not be called, except `onCompletion`
    ///    - Start execution a result operation only after the previous `join` and `fork` operations
    @discardableResult
    func join<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, NewFailure>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: operationQueue) { [unowned self] resolve in
            do {
                let (value1, value2) = try ReadonlyResultMapper.map(self.previousOperation.result, self.result)
                makeOperation(value1, value2) { result in
                    let newResult = Result { try result.get() }
                    resolve(newResult)
                }
            } catch {
                resolve(.failure(error))
            }
        }
        operation.addDependency(self)
        operation.addDependency(previousOperation)
        operationQueue.addOperation(operation)
        return operation
    }
    
    @discardableResult
    func join<NewSuccess>(
        _ type: NewSuccess.Type = NewSuccess.self,
        makeOperation: @escaping (
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, Error>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    /// Returns and start execution a result operation with argument of the value of the previous `join` operation
    ///
    /// - Parameters:
    ///     - type: type of success result
    ///     - makeOperation: function to create an operation and return the value from previous operation,
    ///                      you need to return the resulting value to the function
    /// - Returns: a fork result THIRD operation
    ///
    /// Note: Start execution a result operation only after the previous `join` operation
    @discardableResult
    func fork<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (
            PreviousOperation.PreviousOperation.Success,
            @escaping (Result<NewSuccess, NewFailure>) -> Void
        ) -> Void
    ) -> ForkResultThirdOperation<NewSuccess, Error, ForkResultSecondOperation> {
        let operation = ForkResultThirdOperation<NewSuccess, Error, ForkResultSecondOperation>(
            operationQueue: operationQueue,
            previousOperation: self,
            operationBlock: { [unowned self] resolve in
                do {
                    let value = try self.previousOperation.previousOperation.result.get()!.get()
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
        makeOperation: @escaping (
            PreviousOperation.PreviousOperation.Success,
            @escaping (Result<NewSuccess, Error>) -> Void
        ) -> Void
    ) -> ForkResultThirdOperation<NewSuccess, Error, ForkResultSecondOperation> {
        fork(type, Error.self, makeOperation: makeOperation)
    }
    
    func onCompletion(
         queue: OperationQueue = .main,
         completion: @escaping (PreviousResult, CurrentResult) -> Void
     ) {
         let operation = AsyncBlockOperation { [unowned self] completionAsyncBlock in
            if let result1 = self.previousOperation.result.get(), let result2 = self.result.get() {
                 completion(result1, result2)
             }
             completionAsyncBlock()
         }

         operation.addDependency(previousOperation)
         operation.addDependency(self)
         queue.addOperation(operation)
     }

}
