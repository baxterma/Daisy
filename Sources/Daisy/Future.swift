//
//  Future.swift
//  Daisy
//
//  Created by Alasdair Baxter on 28/12/2016.
//  Copyright © 2016 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - FutureState and FutureResolvedState

/// The 'top-level' states a future can be in.
private enum FutureState<Result> {
    
    case unresolved
    case resolved(resolvedState: FutureResolvedState<Result>)
}

// This 'sub-state' exists as an implementation detail, to avoid
// publicly exposing .unresolved above. This saves users having to have an
// .unresolved case in any switch statements on a future's state, knowing it is actually resolved.
//
/// The resolved states of a future.
public enum FutureResolvedState<Result> {
    
    /// The future was fulfilled with a `result` of type `Result`.
    case fulfilled(result: Result)
    
    /// The future was rejected with an `error`.
    case rejected(error: Error)
    
    /// The future was cancelled, possibly due to an indirect error (`indirectError`).
    ///
    /// An "indirect" error is one that occurred in an unrelated piece of work, but
    /// caused this future to be cancelled.
    /// E.g. a network request failed, causing the future representing the result of some 
    /// parsing to be done with the result of the network request to be cancelled.
    /// The indirect error is this example is the network request error.
    case cancelled(indirectError: Error?)
}

// MARK: - Future

/// A future represents a read-only container for the delivery of a result
/// (of type `Result`) some time in the future.
///
/// One does not create futures, instead, one creates a promise, and then uses the future provided
/// by its `future` property.
/// A `Future<Result>` is what should be returned by any asynchronous function (**not** a promise),
/// where `Result` is the 'output' (or would be the return) type of the function.
/// A future is resolved by one, and only one, promise (the one that created it), using
/// the 'resolving' methods on promise.
///
/// When a future is said to be resolved, it is either:
/// * `fulfilled` with a result,
/// * `rejected` with an error, or
/// * `cancelled`, possibly with an indirect error (see `FutureResolvedState` for more information).
///
/// One can obtain the associated values from each resolved state using the 'when-' methods on future.
public final class Future<Result> {
    
    //MARK: Properties
    
    /// The promise that can set this future.
    private unowned let promise: Promise<Result>
    
    /// A private queue for synchronisation.
    fileprivate let internalQueue = DispatchQueue(label: "com.Daisy.PrivateFutureIsolationQueue")
    
    /// The state of the future.
    private var state: FutureState<Result> = .unresolved {
        
        willSet {
            
            guard case .unresolved = state else {
                
                fatalError("Daisy: Attempting to resolve a \(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())) more than once.")
            }
        }
    }
    
    /// Closures to be run when the future is resolved.
    private var handlers: [(DispatchQueue, (_ result: FutureResolvedState<Result>) -> Void)] = []
    
    //MARK: Initialisers
    
    /// Initialises a future, only resolvable by `promise`.
    init(promise: Promise<Result>) {
        
        self.promise = promise
    }
    
    //MARK: Resolving the Future
    
    /// Resolves the future using the resolved state of `promise`.
    /// If the promise is unresolved, this method does nothing.
    ///
    /// - Note: This method can only be called once for a given future, and `promise` **must** be the
    /// the promise the future was initialised with. Violating either condition will trap.
    func resolve(using promise: Promise<Result>) {
        
        // calling resolve creates a strong reference cycle for the future (keeping it memory)
        // this is through the block below capturing self
        // calling runHandlers also keeps the future is memory, as it captures self too
        // the cycles are broken when each block returns
        // therefore, if a promise is resolved, and then immediately deallocated (decrementing its future's reference count)
        // the future will remain in memory long enough to run its handlers, because resolve will be called by the promise
        // and the cycles mentioned above keep the future in memory
        // the handlers themselves do not create a reference cycle (nor should they, obviously).
        // it's fine if a promise is unresolved and deallocated, taking its future with it (even if the future has handlers set)
        // if the promise is deallocated, then the future could never be resolved, so deallocating it is fine
        
        internalQueue.async {
            
            guard promise === self.promise else {
                
                fatalError("Daisy: Attempting to set a \(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())) using a different promise to the one it was initialised with.")
            }
            
            switch promise.state {
                
            case .unresolved:
                return
                
            case .fulfilled(result: let result):
                self.state = .resolved(resolvedState: .fulfilled(result: result))
                
            case .rejected(error: let error):
                self.state = .resolved(resolvedState: .rejected(error: error))
                
            case .cancelled(indirectError: let indirectError):
                self.state = .resolved(resolvedState: .cancelled(indirectError: indirectError))
            }
            
            self.runHandlers()
        }
    }
    
    /// Executes all closures in the `handlers` array asynchronously
    /// on their specified queue, emptying said array afterwards.
    private func runHandlers() {
    
        // not sync-ed as it's private to future, and we're sure to sync access.
        // runHandlers() will only be called from within a sync-ed closure
        // so it's useful to be able to call it knowing it will do its work
        // within that same sync-ed closure, rather than enqueing the work of running
        // handlers to internalQueue, which may or may not be the next closure
        // to be executed after the current one (the one that called runHandlers()
        // in the first place). It's possible another closure could have been added to
        // internalQueue while the runHandlers()-calling closure was running (but
        // before it called runHandlers()), which would mean runHandlers() wouldn't
        // be the next closure called.
        
        guard case .resolved(resolvedState: let resolvedState) = self.state else { return }
        
        for (queue, closure) in self.handlers {
            
            queue.async {
                
                closure(resolvedState)
            }
        }
        
        self.handlers.removeAll()
    }
    
