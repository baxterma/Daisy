//
//  Task.swift
//  Daisy
//
//  Created by Alasdair Baxter on 09/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - TaskState

/// The states a task can be in.
private enum TaskState<Output> {
    
    case pending // the default state for a task after it has been initialised
    
    case enqueued // the task has been enqueued for execution.
    
    case executing // the task is executing
    
    // the following states are 'resolved' states (i.e. once the task is in one of these states, it cannot be changed)
    case completed(output: Output) // the task successfully completed with `output`
    case failed(error: Error) // the task failed with `error`
    case cancelled(indirectError: Error?) // the task was cancelled, optionally with `indirectError`
    
    var index: Int {
        
        switch self {
            
        case .pending: return 0
        case .enqueued: return 1
        case .executing: return 2
        case .completed(output: _), .failed(error: _), .cancelled(indirectError: _): return 3
            
        }
    }
}

// MARK: - Task

/// `Task` is an abstract class used to represent a single unit of asynchronous work.
/// `Task` includes all the logic and state coordination to ensure the safe execution
/// of your work, meaning that subclasses need only focus on implementing the work
/// they represent. `Task` also includes full support for allowing your work to take
/// input, and produce output. Combined with the chaining family of functions,
/// this allows multiple tasks to be chained safely together, to form a complex sequence
/// of actions, comprised of smaller, easy to maintain chunks.
///
/// `Task` instances are single-use, single-execution objects. In other words, a
/// task instance may be run only once. Attempting to run a task more than once will
/// either result in a warning being printed, or a trap (depending on the state of
/// task, and how you attempted to start it). Likewise, once a task has finished, it
/// cannot be finished again (e.g. completed with different output, or failed after
/// already completing). Once a task has finished, it's state cannot change.
///
/// To begin using `Task`, you need to subclass it. A good `Task` subclass should
/// define a clear unit of work, such as a network request. Depending on the work your
/// task is modelling, it may be useful to begin with smaller tasks, and then use them
/// to compose larger tasks. For example, you might build a task that fetches and
/// returns some model objects from a server. That task might be composed of two
/// smaller tasks: a network task, and a parsing task. All of that is to say, the
/// implementation of `Task` subclasses can range from small, multi-purpose subclasses,
/// to larger, composite, single-purpose, subclasses.
///
/// At the very least, your subclass needs to override the `start(with:)` method. Your
/// implementation should always begin with `guard preStart() else { return }`, this
/// ensures that the necessary bookkeeping is performed, and that your task is not
/// started more than once. The rest of your implementation of `start(with:)` should
/// use the input passed to it to carry out the work your subclass represents. When
/// your subclass completes its work, you should call `complete(with:)`, to signal
/// that your task has finished successfully. If an error occurred during execution,
/// your subclass should call `fail(with:)`, to signal that the task failed.
///
/// Tasks may be started in a number of ways. The most common, and recommended, is
/// to use either the `Daisy.start`, or chaining families of functions. Alternatively,
/// you can also call `start(with:)` on a task instance yourself. If you choose the
/// latter option, it is important to understand that by doing so, you are taking
/// ownership and responsibility of the task's execution. Furthermore, before calling
/// `start(with:)` yourself, it is highly recommended you call `setEnqueued()`, as
/// this formalises the aforementioned ownership of the task that you have taken.
/// Failure to do so can lead to undefined behaviour, and may break the 'single-run'
/// guarantee at the heart of `Task` subclasses. See `setEnqueued()` for more information
/// on what it means to set a task as enqueued, and take manual responsibility for it.
/// It is for these reasons that you are strongly encouraged to use the `Daisy.start`,
/// or chaining families of functions, as they both relieve you of this responsibility.
///
/// Regardless of how you choose to start a task, you may always ask it to cancel.
/// This can be done in one of two ways. The first is to call `cancel(with:)` on the
/// task itself. Like promises and futures, tasks can be cancelled with indirect errors,
/// see `FutureResolvedState.cancelled` for more information on indirect errors. The
/// second way to cancel a task is to add it to a cancellation pool, and drain the pool.
/// This has the advantage of not requiring you to maintain a reference to the task
/// solely for the purpose of being able to cancel it in the future. Similarly,
/// the `Daisy.start`, and chaining families of functions accept cancellation pools as
/// arguments, making them very easy to work with. The one limitation of using a
/// cancellation pool is that you cannot cancel a task with an indirect error.
///
/// To support cancellation in your task subclasses (it is recommended that you do),
/// you should regularly check the value of `isCancelled`. If `isCancelled` is ever
/// `true`, your task should stop executing immediately, without calling either
/// `complete(with:)`, or `fail(with:)` (or `cancel(with:)`, for that matter). If your
/// task triggers some other asynchronous work, you can override the `wasCancelled(with:)`
/// method, and ask said asynchronous work to stop.
open class Task<Input, Output> {
    
