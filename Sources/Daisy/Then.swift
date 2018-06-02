//
//  Then.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - Chaining Tasks

public extension Future {
    
    /// Enqueues `task` to be started on `queue` if the receiver is fulfilled, using
    /// the receiver's result as the input for `task`.   
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
    /// `nil`. If a CancellationPool is specified, `task` will be added to it as soon as this
    /// method is called, irrespective of the resolved state of the receiver.
    ///
    /// - returns: A future representing the finished state of `task`. If the receiver is fulfilled
    /// and `task` started, the returned future will have a resolved state matching the finished
    /// state of `task` (fulfilled if `task` finished successfully, rejected if `task` failed, 
    /// or cancelled if `task` was cancelled).
    /// See the note above for the rules on how the returned future may be resolved if the receiver
    /// is not fulfilled.
    @discardableResult
    public func then<Output>(_ task: Task<Result, Output>,
                             on queue: DispatchQueue = .global(qos: .utility),
                             using cancellationPool: CancellationPool? = nil) -> Future<Output> {
        
        task.setEnqueued()
        cancellationPool?.add(task)
        
        self.whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let output):
                task.attemptStart(with: output, on: queue)
                
            case .rejected(error: let error):
                task.cancel(withIndirectError: error)
                
            case .cancelled(indirectError: let indirectError):
                task.cancel(withIndirectError: indirectError)
            }
        }
        
        return task.future
    }
}

// MARK: - Chaining Closures

public extension Future {
    
    /// Enqueues `closure` to be started on `queue` if the receiver is fulfilled, passing the receiver's
    /// result as the argument for the `input` parameter.
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
    /// - returns: A future either resolved based on the return value or thrown error of `closure`,
    /// or cancelled with an indirect error due to the receiver either being cancelled or rejected.
    @discardableResult
    public func then<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (_ input: Result) throws -> Output) -> Future<Output> {
        
        let promise = Promise<Output>()
        
        self.whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let output):
                queue.async {
                    
                    do {
                        
                        promise.fulfil(with: try closure(output))
                    }
                        
                    catch {
                        
                        promise.reject(with: error)
                    }
                }
                
            case .rejected(error: let error):
                promise.cancel(withIndirectError: error)
                
            case .cancelled(indirectError: let indirectError):
                promise.cancel(withIndirectError: indirectError)
            }
        }
        
        return promise.future
    }
    
    /// Enqueues `closure` to be started on `queue` if the receiver is fulfilled, passing the receiver's
    /// result as the argument for the `input` parameter.
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
    /// - returns: A future either resolved to match the resolved state of the future returned
    /// by `closure`, or cancelled with an indirect error due to the receiver either being cancelled 
    /// or rejected.
    @discardableResult
    public func then<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (_ input: Result) -> Future<Output>) -> Future<Output> {
        
        let promise = Promise<Output>()
        
        self.whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let output):
                queue.async {
                    
                    let future = closure(output)
                    
                    // when the future returned from the closure enters a resolved state, 
                    // resolve the promise we create (and the future we return)
                    future.whenResolved(executeOn: queue, { (resolvedState) in
                        
                        switch resolvedState {
                            
                        case .fulfilled(result: let output):
                            promise.fulfil(with: output)
                        case .rejected(error: let error):
                            promise.reject(with: error)
                        case .cancelled(indirectError: let indirectError):
                            promise.cancel(withIndirectError: indirectError)
                        }
                    })
                }
                
            case .rejected(error: let error):
                promise.cancel(withIndirectError: error)
                
            case .cancelled(indirectError: let error):
                promise.cancel(withIndirectError: error)
            }
        }
        
        return promise.future
    }
}

// MARK: - Chaining Task Groups

public extension Future {
    
    /// Enqueues the group of tasks in `tasks` to be run concurrently if the receiver is
    /// fulfilled, using the receiver's result as the input for each task. The output of
    /// each task is then merged into a single Array, and used to fulfill the returned 
    /// future.
    ///
    /// Note that this method does not make any copies of the receiver's result, therefore, 
    /// if the receiver's result type is a mutable reference type, each task should make
    /// its own copy if it is mutating its input.
    ///
    /// - precondition: The tasks in `tasks` must be pending (`task.isPending == true`).
    ///
    /// - note: If the receiver is rejected, the entire contents of `tasks` will be cancelled
    /// with an indirect error. If the receiver is cancelled (with or without an indirect error),
    /// the entire contents of `tasks` will be cancelled too (with the same indirect error if 
    /// there is one). In both cases, **no** tasks will be started, however, they **will** be 
    /// marked as enququed.
    ///
    /// Furthermore, if any tasks from `tasks` should fail, all other tasks will be cancelled with
    /// an indirect error. Likewise, if any tasks from `tasks` are cancelled, all other tasks
    /// in `tasks` will be cancelled (with an indirect error if there is one).
    ///
    /// - parameter tasks: The tasks to be started concurrently after the receiver is fulfilled.
    /// - parameter queue: The queue to start `tasks` on if the receiver is fulfilled.
    /// Defaults to the global utility queue.
    /// - parameter cancellationPool: The cancellation pool to add the contents of`tasks` to. 
    /// Defaults to `nil`. If a CancellationPool is specified, the contents of `tasks` will be 
    /// added to it as soon as this method is called, irrespective of the resolved state of the receiver.
    ///
    /// - returns: A future which, if fulfilled, will be so with an Array containing the output from
    /// each task in `tasks`. If one task from `tasks` fails or is cancelled, the returned future will
    /// be resolved to match the state of the failed or cancelled task. If the receiver is rejected,
    /// the returned future will be cancelled with an indirect error. If the receiver is cancelled
    /// (with or without an indirect error), the returned future will be cancelled too (with the same 
    /// indirect error if there is one). In both cases, **no** tasks from `tasks` will be started.
    @discardableResult
    public func then<Output>(_ tasks: [Task<Result, Output>],
                             on queue: DispatchQueue = .global(qos: .utility),
                             using cancellationPool: CancellationPool? = nil) -> Future<[Output]> {
        
        tasks.forEach { $0.setEnqueued() }
        cancellationPool?.add(contentsOf: tasks)
        
        let promise = Promise<[Output]>()
        
        self.whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let output):
                let groupFuture = _execute(group: tasks, with: output, on: queue)
                groupFuture.whenFulfilled(promise.fulfil)
                groupFuture.whenRejected(promise.reject)
                groupFuture.whenCancelled(promise.cancel)
                
            case .rejected(error: let error):
                tasks.forEach { $0.cancel(withIndirectError: error) }
                promise.cancel(withIndirectError: error)
                
            case .cancelled(indirectError: let indirectError):
                tasks.forEach { $0.cancel(withIndirectError: indirectError) }
                promise.cancel(withIndirectError: indirectError)
            }
        }
        
        return promise.future
    }
}
