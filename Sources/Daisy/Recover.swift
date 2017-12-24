//
//  Recover.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

public extension Future {
    
    /// Uses the supplied closure to attempt to recover from an error that caused
    /// the receiver to be either rejected, or cancelled with an indirect error.
    ///
    /// In the event of an error, `closure` will be called, giving you an opportunity
    /// to provide an alternative result. If an alternative result cannot be provided,
    /// `closure` should return `nil`.
    ///
    /// - important: It is important to note that if `closure` returns an alternative
    /// result, it will **not** be used to 're-resolve' the receiver (futures can
    /// only be resolved once). Instead, this method returns a new future, that will
    /// be resolved with the alternative result; allowing a chain of futures to
    /// continue. If `closure` is unable to provide an alternative result, the returned
    /// future will be resolved to the same state as the receiver, causing the error
    /// to propagate. If the receiver is fulfilled, or cancelled without an indirect
    /// error, `closure` will not be called, and the returned future will be resolved
    /// to the same state as the receiver.
    ///
    /// - parameter queue: The queue to execute `closure` on. Defaults to the main queue.
    /// - parameter includeIndirectErrors: A `Bool` indicating whether `closure` should
    /// also be used to recover from indirect errors. Defaults to `true`. If you pass
    /// `false` for this parameter, `closure` will only be called if the receiver
    /// is rejected, causing indirect errors to always propagate.
    /// - parameter closure: A closure taking the error that occurred, and returning
    /// either an alternative result, or `nil`.
    ///
    /// - returns: A new future that is either fulfilled with the result returned by
    /// `closure` (in the event of the receiver being rejected, or cancelled with an
    /// indirect error), or resolved to the same state as the receiver if: the receiver
    /// is fulfilled, `includeIndirectErrors` is `false` and the receiver is cancelled
    /// with an indirect error, or `closure` fails to provide an alternative result.
    @discardableResult
    public func recover(on queue: DispatchQueue = .main,
                        includingIndirectErrors includeIndirectErrors: Bool = true,
                        using closure: @escaping (_ error: Error) -> Result?) -> Future<Result> {
        
        let promise = Promise<Result>()
        
        self.whenResolved(executeOn: queue) { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled(result: let output):
                promise.fulfil(with: output)
                
            case .rejected(error: let error):
                if let result = closure(error) {
                    
                    promise.fulfil(with: result)
                }
                    
                else {
                    
                    promise.reject(with: error)
                }
                
            case .cancelled(indirectError: let indirectError):
                if includeIndirectErrors,
                   let indirectError = indirectError,
                   let result = closure(indirectError) {
                    
                    promise.fulfil(with: result)
                }
                
                else {
                    
                    promise.cancel(withIndirectError: indirectError)
                }
            }
        }
        
        return promise.future
    }
    
    /// Uses `alternativeResult` to recover from an error that caused the receiver to
    /// be either rejected, or cancelled with an indirect error.
    ///
    /// - important: It is important to note that `alternativeResult` will **not** be
    /// used to 're-resolve' the receiver (futures can only be resolved once). Instead,
    /// this method returns a new future, that, in the event of an error, will be
    /// resolved with `alternativeResult`; allowing a chain of futures to continue.
    /// If the receiver is fulfilled, or cancelled without an indirect error,
    /// `alternativeResult` will not be used, and the returned future will be resolved
    /// to the same state as the receiver.
    ///
    /// - parameter includeIndirectErrors: A `Bool` indicating whether `alternativeResult`
    /// should also be used to recover from indirect errors. Defaults to `true`. If
    /// you pass `false` for this parameter, `alternativeResult` will only be used if
    /// the receiver is rejected, causing indirect errors to always propagate.
    /// - parameter alternativeResult: The alternative result to use in the event
    /// of an error. `alternativeResult` will be evaluated on the main queue.
    ///
    /// - returns: A new future that is either fulfilled with `alternativeResult`
    /// (in the event of the receiver being rejected, or cancelled with an
    /// indirect error), or resolved to the same state as the receiver if: the receiver
    /// is fulfilled, or `includeIndirectErrors` is `false` and the receiver is cancelled
    /// with an indirect error.
    @discardableResult
    public func recover(includingIndirectErrors includeIndirectErrors: Bool = true,
                        using alternativeResult: @autoclosure @escaping () -> Result) -> Future<Result> {
        
        return recover(on: .main, includingIndirectErrors: includeIndirectErrors, using: { _ in
            
            return alternativeResult()
        })
    }
}