    fileprivate let internalQueue = DispatchQueue(label: "com.Daisy.TaskInternalQueue")
    
    private let promise = Promise<Output>()
    
    /// The future representing the execution of the receiver.
    public var future: Future<Output> { return promise.future }
    
    // not sync-ed as its private to task, and we're sure to sync all setting and getting
    fileprivate var state: TaskState<Output> = .pending {
        
        willSet(newState) {
            
            // a task cannot be set to the state it is already in
            guard newState.index != self.state.index else {
                
                preconditionFailure("Daisy: Once a task (\(Unmanaged.passUnretained(self).toOpaque())) has been made \(self.state), it cannot be made \(newState) again.")
            }
            
            // a task cannot move 'back' a state
            guard newState.index > self.state.index else {
                
                preconditionFailure("Daisy: Attempting to move a task's (\(Unmanaged.passUnretained(self).toOpaque())) state back from \(self.state) to \(newState).")
            }
        }
    }
    
    // MARK: - Init
    
    /// Initialises a new task.
    public init() {  }
    
    // MARK: - Enqueuing
    
    /// Sets the receiver as enqueued, preventing it from being enqueued elsewhere.
    ///
    /// - note: Once a task has been enqueued, it should only be started (or immediately finished, without being started)
    /// by the object that marked it as enqueued. **By enqueing a task, you take ownership of it.**
    ///
    /// - precondition: The receiver should be pending (`isPending == true`).
    public final func setEnqueued() {
        
        internalQueue.sync {
            
            guard case .pending = state else {
                
                preconditionFailure("Daisy: Attempting to enqueue a task (\(Unmanaged.passUnretained(self).toOpaque())) that is \(state). A task may only be used once.")
            }
            
            state = .enqueued
        }
    }
    
    // MARK: - Starting
    
    /// Used internally by the `start(running:)` and chaining families of functions.
    ///
    /// Dispatches a call to `queue` asynchronously, whithin which the function checks (synchronised on the receiver's internal queue)
    /// that the receiver is not finished or executing, and then invokes `start(with:)`. If the receiver is finished or executing
    /// at the time of check, this method does nothing.
    ///
    /// The time the check is carried out cannot be guarenteed, and nor can it be guarenteed that the receiver will be in the
    /// same state it was at the time of check, and then when `start(with:)` is called. The former is due to the asynchronous call on `queue`,
    /// as the time this call is executed is uncontrollable. The latter is due to the possibility that another method will jump
    /// in between the check on the receiver's state and the call to `start(with:)`.
    ///
    /// - parameter input: The input to start the receiver with.
    /// - parameter queue: The queue to asynchronously dispatch a call to `start(with:)` on.
    ///
    /// - note: Extending the latter warning above, it is technically possible for another thread to make a call to `start(with:)`
    /// before the call made by this method, but after the state checks are done (meaning both calls to `start(with:)` will go through, and
    /// the call made by this method would print a warning message). Given that it is the arrival order of the `start(with:)` calls that
    /// matter, this is still, technically, the expected behaviour. It is for this reason that the user is strongly advided to check for early
    /// exit conditions at the begining of their override of `start(with:)` with `preStart()`, as exiting early would prevent
    /// any unnecessary work (by the user) being done.
    final func attemptStart(with input: Input, on queue: DispatchQueue) {
        
        queue.async {
            
            let shouldStart = self.internalQueue.sync { () -> Bool in
                
                switch self.state {
                    
                // do nothing if executing or finished
                case .executing, .completed, .failed, .cancelled:
                    return false
                    
                case .pending, .enqueued: return true
                    
                }
            }
            
            // there is the possibility of another thread jumping in here and calling start
            // meaning the check above is ignored
            if shouldStart {
                
                self.start(with: input)
            }
        }
    }
    
