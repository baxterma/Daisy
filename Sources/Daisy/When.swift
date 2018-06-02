//
//  When.swift
//  Daisy
//
//  Created by Alasdair Baxter on 02/02/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

private let whenQueue = DispatchQueue(label: "com.Daisy.whenQueue", attributes: .concurrent)

public extension Future {
    
    /// When the supplied futures fulfil, this method combines their results into an
    /// array, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter futures: The futures to wait on being fulfilled, whose results
    /// should be combined into an array, and then used to fulfil the returned future.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into an array. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R>(_ futures: [Future<R>]) -> Future<[R]> where Result == [R] {
        
        let syncQueue = DispatchQueue(label: "com.Daisy.WhenSyncQueue")
        let group = DispatchGroup()
        let futuresCount = futures.count
        var output = Array(repeating: Optional<R>.none, count: futuresCount)
        let groupPromise = Promise<[R]>()
        
        for (index, future) in futures.enumerated() {
            
            group.enter()
            
            future.whenResolved(executeOn: syncQueue, { (resolvedState) in
                
                group.leave()
                
                switch resolvedState {
                    
                case .fulfilled(result: let result):
                    output[index] = result
                    
                case .rejected(error: let error) where !groupPromise.isResolved:
                    groupPromise.reject(with: error)
                    
                case .cancelled(indirectError: let error) where !groupPromise.isResolved:
                    groupPromise.cancel(withIndirectError: error)
                    
                default: break
                    
                }
            })
        }
        
        // called when all the supplied futures resolve
        group.notify(queue: syncQueue) {
            
            guard !groupPromise.isResolved else { return }
            
            let fulfilledOutput = output.compactMap { $0 }
            
            // if groupPromise is not resolved, the only thing we can do here is
            // fulfil it. If we don't have the number of fulfilled results we were
            // expecting to fulfil groupPromise with, we should trap.
            precondition(fulfilledOutput.count == futuresCount,
                         "Daisy: Error: The number of fulfilled results differs from the expected amount in `Future.resolvingWhen(_:)`. Expected: \(futuresCount), got: \(fulfilledOutput.count).")
            
            groupPromise.fulfil(with: fulfilledOutput)
        }
        
