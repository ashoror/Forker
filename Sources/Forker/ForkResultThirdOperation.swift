import Foundation

public protocol ForkResultThirdOperationProtocol {
    associatedtype Success
    associatedtype Failure: Error
    associatedtype PreviousOperation: ForkResultSecondOperationProtocol
    
    typealias CurrentResult = Result<Success, Failure>
    
    var previousOperation: PreviousOperation { get }
    var result: Readonly<CurrentResult?>! { get }
}

public final class ForkResultThirdOperation<S, E, X>: AsyncOperation, ForkResultThirdOperationProtocol
where E: Error, X: ForkResultSecondOperationProtocol & Operation {

    public typealias Success = S
    public typealias Failure = E
    public typealias PreviousOperation = X
    
    public typealias PreviousResult = PreviousOperation.CurrentResult
    public typealias PreviousPreviousResult = PreviousOperation.PreviousOperation.CurrentResult
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

public extension ForkResultThirdOperation {
    
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
            PreviousPreviousResult,
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, NewFailure>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: operationQueue) { [unowned self] resolve in
            do {
                let (value1, value2, value3) = try ReadonlyResultMapper.map(
                    self.previousOperation.previousOperation.result,
                    self.previousOperation.result,
                    self.result
                )
                makeOperation(value1, value2, value3) { result in
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
            PreviousPreviousResult,
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, Error>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    @discardableResult
    func fork<NewSuccess, NewFailure: Error>(
        _ type: NewSuccess.Type = NewSuccess.self,
        _ failureType: NewFailure.Type = NewFailure.self,
        makeOperation: @escaping (
            PreviousOperation.PreviousOperation.PreviousOperation.Success,
            @escaping (Result<NewSuccess, NewFailure>) -> Void
        ) -> Void
    ) -> ForkResultFourthOperation<NewSuccess, Error, ForkResultThirdOperation> {
        let operation = ForkResultFourthOperation<NewSuccess, Error, ForkResultThirdOperation>(
            operationQueue: operationQueue,
            previousOperation: self,
            operationBlock: { [unowned self] resolve in
                do {
                    let value = try self.previousOperation.previousOperation.previousOperation.result.get()!.get()
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
            PreviousOperation.PreviousOperation.PreviousOperation.Success,
            @escaping (Result<NewSuccess, Error>) -> Void
        ) -> Void
    ) -> ForkResultFourthOperation<NewSuccess, Error, ForkResultThirdOperation> {
        fork(type, Error.self, makeOperation: makeOperation)
    }
    
    func onCompletion(
         queue: OperationQueue = .main,
         completion: @escaping (PreviousPreviousResult, PreviousResult, CurrentResult) -> Void
     ) {
         let operation = AsyncBlockOperation { [unowned self] completionAsyncBlock in
            if let result1 = self.previousOperation.previousOperation.result.get(),
               let result2 = self.previousOperation.result.get(),
               let result3 = self.result.get() {
                 completion(result1, result2, result3)
             }
             completionAsyncBlock()
         }

         operation.addDependency(previousOperation)
         operation.addDependency(self)
         queue.addOperation(operation)
     }

}