    /// Performs the pre-start checks and bookkeeping needed before starting a task.
    /// This function **must** be called exactly once at the very begining of an override of `start(with:)` (see
    /// warning below for considerations when deeling with subclasses-of-subclasses of `Task`).
    ///
    /// - returns: A `Bool` indicating whether a task should actually start (`true` iff the receiver is either pending or
    /// enququed at the time of calling). It is strongly advised that any override of `start(with:)` begin
    /// with `guard preStart() else { return }`, combining bookkeeping and early exists into one call.
    /// You can ignore the result if you really want, but you **must** call `preStart()` at the begining of your override. Failure
    /// to do so will result in unexpected behaviour.
    ///
    /// - warning: Be careful when subclassing tasks that already inherit from `Task`. This function should only
    /// ever be called once for any call to `start(with:)` (including superclass implementations). Therefore, if you
    /// know that your superclass calls `preStart()` as part of its override of `start(with:)` either be sure to call
    /// its implementation of `start(with:)` and to *not* call `preStart()` yourself, **or** call `preStart()` yourself
    /// and *not* call your superclass's implementation of `start(with:)`. Be aware that doing the former will not privide you
    /// with a means of doing an early exit (checking `isPending` and `isEnqueued` doesn't count as the two separate calls like that
    /// are not thread-safe, or synchronised with the bookkeeping needed when starting).
    @discardableResult
    final public func preStart() -> Bool {
        
        return internalQueue.sync {
            
            switch self.state {
                
            case .executing, .completed, .failed, .cancelled:
                print("Daisy: Warning: `start(with:)` called on a task (\(Unmanaged.passUnretained(self).toOpaque())) that is \(self.state). A task should only be started when it is `pending` or `enqueued`.")
                return false
                
            case .pending, .enqueued:
                self.state = .executing
                return true
                
            }
        }
    }
    
    /// Starts the receiver.
    ///
    /// Overridden by subclasses to implement a task's work. Subclasses **must** invoke `preStart()`
    /// at the very begining of an override.
    ///
    ///  It is strongly advised that your override begin with
    ///
    ///      guard preStart() else { return }
    ///
    /// - note: If you call this method yourself, you are taking responsibility for checking the receiver's state before
    /// you actually call it. See below for details on the effects of calling this method when the receiver is
    /// either executing or finished. You should not combine `start(running:)` or chaining calls with manual calls to `start(with:)`.
    ///
    /// - warning: It is a programmer error to call this method if the receiver has been marked as enqueued by
    /// an object other than the caller, or if the receiver has already started or finished; tasks cannot be reused.
    /// Calling `start(with:)` on a task that is in either of the aforementioned states will cause its work to be
    /// run again, but no new output will be stored (even if it is different). Likewise, the receiver will **not** return
    /// `true` to `isExecuting` if `start(with:)` is called after it has finished. It is for this reason the early exit pattern
    /// involving `preStart()` is highly recommended. See `preStart()` for more information.
    ///
    /// - parameter input: The input to start the task with.
    open func start(with input: Input) {
        
    }
    
    // MARK: - Finishing
    
    /// Completes the receiver with `output`.
    ///
    /// - warning: If a task has been started, this method should only ever be called by the task itself.
    /// - note: If the receiver is already finished, other than printing a warning, this method has no effect.
    /// - parameter output: The task's output.
    final public func complete(with output: Output) {
        
        complete(with: output, shouldPrintAlreadyFinishedWarning: true)
    }
    
    /// Internal implementation of `complete(with:)`.
    func complete(with output: Output, shouldPrintAlreadyFinishedWarning: Bool) {
        
        internalQueue.async {
            
            switch self.state {
                
            case .completed, .failed, .cancelled:
                if shouldPrintAlreadyFinishedWarning {
                    
                    print("Daisy: Warning: Attempting to complete a task (\(Unmanaged.passUnretained(self).toOpaque())) that is already \(self.state). The task will not be changed.")
                }
                
            case .pending, .enqueued, .executing:
                self.state = .completed(output: output)
                self.promise.fulfil(with: output)
            }
        }
    }
    
    /// Fails the receiver with `error`.
    ///
    /// - warning: If a task has been started, this method should only ever be called by the task itself.
    /// - note: If receiver is already finished, other than printing a warning, this method has no effect.
    /// - parameter error: The error that caused the task to fail.
    final public func fail(with error: Error) {
        
        fail(with: error, shouldPrintAlreadyFinishedWarning: true)
    }
    
    /// Internal implementation of `fail(with:)`.
    final func fail(with error: Error, shouldPrintAlreadyFinishedWarning: Bool) {
        
        internalQueue.async {
            
            switch self.state {
                
            case .completed, .failed, .cancelled:
                if shouldPrintAlreadyFinishedWarning {
                    
                    print("Daisy: Warning: Attempting to fail a task (\(Unmanaged.passUnretained(self).toOpaque())) that is already \(self.state). The task will not be changed")
                }
                
            case .pending, .enqueued, .executing:
                self.state = .failed(error: error)
                self.promise.reject(with: error)
            }
        }
    }
    