        return groupPromise.future
    }
    
    /// When the supplied futures fulfil, this method combines their results into a
    /// tuple, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter f0: The future whose result will be used as the first element of
    /// the returned future's result.
    /// - parameter f1: The future whose result will be used as the second element of
    /// the returned future's result.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into a tuple. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R0, R1>(_ f0: Future<R0>,
                                              _ f1: Future<R1>) -> Future<(R0, R1)> where Result == (R0, R1) {
        
        return Future<[Any]>.fulfillingWhen([f0.toAny(), f1.toAny()])
        .then(on: whenQueue, execute: { (results) in
            
            return (results[0] as! R0, results[1] as! R1)
        })
    }
    
    /// When the supplied futures fulfil, this method combines their results into a
    /// tuple, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter f0: The future whose result will be used as the first element of
    /// the returned future's result.
    /// - parameter f1: The future whose result will be used as the second element of
    /// the returned future's result.
    /// - parameter f2: The future whose result will be used as the third element of
    /// the returned future's result.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into a tuple. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R0, R1, R2>(_ f0: Future<R0>,
                                                  _ f1: Future<R1>,
                                                  _ f2: Future<R2>) -> Future<(R0, R1, R2)> where Result == (R0, R1, R2) {
        
        return Future<[Any]>.fulfillingWhen([f0.toAny(), f1.toAny(), f2.toAny()])
        .then(on: whenQueue, execute: { (results) in
            
            return (results[0] as! R0, results[1] as! R1, results[2] as! R2)
        })
    }
    
    /// When the supplied futures fulfil, this method combines their results into a
    /// tuple, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter f0: The future whose result will be used as the first element of
    /// the returned future's result.
    /// - parameter f1: The future whose result will be used as the second element of
    /// the returned future's result.
    /// - parameter f2: The future whose result will be used as the third element of
    /// the returned future's result.
    /// - parameter f3: The future whose result will be used as the fourth element of
    /// the returned future's result.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into a tuple. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R0, R1, R2, R3>(_ f0: Future<R0>,
                                                      _ f1: Future<R1>,
                                                      _ f2: Future<R2>,
                                                      _ f3: Future<R3>) -> Future<(R0, R1, R2, R3)> where Result == (R0, R1, R2, R3) {
        
        return Future<[Any]>.fulfillingWhen([f0.toAny(), f1.toAny(), f2.toAny(), f3.toAny()])
        .then(on: whenQueue, execute: { (results) in
            
            return (results[0] as! R0, results[1] as! R1, results[2] as! R2, results[3] as! R3)
        })
    }
    
    /// When the supplied futures fulfil, this method combines their results into a
    /// tuple, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter f0: The future whose result will be used as the first element of
    /// the returned future's result.
    /// - parameter f1: The future whose result will be used as the second element of
    /// the returned future's result.
    /// - parameter f2: The future whose result will be used as the third element of
    /// the returned future's result.
    /// - parameter f3: The future whose result will be used as the fourth element of
    /// the returned future's result.
    /// - parameter f4: The future whose result will be used as the fifth element of
    /// the returned future's result.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into a tuple. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R0, R1, R2, R3, R4>(_ f0: Future<R0>,
                                                          _ f1: Future<R1>,
                                                          _ f2: Future<R2>,
                                                          _ f3: Future<R3>,
                                                          _ f4: Future<R4>) -> Future<(R0, R1, R2, R3, R4)> where Result == (R0, R1, R2, R3, R4) {
        
        return Future<[Any]>.fulfillingWhen([f0.toAny(), f1.toAny(), f2.toAny(), f3.toAny(), f4.toAny()])
        .then(on: whenQueue, execute: { (results) -> (R0, R1, R2, R3, R4) in
            
            let r0 = results[0] as! R0
            let r1 = results[1] as! R1
            let r2 = results[2] as! R2
            let r3 = results[3] as! R3
            let r4 = results[4] as! R4
        
            return (r0, r1, r2, r3, r4)
        })
    }
    
    /// When the supplied futures fulfil, this method combines their results into a
    /// tuple, which is then used to fulfil the returned future.
    ///
    /// - note: Should any of the supplied futures be rejected or cancelled, the first
    /// one to become so will cause the returned future to be *immediately* resolved to
    /// the same state (either rejected or cancelled).
    ///
    /// - warning: Only the first rejection or cancellation will have
    /// an effect on the returned future. If more than one of the supplied
    /// futures is rejected or cancelled, the resolved state of the returned future
    /// will match that of the *first* future to be rejected or cancelled. This method
    /// only informs you of the first non-fulfilment (through the resolved state of the
    /// returned future).
    ///
    /// - parameter f0: The future whose result will be used as the first element of
    /// the returned future's result.
    /// - parameter f1: The future whose result will be used as the second element of
    /// the returned future's result.
    /// - parameter f2: The future whose result will be used as the third element of
    /// the returned future's result.
    /// - parameter f3: The future whose result will be used as the fourth element of
    /// the returned future's result.
    /// - parameter f4: The future whose result will be used as the fifth element of
    /// the returned future's result.
    /// - parameter f5: The future whose result will be used as the sixth element of
    /// the returned future's result.
    ///
    /// - returns: A new future that fulfils when the supplied futures fulfil, with
    /// their results combined into a tuple. Should any of the supplied futures be
    /// rejected or cancelled, the first one to become so will cause the returned
    /// future to be *immediately* resolved to the same state (either rejected or cancelled).
    public static func fulfillingWhen<R0, R1, R2, R3, R4, R5>(_ f0: Future<R0>,
                                                              _ f1: Future<R1>,
                                                              _ f2: Future<R2>,
                                                              _ f3: Future<R3>,
                                                              _ f4: Future<R4>,
                                                              _ f5: Future<R5>) -> Future<(R0, R1, R2, R3, R4, R5)> where Result == (R0, R1, R2, R3, R4, R5) {
        
        return Future<[Any]>.fulfillingWhen([f0.toAny(), f1.toAny(), f2.toAny(), f3.toAny(), f4.toAny(), f5.toAny()])
        .then(on: whenQueue, execute: { (results) -> (R0, R1, R2, R3, R4, R5) in
                    
            let r0 = results[0] as! R0
            let r1 = results[1] as! R1
            let r2 = results[2] as! R2
            let r3 = results[3] as! R3
            let r4 = results[4] as! R4
            let r5 = results[5] as! R5
                    
            return (r0, r1, r2, r3, r4, r5)
        })
    }
}
