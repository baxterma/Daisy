//
//  Promise.swift
//  Daisy
//
//  Created by Alasdair Baxter on 28/12/2016.
//  Copyright © 2016 Alasdair Baxter. All rights reserved.
//

import Dispatch

/// The states a promise can be in.
enum PromiseState<Result> {
    
    /// The promise is unresolved.
    case unresolved
    
    /// The promise has been fulfilled with a value (resolved).
    case fulfilled(result: Result)
    
    /// The promise has been rejected with an error (resolved).
    case rejected(error: Error)
    
    /// The promise has been cancelled, possibly with an indirect error (resolved).
    case cancelled(indirectError: Error?)
}

/// A promise is used as a means of resolving a future. An asynchronous task or function
/// creates a promise, and keeps it private from the outside world (only exposing the promise's future).
///
/// When the work to be done is finished (be it successfully or unsuccessfully), the promise is resolved by
/// calling `fulfil(with:)`, `reject(with:)`, **or** `cancel(withIndirectError:)` **once**. 
/// Calling any of these functions more than once (regardless if it is a different one each time) will do nothing.
///
/// A promise only acts as a write-only means of setting a future. The result from a resolved promise must be accessed using its
/// `future` property, and the mechanisms future provides.
public final class Promise<Result> {
    
    //MARK: Properties
    
    private var _future: Future<Result>!
    
    /// The promise's future.
    public var future: Future<Result> {
        
        return _future!
    }
    
    private var _state: PromiseState<Result> = .unresolved // so we can protect `state`, and have a non-sync-ed way of accessing it
    
    /// The current state of the promise.
    private(set) var state: PromiseState<Result> {
        
        set { // not sync-ed, as its private to promise, and we're sure to sync any setting
            
            // validate the state change
            switch _state {
                
            case .unresolved:
                _state = newValue
                
            // if the state change is moving from a resolved state, trap (this really shouldn't happen)
            // because `state` can only be set privately, an invalid change is a bug in Daisy
            case .fulfilled(_), .rejected(error: _), .cancelled(indirectError: _):
                fatalError("Daisy: Attempting to move a promise (\(Unmanaged.passUnretained(self).toOpaque())) from the \(_state) state to the \(newValue) state.")
            }    
        }
        
        get { return internalQueue.sync { _state } } // sync-ed because this can be accessed outside of promise
        
    }
    
    /// Returns `true` iff the receiver has been resolved, otherwise returns `false`.
    public var isResolved: Bool {
        
        return internalQueue.sync {
            
            if case .unresolved = _state { return false }
            else { return true }
        }
    }
    
    /// A private queue for synchronisation.
    fileprivate let internalQueue = DispatchQueue(label: "com.Daisy.PrivatePromiseIsolationQueue")
    
    //MARK: Initialisers
    
    /// Initialises an unresolved promise.
    public init() {
        
        _future = Future<Result>(promise: self)
    }
    
    /// Initialises a resolved promise, fulfilled with `result`.
    ///
    /// - parameter result: The result the promise should be fulfilled with.
    public convenience init(fulfilledWith result: Result) {
        
        self.init()
        fulfil(with: result)
    }
    
    /// Initialises a resolved promise, rejected with `error`.
    ///
    /// - parameter error: The error the promise should be rejected with.
    public convenience init(rejectedWith error: Error) {
        
        self.init()
        reject(with: error)
    }
    
    /// Initialises a resolved promise, cancelled with `indirectError`.
    ///
    /// - parameter indirectError: The (optional) indirect error the promise should be cancelled with.
    public convenience init(cancelledWithIndirectError indirectError: Error?) {
        
        self.init()
        cancel(withIndirectError: indirectError)
    }
    
    //MARK: Resolving Methods
    
    /// Fulfills the receiver with `result`.
    ///
    /// Does nothing if the receiver is already resolved.
    ///
    /// - parameter result: The result to fulfil the receiver with.
    public func fulfil(with result: Result) {
        
        internalQueue.async {
            
            guard case .unresolved = self._state else {
                
                print("Daisy: Warning: Attempting to fulfill a \(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())) that is already resolved (\(self._state))")
                return
            }
            
            self.state = .fulfilled(result: result)
            self.future.resolve(using: self)
        }
    }
    
    /// Rejects the receiver with `error`.
    ///
    /// Does nothing if the receiver is already resolved.
    ///
    /// - parameter error: The error to reject the receiver with.
    public func reject(with error: Error) {
        
        internalQueue.async {
            
            guard case .unresolved = self._state else {
                
                print("Daisy: Warning: Attempting to reject a \(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())) that is already resolved (\(self._state))")
                return
            }
            
            self.state = .rejected(error: error)
            self.future.resolve(using: self)
        }
    }
    
    /// Cancels the receiver, optionally with `indirectError`.
    ///
    /// Does nothing if the receiver is already resolved.
    ///
    /// - parameter indirectError: The (optional) indirect error to cancel the
    /// receiver with.
    public func cancel(withIndirectError indirectError: Error? = nil) {
        
        internalQueue.async {
            
            guard case .unresolved = self._state else {
                
                print("Daisy: Warning: Attempting to cancel a \(type(of: self)) (\(Unmanaged.passUnretained(self).toOpaque())) that is already resolved (\(self._state))")
                return
            }
            
            self.state = .cancelled(indirectError: indirectError)
            self.future.resolve(using: self)
        }
    }
}
