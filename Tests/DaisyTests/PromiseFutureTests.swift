//
//  PromiseFutureTests.swift
//  DaisyTests
//
//  Created by Alasdair Baxter on 28/12/2016.
//  Copyright © 2016 Alasdair Baxter. All rights reserved.
//

import XCTest
@testable import Daisy

enum DummyError: Error {
    
    case error
}

extension NSError {
    
    static func makeDaisyTestError() -> NSError {
        
        return NSError(domain: "com.baxter.daisy", code: 42, userInfo: nil)
    }
}

extension XCTestCase {
    
    /// Performs a Dispatch precondition predicating that the current Dispatch queue
    /// is `queue`. If the `dispatchPrecondition` API is unavailable, this method
    /// will trigger an `XCTFail`.
    ///
    /// - Parameter queue: The queue to predicate is the current Dispatch queue.
    func dispatchPreconditionOnQueue(_ queue: DispatchQueue) {
        guard #available(macOS 10.12, iOS 10, tvOS 10, watchOS 3, *) else {
            
            XCTFail("Dispatch API availability preventing a check that we're on the correct queue.")
            return
        }
        
        dispatchPrecondition(condition: .onQueue(queue))
    }
}

class PromiseFutureTests: XCTestCase {
    
    let queue = DispatchQueue(label: "Daisy Test Queue", qos: .background, attributes: .concurrent)
    
    // MARK: Init
    
