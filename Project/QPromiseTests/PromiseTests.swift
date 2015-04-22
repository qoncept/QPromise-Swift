import UIKit
import XCTest

import QPromise

class PromiseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func asyncSucceed(value: Int) -> Promise<Int> {
		return Promise<Int>({ (fulfill, reject, resolve) in
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
				fulfill(value + 1)
				return
			}
		})
	}
	
	func asyncFail(reason: NSError) -> Promise<Int> {
		return Promise<Int>({ (fulfill, reject, resolve) in
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
				reject(reason)
				return
			}
		})
	}
	
    func testThen() {
		let error = NSError()
		var reached: Bool

		reached = false
		asyncSucceed(0).then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 1, "")
			reached = true
			return Promise<Void>.fulfill()
		}, { reason -> Promise<Void> in
			XCTFail("Never reaches here.")
			return Promise<Void>.reject(reason)
		}).wait()
		XCTAssert(reached, "")
		
		reached = false
		asyncFail(error).then ({ value -> Promise<Void> in
			XCTFail("Never reaches here.")
			return Promise<Void>.fulfill()
		}, { reason -> Promise<Void>? in
			XCTAssertEqual(reason, error, "")
			reached = true
			return nil
		}).wait()
		XCTAssert(reached, "")
    }
	
	func testCatch() {
		let error = NSError()
		var reach: Int

		asyncSucceed(0).catch { reason -> Promise<Int>? in
			XCTFail("Never reaches here.")
			return nil
		}.wait()

		reach = 0
		asyncFail(error).catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return nil
		}.wait()
		XCTAssertEqual(reach, 1, "")
		
		// fall through
		reach = 0
		asyncFail(error).catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return nil
		}.catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return nil
		}.wait()
		XCTAssertEqual(reach, 2, "")
		
		// recovery
		reach = 0
		asyncFail(error).catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return self.asyncSucceed(100)
		}.then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 101, "")
			reach++
			return Promise<Void>.fulfill()
		}).wait()
		XCTAssertEqual(reach, 2, "")
		
		// new reason
		let error2 = NSError()
		reach = 0
		asyncFail(error).catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return self.asyncFail(error2)
		}.catch { reason -> Promise<Int>? in
			XCTAssertNotEqual(reason, error, "")
			XCTAssertEqual(reason, error2, "")
			reach++
			return nil
		}.wait()
		XCTAssertEqual(reach, 2, "")
	}
	
	func testFinally() {
		let error = NSError()
		let error2 = NSError()
		var reach: Int
		
		reach = 0
		asyncSucceed(1).finally { () -> Void in
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 1, "")

		reach = 0
		asyncFail(NSError()).finally { () -> Void in
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 1, "")
		
		// value fall through
		reach = 0
		asyncSucceed(0).finally { () -> Void in
			reach++
			return
		}.then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 1, "")
			reach++
			return Promise<Void>.fulfill()
		}).wait()
		XCTAssertEqual(reach, 2, "")
		
		// update value
		reach = 0
		asyncSucceed(0).finally { () -> Promise<Int>? in
			reach++
			return self.asyncSucceed(100)
		}.then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 101, "")
			reach++
			return Promise<Void>.fulfill()
		}).wait()
		XCTAssertEqual(reach, 2, "")

		// recovery
		reach = 0
		asyncFail(error).finally { () -> Promise<Int>? in
			reach++
			return self.asyncSucceed(100)
		}.then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 101, "")
			reach++
			return Promise<Void>.fulfill()
		}).wait()
		XCTAssertEqual(reach, 2, "")

		// reason fall through
		reach = 0
		asyncFail(error).finally { () -> Void in
			reach++
			return
		}.catch { reason -> Void in
			XCTAssertEqual(reason, error, "")
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 2, "")
		
		// new reason
		reach = 0
		asyncFail(error).finally { () -> Promise<Int>? in
			reach++
			return self.asyncFail(error2)
		}.catch { reason -> Promise<Int>? in
			XCTAssertNotEqual(reason, error, "")
			XCTAssertEqual(reason, error2, "")
			reach++
			return nil
		}.wait()
		XCTAssertEqual(reach, 2, "")
		
		// make fail
		reach = 0
		asyncSucceed(0).finally { () -> Promise<Int>? in
			reach++
			return self.asyncFail(error)
		}.catch { reason -> Promise<Int>? in
			XCTAssertEqual(reason, error, "")
			reach++
			return nil
		}.wait()
		XCTAssertEqual(reach, 2, "")
	}
	
	func testThenCatchAndFinally() {
		let error = NSError()
		var reach: Int

		reach = 0
		asyncSucceed(0).then ({ value -> Promise<Int> in
			XCTAssertEqual(value, 1, "")
			reach++
			return self.asyncSucceed(value)
		}).then ({ value -> Promise<Int> in
			XCTAssertEqual(value, 2, "")
			reach++
			return self.asyncSucceed(value)
		}).then ({ value -> Void in
			XCTAssertEqual(value, 3, "")
			reach++
			return
		}).catch { reason -> Void in
			XCTFail("Never reaches here.")
			return
		}.finally { () -> Void in
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 4, "")
		
		reach = 0
		asyncFail(error).then ({ value -> Promise<Int> in
			XCTFail("Never reaches here.")
			return self.asyncSucceed(value)
		}).then ({ value -> Promise<Int> in
			XCTFail("Never reaches here.")
			return self.asyncSucceed(value)
		}).then ({ value -> Promise<Void> in
			XCTFail("Never reaches here.")
			return Promise<Void>.fulfill()
		}).catch { reason -> Void in
			reach++
			XCTAssertEqual(reason, error, "")
			return
		}.finally { () -> Void in
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 2, "")
		
		reach = 0
		asyncFail(error).then ({ value -> Promise<Int> in
			XCTFail("Never reaches here.")
			return self.asyncSucceed(value)
		}).then ({ value -> Promise<Int> in
			XCTFail("Never reaches here.")
			return self.asyncSucceed(value)
		}, { reason in
			XCTAssertEqual(reason, error, "")
			reach++
			return self.asyncSucceed(100)
		}).then ({ value -> Promise<Void> in
			XCTAssertEqual(value, 101, "")
			reach++
			return Promise<Void>.fulfill()
		}).catch { reason -> Void in
			XCTFail("Never reaches here.")
			return
		}.finally { () -> Void in
			reach++
			return
		}.wait()
		XCTAssertEqual(reach, 3, "")
	}
	
	func testThenOverload() {
		let error = NSError()
		
		//	then<U>(onFulfilled: (T) -> Promise<U>, _ onRejectedOrNil: ((NSError) -> Promise<U>?)? = nil)
		//	onRejectedOrNil is nil
		let pr1 = asyncSucceed(0)
			.then { value in
				return Promise<Void>.fulfill()
		}
		pr1.wait()
		
		//	then<U>(onFulfilled: (T) -> Promise<U>, _ onRejectedOrNil: ((NSError) -> Promise<U>?)? = nil)
		//	onRejectedOrNil is not nil
		let pr2 = asyncSucceed(0)
			.then ({ value in
				return Promise<Void>.fulfill()
				}, { error in
					return nil
			})
		pr2.wait()
		
		//	then(onFulfilled: (T) -> Void, _ onRejectedOrNil: ((NSError) -> Promise<Void>)? = nil)
		//	onRejectedOrNil is nil
		let pr3 = asyncSucceed(0)
			.then { value in
				return
		}
		pr3.wait()
		
		//	then(onFulfilled: (T) -> Void, _ onRejectedOrNil: ((NSError) -> Promise<Void>)? = nil)
		//	onRejectedOrNil is not nil
		let pr4 = asyncSucceed(0)
			.then ({ value in
				return
				}, { error in
					return Promise<Void>.reject(NSError(domain: "HogeDomain", code: 1, userInfo: nil))
			})
		pr4.wait()
	}

}

extension Promise {
	func wait() {
		var finished = false
		
		self.finally {
			finished = true
		}
		
		while (!finished){
			NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
		}
	}
}