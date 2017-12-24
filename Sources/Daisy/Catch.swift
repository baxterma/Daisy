//
//  Catch.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

public extension Future {
    
    /// Calls the supplied closure if the receiver is rejected, or cancelled with
    /// an indirect error; giving you an opportunity to respond to errors.
    ///
    /// - note: Calling this method as part of a chain of futures does *not* prevent
    /// errors from propagating past this point (even if `closure` is called). To
    /// recover from an error, and prevent it from propagating, use
    /// `recover(on:includingIndirectErrors:using:)`.
    ///
    /// - parameter queue: The queue to execute `closure` on. Defaults to the main queue.
    /// - parameter includeIndirectErrors: A `Bool` indicating whether `closure`
    /// should also be called if the receiver is cancelled with an indirect error.
    /// Defaults to `true`. If you pass `false` for this parameter, `closure` will
    /// only be called if the receiver is rejected.
    /// - parameter closure: The closure to call if the receiver is rejected, or
    /// cancelled with an indirect error.
    ///
    /// - returns: The receiver. This allows a chain to continue to be built after
    /// calling this method. Note that this means the error the receiver was rejected
    /// or cancelled with will continue to propagate down a chain, even if `closure`
    /// is called.
    @discardableResult
    public func `catch`(on queue: DispatchQueue = .main,
                        includingIndirectErrors includeIndirectErrors: Bool = true,
                        using closure: @escaping (_ error: Error) -> Void) -> Future<Result> {
        
        if includeIndirectErrors {
            
            self.whenAnyError(executeOn: queue, closure)
        }
            
        else {
            
            self.whenRejected(executeOn: queue, closure)
        }
        
        return self
    }
}

