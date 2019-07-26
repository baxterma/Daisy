//
//  Always.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import Dispatch

public extension Future {
    
    /// Enqueues `closure` to always be called when the receiver is resolved,
    /// irrespective of its resolved state. `closure` will always be called if the
    /// receiver is resolved.
    ///
    /// - parameter queue: The queue to call `closure` on. Defaults to the main queue.
    /// - parameter closure: The closure to always call when the receiver is
    /// resolved, irrespective of its resolved state.
    ///
    /// - returns: A future representing the execution of `closure`. Providing the
    /// receiver is resolved at some point, the returned future is guarenteed to be
    /// eventually fulfilled (with `()`).
    @discardableResult
    func always(on queue: DispatchQueue = .main, execute closure: @escaping () -> Void) -> Future<Void> {
        
        let promise = Promise<Void>()
        
        self.whenResolved(executeOn: queue) { _ in
            
            closure()
            promise.fulfil(with: ())
        }
        
        return promise.future
    }
    
    /// Enqueues `task` to always be started when the receiver is resolved,
    /// irrespective of its resolved state. `task` will always be started if the
    /// receiver is resolved.
    ///
    /// - parameter queue: The queue to start `task` on. Defaults to the global
    /// utility queue.
    /// - parameter task: The task to always start when the receiver is resolved,
    /// irrespective of its resolved state.
    ///
    /// - returns: A future representing the execution of `task`. Providing the
    /// receiver is resolved at some point, the returned future is guarenteed to be
    /// eventually resolved too.
    @discardableResult
    func always(on queue: DispatchQueue = .global(qos: .utility), execute task: Task<Void, Void>) -> Future<Void> {
        
        task.setEnqueued()
        
        self.whenResolved(executeOn: queue) { _ in
            
            task.attemptStart(with: (), on: queue)
        }
        
        return task.future
    }
}