    // MARK: Obtaining a future's Resolved State and Associated Values
    
    /// These methods are intended to be for the basic use of futures, and/or building any other more pretty
    /// methods or functionality on top of them.
    
    /// Adds `closure` to the closures to be called when the receiver is resolved. Closures are
    /// executed in the order they are added.
    ///
    /// `closure` will always be called, regardless of the receiver's resolved state.
    ///
    /// - parameter queue: The queue to run `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to use to get the receiver's resolved state.
    public func whenResolved(executeOn queue: DispatchQueue = .main,
                             _ closure: @escaping (_ resolvedState: FutureResolvedState<Result>) -> Void) {
        
        // synchronise
        self.internalQueue.async {
            
            // append queue and closure
            self.handlers.append((queue, closure))
            
            self.runHandlers()
        }
    }
    
    /// Adds `closure` to the closures to be called if the receiver is fulfilled with a result. Closures are
    /// executed in the order they are added.
    ///
    /// `closure` will only be called if the receiver is fulfilled with a result.
    ///
    /// - parameter queue: The queue to run `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to call when the receiver is fulfilled.
    public func whenFulfilled(executeOn queue: DispatchQueue = .main, _ closure: @escaping (_ result: Result) -> Void) {
        
        whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let result):
                closure(result)
                
            default: return
                
            }
        }
    }
    
    /// Adds `closure` to the closures to be called if the receiver is rejected with an error. Closures are
    /// executed in the order they are added.
    ///
    /// `closure` will only be called if the receiver is rejected.
    ///
    /// - parameter queue: The queue to run `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to call when the receiver is rejected.
    public func whenRejected(executeOn queue: DispatchQueue = .main, _ closure: @escaping (_ error: Error) -> Void) {
        
        whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .rejected(error: let error):
                closure(error)
                
            default: return
                
            }
        }
    }
    
    /// Adds `closure` to the closures to be called if the receiver is cancelled. Closures are
    /// executed in the order they are added.
    ///
    /// `closure` will only be called if the receiver is cancelled.
    ///
    /// - parameter queue: The queue to run `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to call when the receiver is cancelled.
    public func whenCancelled(executeOn queue: DispatchQueue = .main, _ closure: @escaping (_ indirectError: Error?) -> Void) {
        
        whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .cancelled(indirectError: let indirectError):
                closure(indirectError)
                
            default: return
                
            }
        }
    }
    
    /// Adds `closure` to the closures to be called if the receiver is either rejected, or cancelled with an indirect error. Closures are
    /// executed in the order they are added.
    ///
    /// `closure` will only be called if the receiver is rejected or cancelled with an indirect error.
    /// If `whenRejected(executeOn:_:)` or `whenCancelled(executeOn:_:)` are called in addition to this method,
    /// their closures will be called as well.
    ///
    /// - parameter queue: The queue to run `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to call when the receiver is rejected, or cancelled with an indirect error.
    public func whenAnyError(executeOn queue: DispatchQueue = .main, _ closure: @escaping (_ error: Error) -> Void) {
        
        whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .rejected(error: let error):
                closure(error)
                
            case .cancelled(indirectError: let error?):
                closure(error)
                
            default: return
                
            }
        }
    }
    
    /// Synchronously waits for the receiver to be resolved.
    ///
    /// - note: In some cases, in order to resolve a future, an object may do work
    /// on the main queue (which is the default for the chaining family of functions). 
    /// `unsafeAwait()`ing that (or a chained) future on the main queue will deadlock. Use with caution.
    ///
    /// - returns: The receiver's result if it is fulfilled, otherwise `nil`.
    @discardableResult
    public func unsafeAwait() -> Result? {
        
        // check if we're already resolved, and cut down on some extra synchronisation
        var earlyResult: Result?
        var resolved = false
        internalQueue.sync {
            
            if case let .resolved(resolvedState) = state {
                
                resolved = true
                
                switch resolvedState {
                    
                case .fulfilled(result: let result):
                    earlyResult = result
                    
                case .rejected, .cancelled: break
                }
            }
        }
        if resolved { return earlyResult }
        
        var result: Result?
        let semaphore = DispatchSemaphore(value: 0)
        
        whenResolved(executeOn: internalQueue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let _result):
                result = _result
                
            default: break
            }
            
            semaphore.signal()
        }
        
        semaphore.wait()
        
        return result
    }
}

// MARK: - Type-Erasing Futures

extension Future {
    
    /// Returns a new future that will be resolved to the same state as the receiver,
    /// with the receiver's result (if there was one) type erased to `Any`.
    ///
    /// - note: This method does **not** return a casted version of `self`, but a
    /// new future instance altogether.
    ///
    /// - returns: A new future that will be resolved to the same state as the receiver.
    func toAny() -> Future<Any> {
        
        let promise = Promise<Any>()
        
        whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled(result: let result): promise.fulfil(with: result)
            case .rejected(error: let error): promise.reject(with: error)
            case .cancelled(indirectError: let indirectError): promise.cancel(withIndirectError: indirectError)
                
            }
        }
        
        return promise.future
    }
}
