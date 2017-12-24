//
//  CancellationPoolTests.swift
//  Daisy
//
//  Created by Alasdair Baxter on 18/01/2017.
//  Copyright © 2017 Alasdair Baxter. All rights reserved.
//

import XCTest
@testable import Daisy

class CancellationPoolTests: XCTestCase {
    
    func testPoolAddAndDrain() {
        
        let task1 = Task<Double, Double>()
        let task2 = Task<Double, Double>()
        
        let task1CancelledExpectation = expectation(description: "Task 1 Cancelled")
        let task2CancelledExpectation = expectation(description: "Task 2 Cancelled")
        
        task1.future.whenResolved { (resolvedState) in
            
            guard case .cancelled = resolvedState else {
                
                XCTFail()
                return
            }
            
            task1CancelledExpectation.fulfill()
        }
        
        task2.future.whenResolved { (resolvedState) in
            
            guard case .cancelled = resolvedState else {
                
                XCTFail()
                return
            }
            
            task2CancelledExpectation.fulfill()
        }
        
        let cancellationPool = CancellationPool()
        cancellationPool.add(task1)
        cancellationPool.add(task2)
        
        cancellationPool.drain()
        
        waitForExpectations(timeout: 3) { (_) in
            
            XCTAssert(task1.isCancelled && task2.isCancelled)
        }
    }
    
    func testAddContentsOfAndDrain() {
        
        let task1 = Task<Double, Double>()
        let task2 = Task<Double, Double>()
        
        let task1CancelledExpectation = expectation(description: "Task 1 Cancelled")
        let task2CancelledExpectation = expectation(description: "Task 2 Cancelled")
        
        task1.future.whenResolved { (resolvedState) in
            
            guard case .cancelled = resolvedState else {
                
                XCTFail()
                return
            }
            
            task1CancelledExpectation.fulfill()
        }
        
        task2.future.whenResolved { (resolvedState) in
            
            guard case .cancelled = resolvedState else {
                
                XCTFail()
                return
            }
            
            task2CancelledExpectation.fulfill()
        }
        
        let cancellationPool = CancellationPool()
        cancellationPool.add(contentsOf: [task1, task2])
        
        cancellationPool.drain()
        
        waitForExpectations(timeout: 3) { (_) in
            
            XCTAssert(task1.isCancelled && task2.isCancelled)
        }
    }
    
    func testNonTaskCancellation() {
        
        let pool = CancellationPool()
        
        let testCancellable = TestCancellable()
        
        pool.add(testCancellable)
        
        pool.drain()
        
        XCTAssert(testCancellable.isCancelled)
    }
}

private class TestCancellable: Cancellable {
    
    private(set) var isCancelled = false
    
    func attemptCancel() {
        
        isCancelled = true
    }
}
