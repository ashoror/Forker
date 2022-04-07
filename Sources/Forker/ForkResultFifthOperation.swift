import Foundation

public protocol ForkResultFifthOperationProtocol {
    associatedtype Success
    associatedtype Failure: Error
    associatedtype PreviousOperation: ForkResultFourthOperationProtocol
    
    typealias CurrentResult = Result<Success, Failure>
    
    var previousOperation: PreviousOperation { get }
    var result: Readonly<CurrentResult?>! { get }
}

public final class ForkResultFifthOperation<S, E, X>: AsyncOperation, ForkResultFifthOperationProtocol
where E: Error, X: ForkResultFourthOperationProtocol & Operation {

    public typealias Success = S
    public typealias Failure = E
    public typealias PreviousOperation = X
    
    public typealias PreviousResult = PreviousOperation.CurrentResult
    public typealias PreviousPreviousResult = PreviousOperation.PreviousOperation.CurrentResult
    public typealias PreviousPreviousPreviousResult = PreviousOperation.PreviousOperation.PreviousOperation.CurrentResult
    public typealias PreviousPreviousPreviousPreviousResult = PreviousOperation.PreviousOperation.PreviousOperation.PreviousOperation.CurrentResult
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

public extension ForkResultFifthOperation {
    
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
            PreviousPreviousPreviousPreviousResult,
            PreviousPreviousPreviousResult,
            PreviousPreviousResult,
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, NewFailure>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        let operation = ResultOperation<NewSuccess, Error>(operationQueue: operationQueue) { [unowned self] resolve in
            do {
                let (value1, value2, value3, value4, value5) = try ReadonlyResultMapper.map(
                    self.previousOperation.previousOperation.previousOperation.previousOperation.result,
                    self.previousOperation.previousOperation.previousOperation.result,
                    self.previousOperation.previousOperation.result,
                    self.previousOperation.result,
                    self.result
                )
                makeOperation(value1, value2, value3, value4, value5) { result in
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
            PreviousPreviousPreviousPreviousResult,
            PreviousPreviousPreviousResult,
            PreviousPreviousResult,
            PreviousResult,
            CurrentResult,
            (@escaping (Result<NewSuccess, Error>) -> Void)
        ) -> Void
    ) -> ResultOperation<NewSuccess, Error> {
        join(type, Error.self, makeOperation: makeOperation)
    }
    
    func onCompletion(
         queue: OperationQueue = .main,
         completion: @escaping (PreviousPreviousPreviousPreviousResult, PreviousPreviousPreviousResult, PreviousPreviousResult, PreviousResult, CurrentResult) -> Void
     ) {
         let operation = AsyncBlockOperation { [unowned self] completionAsyncBlock in
             if
                let result1 = self.previousOperation
                    .previousOperation.previousOperation
                    .previousOperation.result.get(),
                let result2 = self.previousOperation.previousOperation.previousOperation.result.get(),
                let result3 = self.previousOperation.previousOperation.result.get(),
                let result4 = self.previousOperation.result.get(),
                let result5 = self.result.get() {
                 completion(result1, result2, result3, result4, result5)
             }
             completionAsyncBlock()
         }

         operation.addDependency(previousOperation)
         operation.addDependency(self)
         queue.addOperation(operation)
     }

}
