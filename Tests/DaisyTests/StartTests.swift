//
//  Start.swift
//  Daisy
//
//  Created by Alasdair Baxter on 10/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import XCTest
@testable import Daisy

class StartTests: XCTestCase {
    
    // MARK: Starting Tasks
    
    func testStartTask() {
        
        let task = TestTask()
        let finishExpectation = expectation(description: "Task Finished")
        task.future.whenResolved { (resolvedState) in
            
            guard case .fulfilled = resolvedState else {
                
                XCTFail()
                return
            }
            
            finishExpectation.fulfill()
        }
        
        start(running: task, with: 1)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSpecializedVoidStartTask() {
        
        let task = VoidTask()
        let finishExpectation = expectation(description: "Task Finished")
        task.future.whenResolved { (resolvedState) in
            
            guard case .fulfilled = resolvedState else {
                
                XCTFail()
                return
            }
            
            finishExpectation.fulfill()
        }
        
        start(running: task)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFailTask() {
        
        let task = FailingTask()
        let failExpectation = expectation(description: "Task Failed")
        task.future.whenResolved { (resolvedState) in
            
            guard case .rejected(error: let error) = resolvedState else {
                
                XCTFail()
                return
            }
            
            XCTAssert(error is DummyError)
            
            failExpectation.fulfill()
        }
        
        start(running: task, with: ())
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testCancelTask() {
        
        let task = TestTask()
        let cancelExpectation = expectation(description: "Task Cancelled")
        task.future.whenResolved { (resolvedState) in
            
            guard case .cancelled(indirectError: let error) = resolvedState else {
                
                XCTFail()
                return
            }
            
            XCTAssert(error is DummyError)
            
            cancelExpectation.fulfill()
        }
        
        start(running: task, with: 42)
        task.cancel(withIndirectError: DummyError.error)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    // MARK: Task Start Race Conditions
    
    /*
    // disabled
    func testStartCancelRace() {
        
        for _ in 0..<10 {
            
            let wasCancelledCalledExpectation = expectation(description: "WasCancelled Called")
            
            let task = CancelRaceTestTask {
                
                wasCancelledCalledExpectation.fulfill()
            }
            
            let cancelExpectation = expectation(description: "Task Cancelled")
            task.future.whenResolved { (resolvedState) in
                
                guard case .cancelled(indirectError: let error) = resolvedState else {
                    
                    XCTFail()
                    return
                }
                
                XCTAssert(error is DummyError)
                
                cancelExpectation.fulfill()
            }
            
            start(running: task, with: ())
            task.cancel(withIndirectError: DummyError.error)
            
            let sema = DispatchSemaphore(value: 0)
            
            waitForExpectations(timeout: 2, handler: { (_) in
                
                sema.signal()
            })
            
            sema.wait()
        }
    }
    
    // disabled
    func testStartRunningStartWithRace() {
        
        for index in 0..<1000 {
            
            let task = TestTask()
            let finishedExpectation = expectation(description: "Task Cancelled")
            task.future.whenResolved { (resolvedState) in
                
                guard case .fulfilled(result: let result) = resolvedState else {
                    
                    XCTFail()
                    return
                }
                
                if result == Double(index + 1) {
                    
                    XCTAssertTrue(true)
                }
                    
                else if result == (Double(index + 1) + 0.1) {
                    
                    XCTAssertTrue(true)
                }
                    
                else { XCTFail() }
                
                finishedExpectation.fulfill()
            }
            
            // some warnings for starting a task while _ will be printed. Some of these are for the tasks where start(running:) actually
            // manages to  call start(with:) first, and the second call is generating a warning.
            // The others are for instaces where the second call is making it through in the gap between attemptStart's state check and start(with:)
            // call.
            // both a fine as both warrant a warning being printed. The key s that there should be no 'attempting to complete a task' warnings.
            // mostly, though, the second call goes through first, and then the attempt call does its state checks, find the Task has finished,
            // and does nothing (so no message is printed)
            start(running: task, with: Double(index))
            task.start(with: Double(index) + 0.1)
            
            let sema = DispatchSemaphore(value: 0)
            
            waitForExpectations(timeout: 3, handler: { (_) in
                
                sema.signal()
            })
            
            sema.wait()
        }
    }
    */
    
    // MARK: Group Cancellation
    
    func testCancelCollectionOfTasks() {
        
        let cancellationPool = CancellationPool()
        let tasks = [LongTestTask(), LongTestTask(), LongTestTask()]
        let expectations = [expectation(description: "Task 1 Cancelled"),
                            expectation(description: "Task 2 Cancelled"),
                            expectation(description: "Task 3 Cancelled")]
        
        tasks.enumerated().forEach { (index, task) in
            
            task.future.whenCancelled { (_) in
                
                expectations[index].fulfill()
            }
            
            start(running: task, with: 42, using: cancellationPool)
        }
        
        cancellationPool.drain()
        
        waitForExpectations(timeout: 3) { (_) in
            
            XCTAssert(tasks[0].isCancelled && tasks[1].isCancelled && tasks[2].isCancelled)
        }
    }
    
    // MARK: Starting Closures
    
    func testStartWithClosure() {
        
        let runExpectation = expectation(description: "Closure Run")
        let futureFulfilledExpectation = expectation(description: "Future Fulfilled")
        
        start(on: .global(qos: .utility)) {
            
            self.dispatchPreconditionOnQueue(.global(qos: .utility))
            
            runExpectation.fulfill()
            
        }
        .whenFulfilled {
            
            futureFulfilledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testStartWithRejectingClosure() {
        
        let runExpectation = expectation(description: "Closure Run")
        let futureRejectedExpectation = expectation(description: "Future Fulfilled")
        
        start(on: .global(qos: .utility)) {
            
            self.dispatchPreconditionOnQueue(.global(qos: .utility))
            
            runExpectation.fulfill()
            
            throw DummyError.error
            
        }
        .whenRejected { error in
            
            XCTAssert(error is DummyError)
            futureRejectedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    // MARK: Starting Groups
    
    func testStartGroup() {
        
        let group = [TestTask(), TestTask(), TestTask()]
        let finishExpectation = expectation(description: "Group Finished Expectation")
        
        start(running: group, with: 1).then { (output) in
            
            guard output == [2, 2, 2] else { XCTFail(); return }
            finishExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCancelOneFromGroup() {
        
        let group = [LongTestTask(), LongTestTask(), LongTestTask()]
        let errorExpectation = expectation(description: "Group Error Expectation")
        let cancelledExpectation = expectation(description: "Group Cancelled Expectation")
        
        start(running: group, with: 1).then { (output) in
            
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
        
        start(running: group, with: 1, using: cancellationPool).then { (output) in
            
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
        
        // LongTestTask so that, for the purposes of this test, we can be sure that
        // the task will not have finished before one of the failing tasks has failed
        let group = [LongTestTask(), FailingTestTask(), FailingTestTask()]
        let errorExpectation = expectation(description: "Group Error Expectation")
        let cancelledExpectation = expectation(description: "Group Cancelled Expectation")
        let task0IndirectErrorExpectation = expectation(description: "Task 0 Indirect Error")
        
        start(running: group, with: 1)
        .then { (output) in
            
            XCTFail()
        }
        .catch { (error) in
            
            XCTAssert(group[0].isCancelled)
            // group[0] should be cancelled with an indirect error because it was cancelled due to one of the other tasks
            // failing
            group[0].future.whenCancelled { error in
                
                XCTAssertNotNil(error)
                XCTAssert(error is DummyError)
                task0IndirectErrorExpectation.fulfill()
            }
            
            XCTAssert(error is DummyError)
            errorExpectation.fulfill()
        }
        .whenCancelled { (error) in // whenCancelled because the closure-then's future will be cancelled with an indirect error due to the failing tasks
            
            XCTAssert(error is DummyError)
            cancelledExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}

// MARK: - Test Tasks

final class TestTask: Task<Double, Double> {
    
    override func start(with input: Double) {
        
        guard preStart() else { return }
        
        //sleep(1)
        //print("TestTask started with \(input)")
        if !isCancelled {
            
            complete(with: input + 1)
        }
    }
}

final class TestStringTask: Task<String, String> {
    
    override func start(with input: String) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            complete(with: input + " 42")
        }
    }
}

final class FailingTestTask: Task<Double, Double> {
    
    override func start(with input: Double) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            fail(with: DummyError.error)
        }
    }
}

final class LongTestTask: Task<Double, Double> {
    
    override func start(with input: Double) {
        
        guard preStart() else { return }
        
        sleep(1)
        
        if !isCancelled {
            
            complete(with: input + 1)
        }
    }
}

final class CancelRaceTestTask: Task<Void, Void> {
    
    let wasCancelledClosure: () -> Void
    
    init(wasCancelledClosure: @escaping () -> Void) {
        
        self.wasCancelledClosure = wasCancelledClosure
    }
    
    override func start(with input: Void) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            complete(with: ())
        }
    }
    
    override func wasCancelled(with indirectError: Error?) {
        
        wasCancelledClosure()
    }
}

final class VoidTask: Task<Void, Void> {
    
    let expectation: XCTestExpectation?
    
    override init() {
        
        self.expectation = nil
        
        super.init()
    }
    
    init(expectation: XCTestExpectation) {
        
        self.expectation = expectation
        
        super.init()
    }
    
    override func start(with input: Void) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            expectation?.fulfill()
            complete(with: ())
        }
    }
}

final class FailingTask: Task<Void, Void> {
    
    override func start(with input: Void) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            fail(with: DummyError.error)
        }
    }
}

final class AdditionalTask: Task<Double, String> {
    
    override func start(with input: Double) {
        
        guard preStart() else { return }
        
        if !isCancelled {
            
            complete(with: "Answer: \(Int(input))")
        }
    }
}
