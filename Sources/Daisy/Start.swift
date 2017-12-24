//
//  Start.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - Starting Single Tasks

/// Immediately starts running `task` on `queue` with `input`, adding it
/// to `cancellationPool` (if one is specified).
///
/// - precondition: `task` must be pending (`isPending == true`).
///
/// - parameter task: The task to start running with `input` on `queue`.
/// - parameter input: The input to start `task` with.
/// - parameter queue: The queue to start running `task` on. Defaults to
/// the global background queue.
/// - parameter cancellationPool: The cancellation pool to add `task` to. Defaults
/// to `nil`.
///
/// - returns: A future representing the finished state of `task`.
@discardableResult
public func start<Input, Output>(running task: Task<Input, Output>,
                                 with input: Input,
                                 on queue: DispatchQueue = .global(qos: .background),
                                 using cancellationPool: CancellationPool? = nil) -> Future<Output> {
    
    task.setEnqueued()
    
    cancellationPool?.add(task)
    
    task.attemptStart(with: input, on: queue)
    
    return task.future
}

/// Immediately starts running `task` on `queue`, adding it to
/// `cancellationPool`.
///
/// - precondition: `task` must be pending (`isPending == true`).
///
/// - parameter task: The task (which takes no input) to start running
/// on `queue`.
/// - parameter queue: The queue to start running `task` on. Defaults to
/// the global background queue.
/// - parameter cancellationPool: The cancellation pool to add `task` to. Defaults
/// to `nil`.
///
/// - returns: A future representing the finished state of `task`.
@discardableResult
public func start<Output>(running task: Task<Void, Output>,
                          on queue: DispatchQueue = .global(qos: .background),
                          using cancellationPool: CancellationPool? = nil) -> Future<Output> {
    
    return start(running: task, with: (), on: queue, using: cancellationPool)
}

/// Immediately starts running `closure` asynchronosly on `queue`.
///
/// - note: `closure` will only be called once per call to this method.
///
/// - parameter queue: The queue to start running `task` on. Defaults to
/// the global background queue.
/// - parameter closure: The closure to start running on `queue`. If `closure`
/// encounters a problem that prevents it from continuing, it should `throw` a
/// suitable error.
///
/// - returns: A future representing the finished state of `closure`.
@discardableResult
public func start<Output>(on queue: DispatchQueue = .global(qos: .background),
                          executing closure: @escaping () throws -> Output) -> Future<Output> {
    
    let promise = Promise<Output>()
    
    queue.async {
        
        do {
            
            promise.fulfil(with: try closure())
        }
            
        catch {
            
            promise.reject(with: error)
        }
    }
    
    return promise.future
}

// MARK: - Starting a Group of Tasks

/// Immediately starts executing the group of tasks, **without** setting
/// them as enqueued.
///
/// - parameter tasks: The group of tasks to execute.
/// - parameter input: The shared input to start `tasks` with.
/// - parameter queue: The queue to execute the group of tasks on.
///
/// - note: If one task fails or is cancelled, the other tasks in the
/// group will be cancelled (with an indirect error for failures, and if
/// there is one for cancellations), and the returned futures's resolved
/// state will match that of the task that failed or was cancelled (the
/// returned future will either be rejected or cancelled). If multiple tasks
/// fail or are cancelled, the future will be resolved with whichever event
/// happened first.
///
/// - returns: A future that will either be resolved with the combined output
/// from `tasks`, rejected with the first failure error to occur in `tasks`, or
/// cancelled if any of the tasks in `tasks` are cancelled.
@discardableResult
func _execute<Input, Output>(group tasks: [Task<Input, Output>],
                             with input: Input,
                             on queue: DispatchQueue = .global(qos: .background)) -> Future<[Output]> {
    
    // we don't want the returned future to resolve until we're sure all the tasks
    // have been cancelled (if they need to be)
    // this promise is fulfilled when either the group future is fulfilled,
    // or after all the tasks have been cancelled (if the group future is rejected or cancelled)
    let promise = Promise<[Output]>()
    
    let groupFuture = Future.fulfillingWhen(tasks.map { $0.future })
    
    // if the future for all the tasks is cancelled or 
    // rejected (i.e. one of the tasks fails) cancel the others
    groupFuture.whenResolved(executeOn: queue) { (resolvedState) in
        
        switch resolvedState {
            
        case let .rejected(error):
            tasks.forEach { $0.cancel(withIndirectError: error, shouldPrintAlreadyFinishedWarning: false) }
            promise.reject(with: error)
            
        case let .cancelled(error):
            tasks.forEach { $0.cancel(withIndirectError: error, shouldPrintAlreadyFinishedWarning: false) }
            promise.cancel(withIndirectError: error)
            
            
        case let .fulfilled(result): promise.fulfil(with: result)
            
        }
    }
    
    tasks.forEach { $0.attemptStart(with: input, on: queue) }
    
    return promise.future
}

/// Immediately starts running `tasks` on `queue`, with `input` shared with each
/// task. Every task will be added to `cancellationPool`.
///
/// - note: Every task in `tasks` will be dispatched to `queue` at the same time.
/// If `queue` is configured to execute closures concurrently, `tasks` will be run
/// concurrently. Likewise, if `queue` is serial, `tasks` will be executeted one by
/// one in the supplied order.
///
/// If any tasks from `tasks` should fail, all other tasks will be cancelled with
/// an indirect error. Likewise, if any tasks from `tasks` are cancelled, all other tasks
/// in `tasks` will be cancelled (with an indirect error if there is one).
///
/// - warning: Note that `input` is shared between all the tasks in `tasks`.
/// If `input` is a reference type, take care to ensure that `tasks` do not mutate
/// it, as this could cause unintended side-effects.
/// If `tasks` must mutate their input, a solution would be to either use a
/// value-type for `input`, have each task copy their input, or pass a serial queue
/// as `queue` (although this would negate any performance benefits gained from
/// concurrency).
///
/// - parameter tasks: The tasks that will be dispatched to `queue` using `input`.
/// - parameter input: The input that will be used for all of the tasks in `tasks`.
/// - parameter queue: The queue to start running `task` on. Defaults to the global
/// background queue.
/// - parameter cancellationPool: The cancellation pool to add the contents of `tasks` to.
/// Defaults to `nil`. If a CancellationPool is specified, the contents of `tasks` will be
/// added to it as soon as this method is called.
///
/// - returns: A future that will either be resolved with the combined output
/// from `tasks`, rejected with the first failure error to occur in `tasks`, or
/// cancelled if any of the tasks in `tasks` are cancelled.
@discardableResult
public func start<Input, Output>(running tasks: [Task<Input, Output>],
                                 with input: Input,
                                 on queue: DispatchQueue = .global(qos: .background),
                                 using cancellationPool: CancellationPool? = nil) -> Future<[Output]> {
    
    tasks.forEach { $0.setEnqueued() }
    cancellationPool?.add(contentsOf: tasks)
    
    return _execute(group: tasks, with: input, on: queue)
}
