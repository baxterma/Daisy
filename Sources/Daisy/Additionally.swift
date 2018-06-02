//
//  additionally.swift
//  Daisy
//
//  Created by Alasdair Baxter on 09/02/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - Additional Tasks

public extension Future {
    
    /// Enqueues `task` to be started on `queue` if the receiver is fulfilled, using
    /// the receiver's result as the input for `task`. If `task` finishes successfully,
    /// its output is combined into a tuple with the receiver's original result.
    ///
    /// - note: If the receiver is rejected, `task` will be cancelled with an indirect
    /// error. If the receiver is cancelled (with or without an indirect error), `task`
    /// will be cancelled too (with the same indirect error if there is one). In both cases,
    /// `task` will **not** be started, however, it **will** be marked as enququed.
    ///
    /// - precondition: `task` must be pending (`task.isPending == true`).
    ///
    /// - parameter task: The task to be started after the receiver is fulfilled.
    /// - parameter queue: The queue to start `task` on if the receiver is fulfilled.
    /// Defaults to the global utility queue.
    /// - parameter cancellationPool: The cancellation pool to add `task` to. Defaults to
    /// `nil`. If a cancellation pool is specified, `task` will be added to it as soon as this
    /// method is called, irrespective of the resolved state of the receiver.
    ///
    /// - returns: A future representing the combined outputs of the receiver and `task`.
    /// If the receiver is rejected or cancelled, the returned future will match the receiver's
    /// resolved state. If the receiver is fulfilled, but `task` fails or is cancelled, the returned
    /// future will be rejected or cancelled respectively. If the receiver is fulfilled, and `task` finishes
    /// successfully, the returned future will be fulfilled with both results.
    @discardableResult
    public func additionally<Output>(_ task: Task<Result, Output>,
                                     on queue: DispatchQueue = .global(qos: .utility),
                                     using cancellationPool: CancellationPool? = nil) -> Future<(Result, Output)> {
        
        task.setEnqueued()
        cancellationPool?.add(task)
        
        let promise = Promise<(Result, Output)>()
        
        self.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled(let result):
                task.attemptStart(with: result, on: queue)
                task.future.whenFulfilled { promise.fulfil(with: (result, $0)) }
                task.future.whenRejected(promise.reject)
                task.future.whenCancelled(promise.cancel)
                
            case .rejected(let error):
                task.cancel(withIndirectError: error)
                promise.reject(with: error)
                
            case .cancelled(let indirectError):
                task.cancel(withIndirectError: indirectError)
                promise.cancel(withIndirectError: indirectError)
            }
        }
        
        return promise.future
    }
}

// MARK: - Additional Closures

public extension Future {
    
    /// Enqueues `closure` to be started on `queue` if the receiver is fulfilled, passing the receiver's
    /// result as the argument for the `input` parameter. If `closure` returns a result, that result is
    /// combined into a tuple with the receiver's original result.
    ///
    /// - note: If the receiver is rejected, the returned future will be cancelled with an indirect
    /// error. If the receiver is cancelled (with or without an indirect error), the returned future
    /// will be cancelled too (with the same indirect error if there is one). In both cases, `closure`
    /// will **not** be started.
    ///
    /// - parameter queue: The queue to start `closure` on if the receiver is fulfilled.
    /// Defaults to the main queue.
    /// - parameter closure: A closure that takes the result of the receiver (if there is one) as a
    /// parameter, and either returns some output, or throws an error.
    ///
    /// - returns: A future representing the combined results of the receiver and `closure`. If the
    /// receiver is rejected or cancelled, the returned future will match the receiver's resolved state.
    /// If the receiver is fulfilled, but `closure` throws an error, the returned future will be rejected with
    /// the error thrown by `closure`. If the receiver is fulfilled, and `closure` returns a result, the
    /// returned future will be fulfilled with both results.
    @discardableResult
    public func additionally<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (Result) throws -> Output) -> Future<(Result, Output)> {
        
        let promise = Promise<(Result, Output)>()
        
        self.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled(let result):
                do {
                    
                    promise.fulfil(with: (result, try closure(result)))
                    
                } catch {
                    
                    promise.reject(with: error)
                }
                
            case .rejected(let error):
                promise.reject(with: error)
                
            case .cancelled(let indirectError):
                promise.cancel(withIndirectError: indirectError)
            }
        }
        
        return promise.future
    }
    
    /// Enqueues `closure` to be started on `queue` if the receiver is fulfilled, passing the receiver's
    /// result as the argument for the `input` parameter. If the future returned by `closure` is fulfilled,
    /// its result is combined into a tuple with the receiver's original result.
    ///
    /// - note: If the receiver is rejected, the returned future will be cancelled with an indirect
    /// error. If the receiver is cancelled (with or without an indirect error), the returned future
    /// will be cancelled too (with the same indirect error if there is one). In both cases, `closure`
    /// will **not** be started.
    ///
    /// - parameter queue: The queue to start `closure` on if the receiver is fulfilled.
    /// Defaults to the main queue.
    /// - parameter closure: A closure that takes the result of the receiver (if there is one) as a
    /// parameter, and returns a future that will eventually be resolved by the closure or some
    /// other object.
    ///
    /// - returns: A future representing the combined results of the receiver and the future returned by
    /// `closure`. If the receiver is rejected or cancelled, the returned future will match the receiver's
    /// resolved state. If the receiver is fulfilled, but the future returned by `closure` is not, the returned
    /// future will match the state of the future returned by `closure`. If both the receiver and the future
    /// returned by `closure` are fulfilled, the returned future will be fulfilled with both results.
    @discardableResult
    public func additionally<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (Result) -> Future<Output>) -> Future<(Result, Output)> {
        
        let promise = Promise<(Result, Output)>()
        
        self.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled(let result):
                let future = closure(result)
                future.whenFulfilled { promise.fulfil(with: (result, $0)) }
                future.whenRejected(promise.reject)
                future.whenCancelled(promise.cancel)
                
            case .rejected(let error):
                promise.reject(with: error)
                
            case .cancelled(let indirectError):
                promise.cancel(withIndirectError: indirectError)
            }
        }
        
        return promise.future
    }
}
