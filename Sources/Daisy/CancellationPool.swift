//
//  CancellationPool.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

// MARK: - Cancellable

/// A type conforming to this protocol enables it to be cancelled by a cancellation pool.
public protocol Cancellable: class {
    
    /// Asks the receiver to cancel any work it may be doing, providing it
    /// is in a state where it can do so.
    /// If the receiver cannot be cancelled, this method should do nothing.
    func attemptCancel()
}

// Extend Task to conform to Cancellable
extension Task: Cancellable {
    
    public func attemptCancel() {
        
        cancel(shouldPrintAlreadyFinishedWarning: false)
    }
}

// MARK: - CancellationPool

/// A cancellation pool is used to collect a series of `Cancellable` items, where they can later
/// be cancelled without needing to manually store a collection of the aforementioned items.
/// A cancellation pool stores weak references to the items added to it.
///
/// Items can either be added to a cancellation pool manually, or by passing a cancellation pool to any of the
/// `start(running:)` or chaining families of functions. 
///
/// To cancel the items in a cancellation pool, call `drain()`. This asks the items in the pool to cancel, and removes
/// them from the pool. 
///
/// - note: If some of the items in a cancellation pool are in a state where they cannot be cancelled,
/// (e.g. they have already finished their work), they will still be sent the `attemptCancel()` message, and it is up to
/// the receiver in this case to do nothing (as per the documentation for `Cancellable`).
public final class CancellationPool {
    
    private let internalQueue = DispatchQueue(label: "com.Daisy.CancellationPoolInternalQueue")
    
    /// An array of closures that each capture a weak reference to one of the cancellable
    /// items in the cancellation pool.
    private var pool: [() -> Cancellable?] = []
    
    /// Initialises a new, empty, cancellation pool.
    public init() { }
    
    /// Adds the `cancellableItem` to the cancellation pool.
    ///
    /// - parameter cancellableItem: The item to add to the cancellation pool.
    public func add(_ cancellableItem: Cancellable) {
        
        add(contentsOf: [cancellableItem])
    }
    
    /// Adds the contents of `cancellableItems` to the CancellationPool.
    ///
    /// - parameter cancellableItems: The items to add to the cancellation pool.
    public func add(contentsOf cancellableItems: [Cancellable]) {
    
        func makeWeakReferenceWrapper(for cancellable: Cancellable) -> () -> Cancellable? {
            return { [weak cancellable] in return cancellable }
        }
        
        internalQueue.sync {
            
            cancellableItems
                .map(makeWeakReferenceWrapper(for:))
                .forEach { pool.append($0) }
        }
    }
    
    /// Asks all the items in the cancellation pool to cancel, and empties the pool.
    public func drain() {
        
        internalQueue.sync {
            
            pool.compactMap { $0() }
                .forEach { $0.attemptCancel() }
            
            pool.removeAll()
        }
    }
}
