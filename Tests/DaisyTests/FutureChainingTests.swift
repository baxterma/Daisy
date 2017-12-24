//
//  FutureChainingTests.swift
//  Daisy
//
//  Created by Alasdair Baxter on 19/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import XCTest
@testable import Daisy

class FutureChainingTests: XCTestCase {
    
    // MARK: - Then
    
    func testThenOrder() {
        
        var order: [Int] = []
        let thensCalledExpectation = expectation(description: "Fourth Then Called")
        
        let future = start(running: VoidTask(), with: ())
        
        future.then {
            
            order.append(1)
        }
        
        future.then {
            
            order.append(2)
        }
        
        future.then {
            
            order.append(3)
        }
        
        future.then {
            
            order.append(4)
            XCTAssertEqual(order, [1, 2, 3, 4])
            thensCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
        
    }
    
    func testFulfilThenTask() {
        
        let testTaskCompleted = expectation(description: "TestTask Completed")
        let future = Promise<Double>(fulfilledWith:42).future
        
        let testTask = TestTask()
        testTask.future.whenResolved {_ in
            
            testTaskCompleted.fulfill()
        }
        
        future.then(testTask)
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testRejectThenTask() {
        
        let catchCalledExpectation = expectation(description: "Catch Called")
        let testTask = TestTask() // should be cancelled
        
        let promise = Promise<Double>()
        promise.reject(with: DummyError.error)
        let rejectedFuture = promise.future
        
        rejectedFuture.then(testTask)
        .catch { (error) in
            
            XCTAssert(error is DummyError)
            XCTAssert(testTask.isCancelled)
            
            testTask.future.whenCancelled { error in
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                catchCalledExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelThenTask() {
        
        let catchCalledExpectation = expectation(description: "Catch Called")
        let testTask = TestTask() // should be cancelled
        
        let promise = Promise<Double>()
        promise.cancel(withIndirectError: DummyError.error)
        let rejectedFuture = promise.future
        
        rejectedFuture.then(testTask)
        .catch { (error) in
            
            XCTAssert(error is DummyError)
            XCTAssert(testTask.isCancelled)
            
            testTask.future.whenCancelled { error in
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                catchCalledExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testFulfilThenOutputReturningClosure() {
        
        let futureFulfilledExpectation = expectation(description: "Future Fulfilled")
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        
        let shouldBeFulfilledFuture = fulfilledFuture.then { _ in
            
            return
        }
        
        shouldBeFulfilledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            case .fulfilled:
                
                futureFulfilledExpectation.fulfill()
                
            default: XCTFail()
            }
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testRejectThenOutputReturningClosure() {
        
        let futureResolvedExpectation = expectation(description: "Future Resolved")
        
        let promise = Promise<Double>()
        promise.reject(with: DummyError.error)
        let rejectedFuture = promise.future
        
        let shouldBeCancelledFuture = rejectedFuture.then { input -> Double in
            
            XCTFail()
            
            return input + 1
        }
        
        shouldBeCancelledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            // shouldBeCancelledFuture should be cancelled
            case .cancelled(indirectError: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
            default: XCTFail()
            }
            
            futureResolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelThenOutputReturningClosure() {
        
        let futureResolvedExpectation = expectation(description: "Future Resolved")
        
        let promise = Promise<Double>()
        promise.cancel(withIndirectError: DummyError.error)
        let rejectedFuture = promise.future
        
        let shouldBeCancelledFuture = rejectedFuture.then { input -> Double in
            
            XCTFail()
            
            return input + 1
        }
        
        shouldBeCancelledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            // shouldBeCancelledFuture should be cancelled
            case .cancelled(indirectError: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
            default: XCTFail()
            }
            
            futureResolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testFulfilThenFutureReturningClosure() {
        
        let futureFulfilledExpectation = expectation(description: "Future Fulfilled")
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        
        let shouldBeFulfilledFuture = fulfilledFuture.then { _ -> Future<Void> in
            
            return Promise(fulfilledWith: ()).future
        }
        
        shouldBeFulfilledFuture.whenResolved { resolvedState in
            
            switch resolvedState {
                
            case .fulfilled:
                
                futureFulfilledExpectation.fulfill()
                
            default: XCTFail()
            }
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testRejectThenFutureReturningClosure() {
        
        let futureResolvedExpectation = expectation(description: "Future Resolved")
        
        let promise = Promise<Double>()
        promise.reject(with: DummyError.error)
        let rejectedFuture = promise.future
        
        let shouldBeCancelledFuture = rejectedFuture.then { input -> Future<Double> in
            
            XCTFail()
            
            return Promise(fulfilledWith: input + 1).future
        }
        
        shouldBeCancelledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            // shouldBeCancelledFuture should be cancelled
            case .cancelled(indirectError: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
            default: XCTFail()
            }
            
            futureResolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelThenFutureReturningClosure() {
        
        let futureResolvedExpectation = expectation(description: "Future Resolved")
        
        let promise = Promise<Double>()
        promise.cancel(withIndirectError: DummyError.error)
        let cancelledFuture = promise.future
        
        let shouldBeCancelledFuture = cancelledFuture.then { input -> Future<Double> in
            
            XCTFail()
            
            return Promise(fulfilledWith: input + 1).future
        }
        
        shouldBeCancelledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            // shouldBeCancelledFuture should be cancelled
            case .cancelled(indirectError: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
            default: XCTFail()
            }
            
            futureResolvedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testFulfilThenRejectedFutureReturningClosure() {
        
        let futureRejectedExpectation = expectation(description: "Returned Future Rejected")
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        
        let shouldBeRejectedFuture = fulfilledFuture.then { _ -> Future<Void> in
            
            return Promise(rejectedWith: DummyError.error).future
        }
        
        shouldBeRejectedFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            case .rejected(error: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
                futureRejectedExpectation.fulfill()
                
            default: XCTFail()
            }
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilThenCancelledFutureReturningClosure() {
        
        let futureCancelledExpectation = expectation(description: "Returned Future Cancelled")
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        
        let shouldBeCancelledFuture = fulfilledFuture.then { _ -> Future<Void> in
            
            return Promise(cancelledWithIndirectError: DummyError.error).future
        }
        
        shouldBeCancelledFuture.whenResolved { (resolvedState) in
            
            switch resolvedState {
                
            case .cancelled(indirectError: let error):
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                
                futureCancelledExpectation.fulfill()
                
            default: XCTFail()
            }
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testRejectThenGroup() {
        
        let catchCalledExpectation = expectation(description: "Catch Called")
        
        let promise = Promise<Double>()
        promise.reject(with: DummyError.error)
        let rejectedFuture = promise.future
        
        // both tasks below should be cancelled with an indirect error
        // because the rejected future indirectly caused them to be cancelled
        
        let task1 = TestTask()
        let task1IndirectErrorExpectation = expectation(description: "Task 1 Indirect Error")
        
        let task2 = TestTask()
        let task2IndirectErrorExpectation = expectation(description: "Task 2 Indirect Error")
        
        rejectedFuture.then([task1, task2])
        .then { input -> [Double] in
            
            XCTFail()
            return input
        }
        .catch { (error) in
            
            XCTAssert(task1.isCancelled)
            XCTAssert(task1.isCancelled)
            
            task1.future.whenCancelled { error in XCTAssertNotNil(error); XCTAssert(error is DummyError); task1IndirectErrorExpectation.fulfill() }
            task2.future.whenCancelled { error in XCTAssertNotNil(error); XCTAssert(error is DummyError); task2IndirectErrorExpectation.fulfill() }
            
            XCTAssert(error is DummyError)
            
            catchCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelThenGroup() {
        
        let catchCalledExpectation = expectation(description: "Catch Called")
        
        let promise = Promise<Double>()
        promise.cancel(withIndirectError: DummyError.error)
        let rejectedFuture = promise.future
        
        // both tasks below should be cancelled with an indirect error
        // because the rejected future indirectly caused them to be cancelled
        
        let task1 = TestTask()
        let task1IndirectErrorExpectation = expectation(description: "Task 1 Indirect Error")
        
        let task2 = TestTask()
        let task2IndirectErrorExpectation = expectation(description: "Task 2 Indirect Error")
        
        rejectedFuture.then([task1, task2])
        .then { input -> [Double] in
            
            XCTFail()
            return input
        }
        .catch { (error) in
            
            XCTAssert(task1.isCancelled)
            XCTAssert(task1.isCancelled)
            
            task1.future.whenCancelled { error in XCTAssertNotNil(error); XCTAssert(error is DummyError); task1IndirectErrorExpectation.fulfill() }
            task2.future.whenCancelled { error in XCTAssertNotNil(error); XCTAssert(error is DummyError); task2IndirectErrorExpectation.fulfill() }
            
            XCTAssert(error is DummyError)
            
            catchCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Catch
    
    func testCatchIgnoringIndirectErrors() {
        
        // catch with normal error (ignoring indirect errors)
        let catchWithNormalErrorCalledExpectation = expectation(description: "Catch With Normal Error Called")
        let afterCatchWithNormalErrorCalledExpectation = expectation(description: "After Catch With Normal Called")
        
        let failedTask = TestTask()
        failedTask.fail(with: DummyError.error)
        
        failedTask.future
        .catch(includingIndirectErrors: false) { error in
                
            XCTAssert(error is DummyError)
            catchWithNormalErrorCalledExpectation.fulfill()
        }
        .whenRejected { error in
            
            XCTAssert(error is DummyError)
            afterCatchWithNormalErrorCalledExpectation.fulfill()
        }
        
        // catch with indirect error (ignoring indirect errors)
        let whenCancelledWithIndirectErrorCalledExpectation = expectation(description: "whenCancelled With Indirect Error Called")
        
        let cancelledTask = TestTask()
        cancelledTask.cancel(withIndirectError: DummyError.error)
        
        cancelledTask.future
        .catch(includingIndirectErrors: false) { _ in
                
            XCTFail()
        }
        .whenCancelled { error in
            
            XCTAssert(error is DummyError) // error should propagate
            whenCancelledWithIndirectErrorCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCatchIncludingIndirectErrors() {
        
        // catch with normal error (including indirect errors)
        let catchWithNormalErrorCalledExpectation = expectation(description: "Catch With Normal Error Called")
        let afterCatchWithNormalErrorCalledExpectation = expectation(description: "After Catch With Normal Error Called")
        
        let failedTask = TestTask()
        failedTask.fail(with: DummyError.error)
        
        failedTask.future
        .catch(includingIndirectErrors: true) { error in
                
            XCTAssert(error is DummyError)
            catchWithNormalErrorCalledExpectation.fulfill()
        }
        .whenRejected { error in
                
            XCTAssert(error is DummyError) // error should correctly propagate
            afterCatchWithNormalErrorCalledExpectation.fulfill()
        }
        
        // catch with indirect error (including indirect errors)
        let catchCalledWithIndirectErrorCalledExpectation = expectation(description: "Catch With Indirect Error Called")
        let afterCatchCalledWithIndirectErrorCalledExpectation = expectation(description: "After Catch With Indirect Error Called")
        
        let cancelledTask = TestTask()
        cancelledTask.cancel(withIndirectError: DummyError.error)
        
        cancelledTask.future
        .catch(includingIndirectErrors: true) { error in
                
            XCTAssert(error is DummyError)
            catchCalledWithIndirectErrorCalledExpectation.fulfill()
        }
        .whenCancelled { error in
                
            XCTAssert(error is DummyError) // error should propagate
            afterCatchCalledWithIndirectErrorCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testUncalledCatch() {
        
        let afterCatchCalledExpectation = expectation(description: "After Catch Called")
        
        start(running: TestTask(), with: 40)
        .then { input in
                
            return input + 1
        }
        .catch { (error) in
            
            XCTFail()
        }
        .then { (input) in
                
            XCTAssertEqual(input, 42)
            afterCatchCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Recover
    
    func testRecoverIgnoringIndirectErrors() {
        
        // recover with normal error (ignoring indirect errors)
        let recoverWithNormalErrorCalledExpectation = expectation(description: "Recover With Normal Error Called")
        let whenFulfilledCalledAfterNormalErrorExpectation = expectation(description: "whenFulfilled Called After Normal")
        
        let failedTask = TestTask()
        failedTask.fail(with: DummyError.error)
        
        failedTask.future
        .recover(includingIndirectErrors: false) { error in
                
            XCTAssert(error is DummyError)
            recoverWithNormalErrorCalledExpectation.fulfill()
            return 42
        }
        .whenFulfilled { result in
                
            XCTAssertEqual(result, 42)
            whenFulfilledCalledAfterNormalErrorExpectation.fulfill()
        }
        
        // recover with indirect error (ignoring indirect errors)
        let whenCancelledWithIndirectErrorCalledExpectation = expectation(description: "whenCancelled Called After Indirect Error")
        
        let cancelledTask = TestTask()
        cancelledTask.cancel(withIndirectError: DummyError.error)
        
        cancelledTask.future
        .recover(includingIndirectErrors: false) { _ in
                
            XCTFail()
            return 42
        }
        .whenCancelled { error in
                
            XCTAssert(error is DummyError) // error should propagate
            whenCancelledWithIndirectErrorCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testRecoverIncludingIndirectErrors() {
        
        // recover with normal error (including indirect errors)
        let recoverWithNormalErrorCalledExpectation = expectation(description: "Recover With Normal Error Called")
        let whenFulfilledCalledAfterNormalErrorExpectation = expectation(description: "whenFulfilled Called After Normal Error")
        
        let failedTask = TestTask()
        failedTask.fail(with: DummyError.error)
        
        failedTask.future
        .recover(includingIndirectErrors: true) { error in
                
            XCTAssert(error is DummyError)
            recoverWithNormalErrorCalledExpectation.fulfill()
            return 42
        }
        .whenFulfilled { result in
                
            XCTAssertEqual(result, 42)
            whenFulfilledCalledAfterNormalErrorExpectation.fulfill()
        }
        
        // recover with indirect error (including indirect errors)
        let recoverCalledWithIndirectErrorCalledExpectation = expectation(description: "Recover With Indirect Error Called")
        let whenFulfilledCalledAfterIndirectErrorExpectation = expectation(description: "whenFulfilled Called After Indirect Error")
        
        let cancelledTask = TestTask()
        cancelledTask.cancel(withIndirectError: DummyError.error)
        
        cancelledTask.future
        .recover(includingIndirectErrors: true) { error in
                
            XCTAssert(error is DummyError)
            recoverCalledWithIndirectErrorCalledExpectation.fulfill()
            return 42
        }
        .whenFulfilled { result in
                
            XCTAssertEqual(result, 42)
            whenFulfilledCalledAfterIndirectErrorExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testUnableToRecoverStatePropagation() {
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        let rejectedFuture = Promise<Void>(rejectedWith: DummyError.error).future
        let cancelledWithoutIndirectErrorFuture = Promise<Void>(cancelledWithIndirectError: nil).future
        let cancelledWithIndirectErrorFuture = Promise<Void>(cancelledWithIndirectError: DummyError.error).future
        
        let whenFulfilledExpectation = expectation(description: "When Fulfilled Called")
        let whenRejectedExpectation = expectation(description: "When Rejected Called")
        let whenCancelledWithoutIndirectErrorExpectation = expectation(description: "When Cancelled Without Indirect Error Called")
        let whenCancelledWithIndirectErrorExpectation = expectation(description: "When Cancelled With Indirect Error Called")
        
        // fulfilled
        fulfilledFuture
        .recover { error in

            XCTFail()
            return nil
        }
        .whenFulfilled { result in
            
            whenFulfilledExpectation.fulfill()
        }
        
        // rejected
        rejectedFuture
        .recover { error in
            
            XCTAssert(error is DummyError)
            return nil
        }
        .whenRejected { error in
            
            XCTAssert(error is DummyError)
            whenRejectedExpectation.fulfill()
        }
        
        // cancelled without indirect error
        cancelledWithoutIndirectErrorFuture
        .recover { _ in
            
            XCTFail()
            return nil
        }
        .whenCancelled { error in
            
            XCTAssertNil(error)
            whenCancelledWithoutIndirectErrorExpectation.fulfill()
        }
        
        cancelledWithIndirectErrorFuture
        .recover { error in
            
            XCTAssert(error is DummyError)
            return nil
        }
        .whenCancelled { error in
            
            XCTAssertNotNil(error)
            XCTAssert(error is DummyError)
            whenCancelledWithIndirectErrorExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testUncalledRecover() {
        
        let afterRecoverCalledExpectation = expectation(description: "After Recover Called")
        
        start(running: TestTask(), with: 41)
        .recover { _ -> Double in
                
            XCTFail()
            return 42
        }
        .then { input -> Void in
                
            afterRecoverCalledExpectation.fulfill()
            XCTAssertEqual(input, 42)
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRecoverWithDefaultValue() {
        
        let afterRecoverCalledExpectation = expectation(description: "After Recover Called")
        
        start(running: TestTask(), with: 40)
        .then { input throws -> Double in
                
            throw DummyError.error
        }
        .recover(using: 42)
        .then { input -> Void in
                
            afterRecoverCalledExpectation.fulfill()
            XCTAssertEqual(input, 42)
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRecoverWithCatch() {
        
        let recoverCalledExpectation = expectation(description: "Recover Called")
        let catchCalledExpectation = expectation(description: "Catch Called")
        let thenCalledExpectation = expectation(description: "Then Called")
        
        start(running: TestTask(), with: 41)
        .then { _ -> Double in
            
            throw DummyError.error
        }
        .catch { (error) -> Void in
            
            catchCalledExpectation.fulfill()
            XCTAssert(error is DummyError)
        }
        .recover { _ -> Double in
            
            recoverCalledExpectation.fulfill()
            return 42
        }
        .then { input -> Void in
            
            XCTAssertEqual(input, 42)
            thenCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRecoverThenCatch() {
        
        let recoverCalledExpectation = expectation(description: "Recover Called")
        let afterRecoverCalledExpectation = expectation(description: "After Recover Called")
        
        start(running: TestTask(), with: 40)
        .then { _ -> Double in
            
            throw DummyError.error
        }
        .recover { _ -> Double in
            
            recoverCalledExpectation.fulfill()
            return 42
        }
        .catch { (error) -> Void in
            
            XCTFail()
        }
        .then { input -> Void in
            
            afterRecoverCalledExpectation.fulfill()
            XCTAssertEqual(input, 42)
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Always
    
    func testAlwaysClosure() {
        
        let recoverCalledExpectation = expectation(description: "Recover Called")
        let alwaysCalledExpectation = expectation(description: "After Recover Called")
        let catchCalledExpectation = expectation(description: "Catch Called")
        
        
        start(running: TestTask(), with: 40)
        .then { _ -> Double in
            
            throw DummyError.error
        }
        .recover { _ -> Double? in
            
            recoverCalledExpectation.fulfill()
            return nil
        }
        .catch { (error) -> Void in
            
            catchCalledExpectation.fulfill()
            XCTAssert(error is DummyError)
        }
        .always {
            
            alwaysCalledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testAlwaysTask() {
        
        let recoverCalledExpectation = expectation(description: "Recover Called")
        let alwaysCalledExpectation = expectation(description: "After Recover Called")
        let catchCalledExpectation = expectation(description: "Catch Called")
        
        start(running: TestTask(), with: 40)
        .then { _ -> Double in
            
            throw DummyError.error
        }
        .recover { _ -> Double? in
            
            recoverCalledExpectation.fulfill()
            return nil
        }
        .catch { (error) -> Void in
            
            catchCalledExpectation.fulfill()
            XCTAssert(error is DummyError)
        }
        .always(execute: VoidTask(expectation: alwaysCalledExpectation))
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Resolving When & Group Chaining
    
    func testResolvingWhenGroups() {
        
        let when2Expectation = expectation(description: "When2 Expectation")
        let when3Expectation = expectation(description: "When3 Expectation")
        let when4Expectation = expectation(description: "When4 Expectation")
        let when5Expectation = expectation(description: "When5 Expectation")
        let when6Expectation = expectation(description: "When6 Expectation")
        
        func startTestTask() -> Future<Double> { return start(running: TestTask(), with: 1) }
        func startTestStringTask() -> Future<String> { return start(running: TestStringTask(), with: "Answer:") }
                
        Future.fulfillingWhen(startTestTask(), startTestStringTask()).then { result1, result2 in
            
            XCTAssertEqual(result1, 2)
            XCTAssertEqual(result2, "Answer: 42")
            
            when2Expectation.fulfill()
        }
        
        Future.fulfillingWhen(startTestTask(), startTestStringTask(), startTestTask()).then { result1, result2, result3 in
            
            XCTAssertEqual(result1, 2)
            XCTAssertEqual(result2, "Answer: 42")
            XCTAssertEqual(result3, 2)
            
            when3Expectation.fulfill()
        }
        
        Future.fulfillingWhen(startTestStringTask(), startTestTask(), startTestStringTask(), startTestStringTask()).then { result1, result2, result3, result4 in
            
            XCTAssertEqual(result1, "Answer: 42")
            XCTAssertEqual(result2, 2)
            XCTAssertEqual(result3, "Answer: 42")
            XCTAssertEqual(result4, "Answer: 42")
            
            when4Expectation.fulfill()
        }
        
        Future.fulfillingWhen(startTestTask(), startTestStringTask(), startTestTask(), startTestStringTask(), startTestTask()).then { result1, result2, result3, result4, result5 in
            
            XCTAssertEqual(result1, 2)
            XCTAssertEqual(result2, "Answer: 42")
            XCTAssertEqual(result3, 2)
            XCTAssertEqual(result4, "Answer: 42")
            XCTAssertEqual(result5, 2)
            
            when5Expectation.fulfill()
        }
        
        Future.fulfillingWhen(startTestTask(), startTestTask(), startTestStringTask(), startTestStringTask(), startTestTask(), startTestStringTask()).then { result1, result2, result3, result4, result5, result6 in
            
            XCTAssertEqual(result1, 2)
            XCTAssertEqual(result2, 2)
            XCTAssertEqual(result3, "Answer: 42")
            XCTAssertEqual(result4, "Answer: 42")
            XCTAssertEqual(result5, 2)
            XCTAssertEqual(result6, "Answer: 42")
            
            when6Expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testResolvingWhenTypeInference() {
        
        // there should be no build errors here.
        // the types of the returned futures should
        // be inferred.
        
        let fulfilledFuture = Promise(fulfilledWith: ()).future
        
        let _ = fulfilledFuture.then { _ in
            
            return .fulfillingWhen(Promise(fulfilledWith: ()).future, Promise(fulfilledWith: ()).future)
        }
        
        let _ = fulfilledFuture.then { _ in
            
            return .fulfillingWhen(Promise(fulfilledWith: "").future, Promise(fulfilledWith: ()).future, Promise(fulfilledWith: 42).future)
        }
        
        let _ = fulfilledFuture.then { _ in
            
            return .fulfillingWhen([Promise(fulfilledWith: ()).future, Promise(fulfilledWith: ()).future])
        }
    }
    
    func testThenGroup() {
        
        let group = [TestTask(), TestTask(), TestTask()]
        let finishExpectation = expectation(description: "Group Finished Expectation")
        
        start(running: TestTask(), with: 1)
            .then(group)
            .then { (output) in
                
                guard output == [3, 3, 3] else { XCTFail(); return }
                finishExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelOneFromGroup() {
        
        let group = [LongTestTask(), LongTestTask(), LongTestTask()]
        let errorExpectation = expectation(description: "Group Error Expectation")
        let cancelledExpectation = expectation(description: "Group Cancelled Expectation")
        
        start(running: TestTask(), with: 1)
            .then(group)
            .then { (output) in
                
                XCTFail()
            }
            .catch { (error) in
                
                var allCancelled = true
                group.forEach { if !$0.isCancelled { allCancelled = false } }
                
                XCTAssert(allCancelled)
                XCTAssert(error is DummyError)
                errorExpectation.fulfill()
            }
            .whenCancelled { (error) in
                
                XCTAssert(error is DummyError)
                cancelledExpectation.fulfill()
        }
        
        group[0].cancel(withIndirectError: DummyError.error)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelAllGroup() {
        
        let group = [LongTestTask(), LongTestTask(), LongTestTask()]
        let cancellationPool = CancellationPool()
        let cancelledExpectation = expectation(description: "Group Cancelled Expectation")
        
        start(running: TestTask(), with: 1)
            .then(group, using: cancellationPool)
            .then { (output) in
                
                XCTFail()
            }
            .catch { (error) in
                
                XCTFail()
            }
            .whenCancelled { (error) in
                
                var allCancelled = true
                group.forEach { if !$0.isCancelled { allCancelled = false } }
                XCTAssert(allCancelled)
                
                XCTAssert(error == nil)
                cancelledExpectation.fulfill()
        }
        
        cancellationPool.drain()
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testFailFromGroup() {
        
        let group = [LongTestTask(), FailingTestTask(), FailingTestTask()]
        let errorExpectation = expectation(description: "Group Error Expectation")
        let cancelledExpectation = expectation(description: "Group Cancelled Expectation")
        
        start(running: TestTask(), with: 1)
            .then(group)
            .then { (output) in
                
                XCTFail()
            }
            .catch { (error) in
                
                XCTAssert(group[0].isCancelled)
                
                XCTAssert(error is DummyError)
                errorExpectation.fulfill()
            }
            .whenCancelled { (error) in // whenCancelled because the closure-then's future will be cancelled with an indirect error
                
                XCTAssert(error is DummyError)
                cancelledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: - Additionally
    
    // MARK: Tasks
    
    func testFulfilledFutureThenAdditionalCompletingTask() {
        
        let finishedExpectation = expectation(description: "Finished Expectation")
        
        start(running: TestTask(), with: 41)
        .additionally(AdditionalTask())
        .then { (firstResult, secondResult) in
            
            XCTAssertEqual(firstResult, 42)
            XCTAssertEqual(secondResult, "Answer: 42")
            
            finishedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRejectedFutureThenAdditionalCompletingTask() {
        
        let whenCancelledCalled = expectation(description: "Task When Cancelled Called")
        let whenRejectedCalled = expectation(description: "Additionally Future When Rejected Called")
        
        let rejectedFuture = Promise<Void>(rejectedWith: DummyError.error).future
        
        let task = VoidTask()
        task.future.whenCancelled { indirectError in
            
            XCTAssertNotNil(indirectError)
            XCTAssert(indirectError is DummyError)
            whenCancelledCalled.fulfill()
        }
        
        rejectedFuture
        .additionally(task)
        .whenRejected { error in
            
            XCTAssert(error is DummyError)
            whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testCancelledFutureThenAdditionalCompletingTask() {
        
        let taskWhenCancelledCalled = expectation(description: "Task When Cancelled Called")
        let additionallyWhenCancelledCalled = expectation(description: "Additionally Future When Cancelled Called")
        
        let cancelledFuture = Promise<Void>(cancelledWithIndirectError: DummyError.error).future
        
        let task = VoidTask()
        task.future.whenCancelled { indirectError in
            
            XCTAssertNotNil(indirectError)
            XCTAssert(indirectError is DummyError)
            taskWhenCancelledCalled.fulfill()
        }
        
        cancelledFuture
        .additionally(task)
        .whenCancelled { indirectError in
            
            XCTAssertNotNil(indirectError)
            XCTAssert(indirectError is DummyError)
            additionallyWhenCancelledCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilledFutureThenAdditionalFailingTask() {
        
        let whenRejectedCalled = expectation(description: "When Rejected Called")
        
        let fulfilledFuture = Promise<Void>(fulfilledWith: ()).future
        
        let task = FailingTask()
        
        fulfilledFuture
        .additionally(task)
        .whenRejected { error in
            
                XCTAssert(error is DummyError)
                whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilledFutureThenAdditionalCancellingTask() {
        
        let whenCancelledCalled = expectation(description: "When Cancelled Called")
        
        let fulfilledFuture = Promise<Double>(fulfilledWith: 42).future
        
        let task = LongTestTask()
        
        fulfilledFuture
        .additionally(task)
        .whenCancelled { indirectError in
                
            XCTAssert(indirectError is DummyError)
            whenCancelledCalled.fulfill()
        }
        
        task.cancel(withIndirectError: DummyError.error)
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    // MARK: Closures
    
    func testFulfilledFutureThenAdditionalResultReturningClosure() {
        
        let finishedExpectation = expectation(description: "Finished Expectation")
        
        start(running: TestTask(), with: 41)
        .additionally { result in
            
            return "Answer: \(Int(result))"
        }
        .then { (firstResult, secondResult) in
            
            XCTAssertEqual(firstResult, 42)
            XCTAssertEqual(secondResult, "Answer: 42")
            
            finishedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelledFutureThenAddionalResultReturningClosure() {
        
        let whenCancelledCalled = expectation(description: "When Cancelled Called")
        
        let cancelledFuture = Promise<Void>(cancelledWithIndirectError: DummyError.error).future
        
        cancelledFuture
        .additionally { _ -> Void in
            
            XCTFail()
            return ()
        }
        .whenCancelled { indirectError in
                
            XCTAssert(indirectError is DummyError)
            whenCancelledCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testRejectedFutureThenAddionalResultReturningClosure() {
        
        let whenRejectedCalled = expectation(description: "When Rejected Called")
        
        let rejectedFuture = Promise<Void>(rejectedWith: DummyError.error).future
        
        rejectedFuture
        .additionally { () -> Void in
            
            XCTFail()
            return ()
        }
        .whenRejected { error in
                
            XCTAssert(error is DummyError)
            whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilledFutureThenAdditionalThrowingClosure() {
        
        let whenRejectedCalled = expectation(description: "When Rejected Called")
        
        let fulfilledFuture = Promise<Void>(fulfilledWith: ()).future
        
        fulfilledFuture
        .additionally { () -> Void in throw DummyError.error }
        .whenRejected { error in
            
                XCTAssert(error is DummyError)
                whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    // MARK: Futures
    
    func testFulfilledFutureThenAdditionalFulfilledFutureReturningClosure() {
        
        let finishedExpectation = expectation(description: "Finished Expectation")
        start(running: TestTask(), with: 41)
        .additionally { (result) -> Future<String> in
            
            let promise = Promise<String>()
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(1)) {
                
                promise.fulfil(with: "Answer: \(Int(result))")
            }
            
            return promise.future
        }
        .then { (firstResult, secondResult) in
            
            XCTAssertEqual(firstResult, 42)
            XCTAssertEqual(secondResult, "Answer: 42")
            
            finishedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRejectedFutureThenAdditionalFulfilledFutureReturningClosure() {
        
        let whenRejectedCalled = expectation(description: "When Rejected Called")
        
        let rejectedFuture = Promise<Void>(rejectedWith: DummyError.error).future
        
        rejectedFuture
        .additionally { result -> Future<Void> in
            
            XCTFail()
            return Promise(fulfilledWith: ()).future
        }
        .whenRejected { error in
                
                XCTAssert(error is DummyError)
                whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testCancelledFutureThenAdditionalFulfilledFutureReturningClosure() {
        
        let whenCancelledCalled = expectation(description: "When Cancelled Called")
        
        let cancelledFuture = Promise<Void>(cancelledWithIndirectError: DummyError.error).future
        
        cancelledFuture
        .additionally { result -> Future<Void> in
                
            XCTFail()
            return Promise(fulfilledWith: ()).future
        }
        .whenCancelled { indirectError in
                
            XCTAssert(indirectError is DummyError)
            whenCancelledCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilledFutureThenAdditionalRejectedFutureReturningClosure() {
        
        let whenRejectedCalled = expectation(description: "When Rejected Called")
        
        let fulfilledFuture = Promise<Void>(fulfilledWith: ()).future
        
        fulfilledFuture
        .additionally { result -> Future<Void> in
            
            return Promise(rejectedWith: DummyError.error).future
        }
        .whenRejected { error in
                
            XCTAssert(error is DummyError)
            whenRejectedCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFulfilledFutureThenAdditionalCancelledFutureReturningClosure() {
        
        let whenCancelledCalled = expectation(description: "When Cancelled Called")
        
        let fulfilledFuture = Promise<Void>(fulfilledWith: ()).future
        
        fulfilledFuture
        .additionally { result -> Future<Void> in
                
            return Promise(cancelledWithIndirectError: DummyError.error).future
        }
        .whenCancelled { indirectError in
                
            XCTAssert(indirectError is DummyError)
            whenCancelledCalled.fulfill()
        }
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
}
