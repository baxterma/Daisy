//
//  TaskTests.swift
//  DaisyTests
//
//  Created by Alasdair Baxter on 18/06/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import XCTest
@testable import Daisy

class TaskTests: XCTestCase {
    
    // MARK: Enqueuing Tasks
    
    func testSetEnqueuedStateCheck() {
        
        let task = TestTask()
        
        task.setEnqueued()
        
        XCTAssert(task.isEnqueued)
        XCTAssert(!task.isPending)
        XCTAssert(!task.isExecuting)
        XCTAssert(!task.isFinished)
        XCTAssert(!task.isFailed)
        XCTAssert(!task.isCancelled)
        XCTAssert(!task.isCompleted)
    }
    
    func testIsEnqueued() {
        
        let task = TestTask()
        
        start(running: LongTestTask(), with: 42)
        .then(task)
        
        XCTAssert(task.isEnqueued)
    }
    
    // MARK: State Checks
    
    func testExecutionStateChecks() {
        
        let completingTask = LongTestTask()
        
        XCTAssert(completingTask.isPending)
        XCTAssert(!completingTask.isExecuting)
        XCTAssert(!completingTask.isFinished)
        XCTAssert(!completingTask.isFailed)
        XCTAssert(!completingTask.isCancelled)
        XCTAssert(!completingTask.isCompleted)
        XCTAssert(!completingTask.isEnqueued)
        
        start(running: completingTask, with: 42)
        
        let waitSemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(10)) {
            
            XCTAssert(!completingTask.isPending)
            XCTAssert(completingTask.isExecuting)
            XCTAssert(!completingTask.isFinished)
            XCTAssert(!completingTask.isFailed)
            XCTAssert(!completingTask.isCancelled)
            XCTAssert(!completingTask.isCompleted)
            XCTAssert(!completingTask.isEnqueued)
            
            waitSemaphore.signal()
        }
        
        waitSemaphore.wait()
    }
    
    func testFailingTaskStateChecks() {
        
        let failingTask = FailingTestTask()
        let failingTaskExpectation = expectation(description: "Failing task completed")
        
        start(running: failingTask, with: 42)
        .whenRejected { _ in
                
            failingTaskExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 2) { _ in
            
            XCTAssert(!failingTask.isPending)
            XCTAssert(!failingTask.isExecuting)
            XCTAssert(failingTask.isFinished)
            XCTAssert(failingTask.isFailed)
            XCTAssert(!failingTask.isCancelled)
            XCTAssert(!failingTask.isCompleted)
            XCTAssert(!failingTask.isEnqueued)
        }
    }
    
    func testCancelledTaskStateChecks() {
        
        let task = LongTestTask()
        let taskCancelledExpectation = expectation(description: "Task cancelled")
        
        start(running: task, with: 42)
        .whenCancelled { _ in
                
            taskCancelledExpectation.fulfill()
        }
        
        task.cancel()
        
        waitForExpectations(timeout: 2) { _ in
            
            XCTAssert(!task.isPending)
            XCTAssert(!task.isExecuting)
            XCTAssert(task.isFinished)
            XCTAssert(!task.isFailed)
            XCTAssert(task.isCancelled)
            XCTAssert(!task.isCompleted)
            XCTAssert(!task.isEnqueued)
        }
    }
    
    func testCompletingTaskStateChecks() {
        
        let completingTask = LongTestTask()
        let completingTaskExpectation = expectation(description: "Completing task completed")
        
        start(running: completingTask, with: 42)
        .then { _ in
                
            completingTaskExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 2) { _ in
            
            XCTAssert(!completingTask.isPending)
            XCTAssert(!completingTask.isExecuting)
            XCTAssert(completingTask.isFinished)
            XCTAssert(!completingTask.isFailed)
            XCTAssert(!completingTask.isCancelled)
            XCTAssert(completingTask.isCompleted)
            XCTAssert(!completingTask.isEnqueued)
        }
    }
    
    // MARK: Multiple Finish
    
    func testTaskMultipleFinish() {
        
        // completed
        
        let whenFulfilledCalledExpectation = expectation(description: "When Fulfilled Called Expectation")
        
        let completed = TestTask()
        completed.complete(with: 42)
        completed.complete(with: 43)
        completed.fail(with: DummyError.error)
        completed.cancel(withIndirectError: DummyError.error)
        
        completed.future.whenFulfilled { result in
            
            XCTAssertEqual(result, 42)
            whenFulfilledCalledExpectation.fulfill()
        }
        
        XCTAssert(completed.isCompleted)
        
        // failed
        
        let whenRejectedCalledExpectation = expectation(description: "When Rejected Called Expectation")
        
        let failed = TestTask()
        failed.fail(with: DummyError.error)
        failed.fail(with: NSError.makeDaisyTestError())
        failed.complete(with: 42)
        failed.cancel(withIndirectError: DummyError.error)
        
        failed.future.whenRejected { error in
            
            XCTAssert(error is DummyError)
            whenRejectedCalledExpectation.fulfill()
        }
        
        XCTAssert(failed.isFailed)
        
        // cancelled
        
        let whenCancelledCalledExpectation = expectation(description: "When Cancelled Called Expectation")
        
        let cancelled = TestTask()
        cancelled.cancel(withIndirectError: DummyError.error)
        cancelled.cancel(withIndirectError: NSError.makeDaisyTestError())
        cancelled.fail(with: DummyError.error)
        cancelled.complete(with: 42)
        
        cancelled.future.whenCancelled { error in
            
            XCTAssertNotNil(error)
            XCTAssert(error is DummyError)
            whenCancelledCalledExpectation.fulfill()
        }
        
        XCTAssert(cancelled.isCancelled)
        
        waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    // MARK: PreStart
    
    func testPreStartReturnValue() {
        
        let pending = TestTask()
        XCTAssertTrue(pending.preStart())
        
        let enqueued = TestTask()
        enqueued.setEnqueued()
        XCTAssertTrue(enqueued.preStart())
        
        let executing = LongTestTask()
        executing.start(with: 42)
        XCTAssertFalse(executing.preStart())
        
        let failed = TestTask()
        failed.fail(with: DummyError.error)
        XCTAssertFalse(failed.preStart())
        
        let cancelled = TestTask()
        cancelled.cancel(withIndirectError: DummyError.error)
        XCTAssertFalse(cancelled.preStart())
        
        let completed = TestTask()
        completed.complete(with: 42)
        XCTAssertFalse(completed.preStart())
    }
}
