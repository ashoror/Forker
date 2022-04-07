# Forker

## A lightweight solution to work with multihreading.

## Forker allows synchronizing multiple concurrent and/or serial operations.

### How does it work?
```swift
// Forker works with OperationQueue, then first of all
// we need to create an OperationQueue object

let operationQueue = OperationQueue()

// To create a concurrent operation, use the function `fork`
// The first argument is result type, also an optional argument,
// the compiler can recognize the type itself,
// but if it does not succeed (this happens),
// then it is necessary to specify this type

operationQueue.fork(Bool.self) { resolve in
    // Resolve is the final function,
    // the result of the performed operation must be passed to it

    resolve(.success(true))
}

// To create another concurrent operation we need to continue `fork`

operationQueue
    .fork(Bool.self) { resolve in
        ...
    }
    .fork(String.self) { _, resolve in
        ...
    }

// To synchronize previous operations 
// we can use the `join` or `onCompletion` functions

operationQueue
    .fork(Bool.self) { resolve in
        ...
    }
    .fork(String.self) { _, resolve in
        ...
    }
    .join(String.self) { firstResult, secondResult, resolve in
        // `firstResult` and `secondResult` is the results of previous operations
        // as Result type

        // The difference between `join` and `onCompletion`
        // is that `join` does not complete the queue execution

        resolve("Hello, World!")
    }
    .onCompletion { joinResult in
        // `onCompletion` completes queue execution
    }
```

Note: If you failed to `join`, all subsequent operations will be canceled and will not be called, except `onCompletion`

### Summary: 

There are only three key functions:

1. `fork` - builds a chain of concurrent operations
2. `join` - builds a chain of serial operations, can also synchronize previous operations
3. `onCompletion` - synchronizes previous operations and completes queue execution

Best practice:

`OrderBuyReceivingDataWorker.swift, CryptoHistoryService.swift`

Constraints:

1. Maximum number of concurrent operations in a row: 5
2. Maximum number of serial operations in a row: 5
