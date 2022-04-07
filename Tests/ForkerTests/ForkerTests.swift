import XCTest

@testable import Forker

import Foundation

final class ForkerTests: XCTestCase {
    
    enum TestForkerError: Error {
        case exampleError
    }

    func testDependencyQueueShouldWorkProperly() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let exp = expectation(description: "expectation1")

        // When
        operationQueue
            .join(String.self) { resolve in
                resolve(.success("Value 1"))
            }
            .join(Int.self) { value, resolve in
                XCTAssertEqual(value, "Value 1")
                resolve(.success(2))
            }
            .join(String.self) { value, resolve in
                XCTAssertEqual(value, 2)
                resolve(.success("Value 3"))
            }
            .onCompletion(queue: completionQueue) { result in
                switch result {
                case let .success(value):
                    XCTAssertEqual(value, "Value 3")
                case .failure:
                    XCTFail("Failure should not be called")
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 0.5)
    }

    func testDependencyQueueShouldNotWorkProperly() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let test_error = TestForkerError.exampleError
        let exp = expectation(description: "expectation1")

        // When
        operationQueue
            .join(String.self) { resolve in
                resolve(.failure(test_error))
            }
            .join(String.self) { value, resolve in
                XCTFail("This operation not be called")
            }
            .join(String.self) { value, resolve in
                XCTFail("This operation not be called")
            }
            .onCompletion(queue: completionQueue) { result in
                switch result {
                case .success:
                    XCTFail("Success should not be called")
                case let .failure(error):
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 0.5)
    }

    func testParallelQueueShouldWorkProperly1() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let exp = expectation(description: "expectation1")

        // When
        operationQueue
            .fork(Int.self) { resolve in
                resolve(.success(0))
            }
            .join(Int.self) { result, resolve in
                if case let .success(value) = result {
                    XCTAssertEqual(value, 0)
                }
                resolve(.success(1))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(2))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(3))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(4))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(5))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(6))
            }
            .join(Int.self) { result1, result2, result3, result4, result5, resolve in
                if case let .success(value) = result1 {
                    XCTAssertEqual(value, 2)
                }
                if case let .success(value) = result2 {
                    XCTAssertEqual(value, 3)
                }
                if case let .success(value) = result3 {
                    XCTAssertEqual(value, 4)
                }
                if case let .success(value) = result4 {
                    XCTAssertEqual(value, 5)
                }
                if case let .success(value) = result5 {
                    XCTAssertEqual(value, 6)
                }
                resolve(.success(4))
            }
            .join(Int.self) { value, resolve in
                XCTAssertEqual(value, 4)
                resolve(.success(5))
            }
            .onCompletion(queue: completionQueue) { result in
                switch result {
                case let .success(value):
                    XCTAssertEqual(value, 5)
                case let .failure(error):
                    XCTFail("Failure should not be called: \(error)")
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 0.5)
    }
    
    func testParallelQueueShouldNotWorkProperlyWithForkFailure1() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let exp = expectation(description: "expectation1")
        let test_error1 = TestForkerError.exampleError
        
        // When
        operationQueue
            .fork(Int.self) { resolve in
                resolve(.success(0))
            }
            .join(Int.self) { result, resolve in
                if case let .success(value) = result {
                    XCTAssertEqual(value, 0)
                }
                resolve(.success(1))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.failure(test_error1))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(3))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.failure(test_error1))
            }
            .onCompletion(queue: completionQueue) { result1, result2, result3 in
                switch result1 {
                case .success:
                    XCTFail("Success should not be called")
                case let .failure(error):
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                switch result2 {
                case let .success(value):
                    XCTAssertEqual(value, 3)
                case .failure:
                    XCTFail("Failure should not be called")
                }
                switch result3 {
                case .success:
                    XCTFail("Success should not be called")
                case let .failure(error):
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 0.5)
    }

    func testParallelQueueShouldNotWorkProperlyWithForkFailure2() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let test_error1 = TestForkerError.exampleError
        let exp = expectation(description: "expectation1")

        // When
        operationQueue
            .fork(Int.self) { resolve in
                resolve(.success(0))
            }
            .fork(Int.self) { _, resolve in
                resolve(.success(1))
            }
            .join(Int.self) { result1, result2, resolve in
                if case let .success(value) = result1 {
                    XCTAssertEqual(value, 0)
                }
                if case let .success(value) = result2 {
                    XCTAssertEqual(value, 1)
                }
                resolve(.success(1))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.failure(test_error1))
            }
            .fork(Int.self) { value, resolve in
                XCTAssertEqual(value, 1)
                resolve(.success(3))
            }
            .onCompletion(queue: completionQueue) { result1, result2 in
                if case let .failure(error) = result1 {
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                if case let .success(value) = result2 {
                    XCTAssertEqual(value, 3)
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 10)
    }

    func testParallelQueueShouldNotWorkProperlyWithJoinFailure() {
        // Given
        let operationQueue = OperationQueue()
        let completionQueue = OperationQueue()
        let test_error = TestForkerError.exampleError
        let exp = expectation(description: "expectation1")

        // When
        operationQueue
            .fork(Int.self) { resolve in
                resolve(.success(0))
            }
            .join(Int.self) { result, resolve in
                if case let .success(value) = result {
                    XCTAssertEqual(value, 0)
                }
                resolve(.failure(test_error))
            }
            .fork(Int.self) { value, resolve in
                XCTFail("Fork should not be called")
            }
            .fork(Int.self) { value, resolve in
                XCTFail("Fork should not be called")
            }
            .onCompletion(queue: completionQueue) { result1, result2 in
                if case let .failure(error) = result1 {
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                if case let .failure(error) = result2 {
                    XCTAssertEqual(error as! TestForkerError, .exampleError)
                }
                exp.fulfill()
            }

        // Then
        waitForExpectations(timeout: 0.5)
    }

}
