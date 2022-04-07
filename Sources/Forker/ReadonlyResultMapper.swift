import Foundation

struct ReadonlyResultMapper {
    
    typealias ReadonlyResult<T, U> = Readonly<Result<T, U>?> where U: Error
    
    static func map<Success, Failure>(_ result: ReadonlyResult<Success, Failure>) throws -> Result<Success, Failure> {
        if let result = result.get() {
            return result
        }
        
        throw AsyncResultOperationError.resultNotAssigned
    }
    
    static func map<Success1, Success2, Failure1, Failure2>(
        _ result1: ReadonlyResult<Success1, Failure1>,
        _ result2: ReadonlyResult<Success2, Failure2>
    ) throws -> (result1: Result<Success1, Failure1>, result2: Result<Success2, Failure2>) {
        if let result1 = result1.get(), let result2 = result2.get() {
            return (result1: result1, result2: result2)
        }
        
        throw AsyncResultOperationError.resultNotAssigned
    }
    
    static func map<Success1, Success2, Success3, Failure1, Failure2, Failure3>(
        _ result1: ReadonlyResult<Success1, Failure1>,
        _ result2: ReadonlyResult<Success2, Failure2>,
        _ result3: ReadonlyResult<Success3, Failure3>
    ) throws -> (
        result1: Result<Success1, Failure1>,
        result2: Result<Success2, Failure2>,
        result3: Result<Success3, Failure3>
    ) {
        if let result1 = result1.get(), let result2 = result2.get(), let result3 = result3.get() {
            return (result1: result1, result2: result2, result3: result3)
        }
        
        throw AsyncResultOperationError.resultNotAssigned
    }
    
    static func map<Success1, Success2, Success3, Success4, Failure1, Failure2, Failure3, Failure4>(
        _ result1: ReadonlyResult<Success1, Failure1>,
        _ result2: ReadonlyResult<Success2, Failure2>,
        _ result3: ReadonlyResult<Success3, Failure3>,
        _ result4: ReadonlyResult<Success4, Failure4>
    ) throws -> (
        result1: Result<Success1, Failure1>,
        result2: Result<Success2, Failure2>,
        result3: Result<Success3, Failure3>,
        result4: Result<Success4, Failure4>
    ) {
        if let result1 = result1.get(), let result2 = result2.get(), let result3 = result3.get(), let result4 = result4.get() {
            return (result1: result1, result2: result2, result3: result3, result4: result4)
        }
        
        throw AsyncResultOperationError.resultNotAssigned
    }
    
    static func map<Success1, Success2, Success3, Success4, Success5, Failure1, Failure2, Failure3, Failure4, Failure5>(
        _ result1: ReadonlyResult<Success1, Failure1>,
        _ result2: ReadonlyResult<Success2, Failure2>,
        _ result3: ReadonlyResult<Success3, Failure3>,
        _ result4: ReadonlyResult<Success4, Failure4>,
        _ result5: ReadonlyResult<Success5, Failure5>
    ) throws -> (
        result1: Result<Success1, Failure1>,
        result2: Result<Success2, Failure2>,
        result3: Result<Success3, Failure3>,
        result4: Result<Success4, Failure4>,
        result5: Result<Success5, Failure5>
    ) {
        if let result1 = result1.get(), let result2 = result2.get(),
           let result3 = result3.get(), let result4 = result4.get(),
           let result5 = result5.get() {
            return (result1: result1, result2: result2, result3: result3, result4: result4, result5: result5)
        }
        
        throw AsyncResultOperationError.resultNotAssigned
    }
    
}