    /// Cancels the receiver, optionally with an indirect error.
    ///
    /// - note: Calling this method does not force a task to stop, rather is updates the task's internal state, marking it for cancellation.
    /// It is up to subclasses to monitor the `isCancelled` property, and stop if it is `true`. Alternatively, subclasses can override the
    /// `wasCancelled` method (which is called when a task is cancelled), and stop any work.
    ///
    /// - parameter indirectError: The indirect error that caused the task to be cancelled. An indirect error is one that
    /// was not encountered by the task itself, but instead occured elsewhere, and caused the receiver to be cancelled.
    /// - note: If receiver is already finished, other than printing a warning, this method has no effect.
    final public func cancel(withIndirectError indirectError: Error? = nil) {
        
        cancel(withIndirectError: indirectError, shouldPrintAlreadyFinishedWarning: true)
    }
    
    /// Internal implementation of `cancel(withIndirectError:)`.
    func cancel(withIndirectError indirectError: Error? = nil, shouldPrintAlreadyFinishedWarning: Bool) {
        
        internalQueue.async {
            
            switch self.state {
                
            case .completed, .failed, .cancelled:
                if shouldPrintAlreadyFinishedWarning {
                    print("Daisy: Warning: Attempting to cancel a task (\(Unmanaged.passUnretained(self).toOpaque())) that is already \(self.state). The task will not be changed")
                }
                
            case .pending, .enqueued, .executing:
                self.state = .cancelled(indirectError: indirectError)
                self.promise.cancel(withIndirectError: indirectError)
                
                self.wasCancelled(with: indirectError)
            }
        }
    }
    
    /// Subclasses should override this method as a means of being notified when a task has been cancelled, stopping any work.
    ///
    /// - note: There is no need to invoke `super`'s implementation at any point.
    /// No guarentees are made as to which queue this method will be called on.
    /// - parameter indirectError: The indirect error that caused the task to be cancelled. See `cancel(with:)` for more information
    /// on what is meant by 'indirect errors'.
    open func wasCancelled(with indirectError: Error?) {
        
    }
}

// MARK: - Convenience Getters

/// Conveinience (Synchronised) Properties for Checking a task's State
public extension Task {
    
    /// Returns `true` if the receiver is pending, otherwise returns `false`.
    public final var isPending: Bool {
        
        return internalQueue.sync {
            
            if case .pending = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver has been enqueued, otherwise returns `false`.
    ///
    /// If the receiver has been enqueued, it should only be started by the object that enqueued it.
    ///
    /// - seeAlso: `setEnqueued()`
    public final var isEnqueued: Bool {
        
        return internalQueue.sync {
            
            if case .enqueued = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver is executing, otherwise returns `false`.
    ///
    /// A task should not be started if it is already executing.
    public final var isExecuting: Bool {
        
        return internalQueue.sync {
            
            if case .executing = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver is completed, otherwise returns `false`.
    ///
    /// A task should not be started, failed, cancelled, or completed if it is already completed.
    public final var isCompleted: Bool {
        
        return internalQueue.sync {
            
            if case .completed = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver has failed, otherwise returns `false`.
    ///
    /// A task should not be started, failed, cancelled, or completed if it has already failed.
    public final var isFailed: Bool {
        
        return internalQueue.sync {
            
            if case .failed = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver has been cancelled, otherwise returns `false`.
    ///
    /// A task should not be started, failed, cancelled, or completed if it has already been cancelled.
    public final var isCancelled: Bool {
        
        return internalQueue.sync {
            
            if case .cancelled = state { return true }
            else { return false }
        }
    }
    
    /// Returns `true` if the receiver is either completed, failed, or cancelled, otherwise returns `false`.
    ///
    /// A task should not be started, failed, cancelled, or completed if it is already finished.
    public final var isFinished: Bool {
        
        return internalQueue.sync {
            
            switch state {
                
            case .completed, .failed, .cancelled: return true
            case .pending, .enqueued, .executing: return false
                
            }
        }
    }
    
    /// Returns a string concisely describing the receiver's current state; useful for debugging.
    public final var stateDescription: String {
        
        return internalQueue.sync { String(describing: state) }
    }
}