    func testInitPromise() {
        
        let unresolved = Promise<Void>()
        XCTAssert(!unresolved.isResolved)
        
        let rejected = Promise<Void>(rejectedWith: DummyError.error)
        let rejectedExpectation = expectation(description: "Promise rejected")
        rejected.future.whenRejected { error in
            
            XCTAssert(error is DummyError)
            rejectedExpectation.fulfill()
        }
        XCTAssert(rejected.isResolved)
        
        let cancelled = Promise<Void>(cancelledWithIndirectError: nil)
        let cancelledExpectation = expectation(description: "Promise cancelled")
        cancelled.future.whenCancelled { (error) in
            
            XCTAssert(error == nil)
            cancelledExpectation.fulfill()
        }
        XCTAssert(cancelled.isResolved)
        
        let cancelledWithIndirectError = Promise<Void>(cancelledWithIndirectError: DummyError.error)
        let cancelledWithIndirectErrorExpectation = expectation(description: "Promise cancelled with indirect error")
        cancelledWithIndirectError.future.whenCancelled { (error) in
            
            guard let error = error else { XCTFail(); return }
            
            XCTAssert(error is DummyError)
            cancelledWithIndirectErrorExpectation.fulfill()
        }
        XCTAssert(cancelledWithIndirectError.isResolved)
        
        let fulfilled = Promise(fulfilledWith: 42)
        let fulfilledExpectation = expectation(description: "Promise fulfilled")
        fulfilled.future.whenFulfilled { result in
            
            XCTAssertEqual(result, 42)
            fulfilledExpectation.fulfill()
        }
        XCTAssert(fulfilled.isResolved)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    // MARK: Resolve
    
    func testPromiseIsResolved() {
        
        let unresolved = Promise<Void>()
        XCTAssert(!unresolved.isResolved)
        
        let rejected = Promise<Void>(rejectedWith: DummyError.error)
        XCTAssert(rejected.isResolved)
        
        let cancelled = Promise<Void>(cancelledWithIndirectError: nil)
        XCTAssert(cancelled.isResolved)
        
        let cancelledWithIndirectError = Promise<Void>(cancelledWithIndirectError: DummyError.error)
        XCTAssert(cancelledWithIndirectError.isResolved)
        
        let fulfilled = Promise<Double>(fulfilledWith: 42)
        XCTAssert(fulfilled.isResolved)
    }
    
    func testResolveFutureWithUnresolvedPromise() {
        
        let waitedExpectation = expectation(description: "Waited for possible test failure")
        
        let unresolvedPromise = Promise<Void>()
        let future = unresolvedPromise.future
        
        future.resolve(using: unresolvedPromise)
        
        future.whenResolved { _ in XCTFail() }
        
        // give the whenResolved handler a chance to be called;
        // Future has no isResolved property
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(1), execute: waitedExpectation.fulfill)
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    // MARK: Resovle and Notify
    
    func testResolveFutureAndGetResolvedState() {
        
        let asyncAddOneExpectation = expectation(description: "Async Add One")
        
        let future = longAsyncAddOne(to: 1)
        future.whenResolved(executeOn: queue) { (result) in
            
            guard case .fulfilled(let value) = result else { XCTFail(); return }
            
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(value == 2)
            
            asyncAddOneExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testResolveFutureAndNotify() {
        
        let asyncAddOneExpectation = expectation(description: "Async Add One")
        
        let future = longAsyncAddOne(to: 1)
        
        future.whenRejected { _ in XCTFail() }
        future.whenCancelled { _ in XCTFail() }
        future.whenAnyError { _ in XCTFail() }
        
        future.whenFulfilled(executeOn: queue) { (value) in
            
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(value == 2)
            
            asyncAddOneExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testRejectFutureAndNotify() {
        
        let rejectFutureExpectation = expectation(description: "Reject Future")
        let whenAnyErrorCalledExpectation = expectation(description: "whenAnyError Called")
        
        let future = rejectingFuture()
        
        future.whenFulfilled { _ in XCTFail() }
        future.whenCancelled { _ in XCTFail() }
        
        future.whenRejected(executeOn: queue) { (error) in
    
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(error is DummyError)
            
            rejectFutureExpectation.fulfill()
        }
        
        future.whenAnyError(executeOn: queue) { error in
  
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(error is DummyError)
            
            whenAnyErrorCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCancelFutureAndNotify() {
        
        let cancelFutureExpectation = expectation(description: "Cancel Future")
        
        let future = cancellingFuture()
        
        future.whenFulfilled { _ in XCTFail() }
        future.whenRejected { _ in XCTFail() }
        future.whenAnyError { _ in XCTFail() }
        
        future.whenCancelled(executeOn: queue) { (_) in
    
            self.dispatchPreconditionOnQueue(self.queue)
            cancelFutureExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCancelWithIndirectErrorFutureAndNotify() {
        
        let cancelWithIndirectErrorExpectation = expectation(description: "Cancel With Indirect Error Future")
        let whenAnyErrorCalledExpectation = expectation(description: "whenAnyError Called Expectation")
        
        let future = cancellingWithIndirectErrorFuture()
        
        future.whenFulfilled { _ in XCTFail() }
        future.whenRejected { _ in XCTFail() }
        
        future.whenCancelled(executeOn: queue) { (indirectError) in
            
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(indirectError is DummyError)
            
            cancelWithIndirectErrorExpectation.fulfill()
        }
        
        future.whenAnyError(executeOn: queue) { error in
            
            self.dispatchPreconditionOnQueue(self.queue)
            XCTAssert(error is DummyError)
            
            whenAnyErrorCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: Future Extended Retain
    
    func testDirectGetValueRetainFuture() {
        
        let asyncAddOneExpectation = expectation(description: "Async Add One")
        
        longAsyncAddOne(to: 1).whenFulfilled { (value) in
            
            XCTAssert(value == 2)
            
            asyncAddOneExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: Multiple Future Resolves
    
    func testMultipleFutureResolve() {
        
        // resolve after fulfil
        
        let whenFulfilCalledExpectation = expectation(description: "WhenFulFilled Called")
        
        let fulfilPromise = Promise<String>()
        let fulfilFuture = fulfilPromise.future
        
        let expectedResult = "42"
        
        fulfilPromise.fulfil(with: expectedResult)
        fulfilPromise.fulfil(with: "0")
        
        fulfilFuture.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled(result: let result):
                XCTAssertEqual(result, expectedResult)
                whenFulfilCalledExpectation.fulfill()
            
            default: XCTFail()
            }
        }
        
        // resolve after reject
        
        let whenRejectedCalledExpectation = expectation(description: "WhenRejected Called")
        
        let rejectPromise = Promise<Void>()
        let rejectFuture = rejectPromise.future
        
        rejectPromise.reject(with: DummyError.error)
        rejectPromise.reject(with: NSError.makeDaisyTestError())
        
        rejectFuture.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .rejected(error: let error):
                XCTAssert(error is DummyError)
                whenRejectedCalledExpectation.fulfill()
            
            default: XCTFail()
            }
        }
        
        // resolve after cancellation
        
        let whenCancelledCalledExpectation = expectation(description: "WhenCancellde Called")
        
        let cancelPromise = Promise<Void>()
        let cancelFuture = cancelPromise.future
        
        cancelPromise.cancel()
        cancelPromise.cancel(withIndirectError: DummyError.error)
        
        cancelFuture.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .cancelled(indirectError: let indirectError):
                XCTAssert(indirectError == nil)
                whenCancelledCalledExpectation.fulfill()
                
            default: XCTFail()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: Handler Order and Queue
    
    func testFutureHandlerOrder() {
        
        let future = longAsyncAddOne(to: 1)
        let resolvedExpectation = expectation(description: "Future Resolved")
        
        var numbers: [Int] = []
        
        future.whenResolved { (_) in
            
            numbers.append(1)
        }
        
        future.whenFulfilled { (_) in
            
            numbers.append(2)
        }
        
        future.whenResolved { (_) in
            
            numbers.append(3)
            resolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 2) { (_) in
            
            XCTAssert(numbers == [1, 2, 3])
        }
    }
    
    func testFutureHandlerQueue() {
        
        let future = longAsyncAddOne(to: 1)
        let resolvedExpectation = expectation(description: "Future Resolved")
        
        future.whenResolved { (_) in
            
            self.dispatchPreconditionOnQueue(.main)
            resolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    // MARK: Await
    
    func testAwaitFutureResult() {
        
        let resolvedHandlerCalledExpectation = expectation(description: "Resolved Handler Called")
        
        let future = longAsyncAddOne(to: 1)
        future.whenResolved { (_) in
            
            resolvedHandlerCalledExpectation.fulfill()
        }
        
        if let result = future.unsafeAwait() {
            
            XCTAssertEqual(result, 2)
        }
            
        else {
            
            XCTFail()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testAwaitRejectingFutureResult() {
        
        XCTAssert(rejectingFuture().unsafeAwait() == nil)
    }
    
    func testAwaitCancelledFutureResult() {
        
        XCTAssert(cancellingFuture().unsafeAwait() == nil)
    }
    
    func testAlreadyFulfilledAwaitFutureResult() {
        
        // fulfilled future
        
        let fulfilledResolvedHandlerCalledExpectation = expectation(description: "Fulfilled Resolved Handler Called")
        
        let resolvedFuture = Promise(fulfilledWith: 42).future
        resolvedFuture.whenResolved { (_) in
            
            // do the await in a whenResolved block to avoid a possible
            // test-related race condition where the await call would go
            // through on the future's internal queue before the promise's
            // call the fulfil on its internal queue.
            // this isn't a bug, this is just a 'workaround' so the test tests
            // what its supposed to
            if let result = resolvedFuture.unsafeAwait() {
                
                XCTAssertEqual(result, 42)
            }
                
            else {
                
                XCTFail()
            }
            
            fulfilledResolvedHandlerCalledExpectation.fulfill()
        }
        
        // rejected future
        
        let rejectedResolvedHandlerCalledExpectation = expectation(description: "Rejected Resolved Handler Called")
        
        let rejectedFuture = Promise<Void>(rejectedWith: DummyError.error).future
        rejectedFuture.whenResolved { (_) in
            
            XCTAssertNil(rejectedFuture.unsafeAwait())
            
            rejectedResolvedHandlerCalledExpectation.fulfill()
        }
        
        // cancelled future
        
        let cancelledResolvedHandlerCalledExpectation = expectation(description: "Cancelled Resolved Handler Called")
        
        let cancelledFuture = Promise<Void>(cancelledWithIndirectError: DummyError.error).future
        cancelledFuture.whenResolved { (_) in
            
            XCTAssertNil(cancelledFuture.unsafeAwait())
            
            cancelledResolvedHandlerCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: ToAny
    
    func testFutureToAny() {
        
        // fulfilled
        
        let whenAnyFulfilledCalledExpectation = expectation(description: "When Any Fulfilled Called")
        let anyFulfilledFuture = Promise(fulfilledWith: 42).future.toAny()
        
        anyFulfilledFuture.whenFulfilled { result in
            
            guard let result = result as? Int else { XCTFail(); return }
            
            XCTAssertEqual(result, 42)
            
            whenAnyFulfilledCalledExpectation.fulfill()
        }
        
        // rejected
        
        let whenAnyRejectedCalledExpectation = expectation(description: "When Any Rejected Called")
        let anyRejectedFuture = Promise<Int>(rejectedWith: DummyError.error).future.toAny()
        
        anyRejectedFuture.whenRejected { error in
            
            XCTAssert(error is DummyError)
            
            whenAnyRejectedCalledExpectation.fulfill()
        }
        
        // cancelled
        
        let whenAnyCancelledCalledExpectation = expectation(description: "When Any Cancelled Called")
        let anyCancelledFuture = Promise<Int>(cancelledWithIndirectError: DummyError.error).future.toAny()
        
        anyCancelledFuture.whenCancelled { error in
            
            XCTAssertNotNil(error)
            XCTAssert(error is DummyError)
            
            whenAnyCancelledCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Future Vending Functions
    
    let asyncDelay = 1
    
    private func longAsyncAddOne(to: Int) -> Future<Int> {
        
        let promise = Promise<Int>()
        
        queue.asyncAfter(deadline: .now() + .seconds(asyncDelay)) {
            
            promise.fulfil(with: to + 1)
        }
        
        return promise.future
    }
    
    private func asyncAddOne(to: Int) -> Future<Int> {
        
        let promise = Promise<Int>()
        
        promise.fulfil(with: to + 1)
        
        return promise.future
    }
    
    private func rejectingFuture() -> Future<Void> {
        
        let promise = Promise<Void>()
        
        queue.asyncAfter(deadline: .now() + .seconds(asyncDelay)) {
            
            promise.reject(with: DummyError.error)
        }
        
        return promise.future
    }
    
    private func cancellingFuture() -> Future<Void> {
        
        let promise = Promise<Void>()
        
        queue.asyncAfter(deadline: .now() + .seconds(asyncDelay)) { 
            
            promise.cancel()
        }
        
        return promise.future
    }
    
    private func cancellingWithIndirectErrorFuture() -> Future<Void> {
        
        let promise = Promise<Void>()
        
        queue.asyncAfter(deadline: .now() + .seconds(asyncDelay)) { 
            
            promise.cancel(withIndirectError: DummyError.error)
        }
        
        return promise.future
    }
}
