import Foundation

public class Promise<T> {
	private var result: PromiseResult<T>?
	
	private var fulfilledHandlers: [(T) -> Void]
	private var rejectedHandlers: [(NSError) -> Void]
	
	public init(_ executor: (fulfill: (T) -> Void, reject: (NSError) -> Void, resolve: (Promise<T>) -> Void) -> Void) {
		fulfilledHandlers = []
		rejectedHandlers = []
		
		executor(fulfill: fulfill, reject: reject, resolve: resolve)
	}

	private convenience init() {
		self.init({ (fulfill, reject, resolve) in })
	}

	public var settled: Bool {
		return result != nil
	}
	
	private func fulfill(value: T) {
		if settled {
			fatalError("Illegal state.")
		}

		result = .Fulfilled(Container(value))
		
		for handler in fulfilledHandlers {
			handler(value)
		}
		
		clearHandlers()
	}
	
	private func reject(reason: NSError) {
		if settled {
			fatalError("Illegal state.")
		}

		result = .Rejected(reason)
		
		for handler in rejectedHandlers {
			handler(reason)
		}
		
		clearHandlers()
	}
	
	private func resolve(promise: Promise<T>) {
		promise.`defer`({
			self.fulfill($0)
		}, {
			self.reject($0)
		})
	}
	
	private func clearHandlers() {
		fulfilledHandlers = []
		rejectedHandlers = []
	}
	
	private func `defer`(fulfilledHandler: (T) -> Void, _ rejectedHandler: (NSError) -> Void) {
		if let result = self.result {
			switch result {
			case .Fulfilled(let value):
				fulfilledHandler(value.value)
			case .Rejected(let reason):
				rejectedHandler(reason)
			}
			
			return
		}
		
		self.fulfilledHandlers.append(fulfilledHandler)
		self.rejectedHandlers.append(rejectedHandler)
	}

	public func then<U>(onFulfilled: (T) -> Promise<U>) -> Promise<U> {
		return then(onFulfilled, nil)
	}
	
	public func then<U>(onFulfilled: (T) -> Promise<U>, _ onRejectedOrNil: ((NSError) -> Promise<U>?)?) -> Promise<U> {
		let promise = Promise<U>()
		
		`defer`({
			promise.resolve(onFulfilled($0))
		}, {
			onRejectedOrNil?($0).map { promise.resolve($0) } ?? promise.reject($0)
		})

		return promise
	}
	
	public func `catch`(onRejected: ((NSError) -> Promise<T>?)) -> Promise<T> {
		let promise = Promise<T>()
		
		`defer`({
			promise.fulfill($0)
		}, {
			onRejected($0).map { promise.resolve($0) } ?? promise.reject($0)
		})
		
		return promise
	}
	
	public func finally(onSettled: () -> Promise<T>?) -> Promise<T> {
		let promise = Promise<T>()
		
		`defer`({ value in
			onSettled().map { promise.resolve($0) } ?? promise.fulfill(value)
		}, { error in
			onSettled().map { promise.resolve($0) } ?? promise.reject(error)
		})
		
		return promise
	}
}

public extension Promise {
	public class func deferred<T>() -> (promise: Promise<T>, fulfill: (T) -> Void, reject: (NSError) -> Void, resolve: (Promise<T>) -> Void) {
		let promise = Promise<T>()
		return (promise, promise.fulfill, promise.reject, promise.resolve)
	}
}

public extension Promise {
	public class func fulfill<T>(value: T) -> Promise<T> {
		return Promise<T>({fulfill, reject, resolve in
			fulfill(value)
		})
	}
	
	public class func reject<T>(reason: NSError) -> Promise<T> {
		return Promise<T>({(fulfill, reject, resolve) in
			reject(reason)
		})
	}
	
	public class func resolve<T>(promise: Promise<T>) -> Promise<T> {
		return Promise<T>({(fulfill, reject, resolve) in
			resolve(promise)
		})
	}
}

public extension Promise {
	public func then(onFulfilled: (T) -> Void) -> Promise<Void> {
		return then(onFulfilled, nil)
	}
	
	public func then(onFulfilled: (T) -> Void, _ onRejectedOrNil: ((NSError) -> Promise<Void>?)?) -> Promise<Void> {
		return then({ value -> Promise<Void> in
			onFulfilled(value)
			return Promise<Void>.fulfill()
		}, { reason -> Promise<Void>? in
			return onRejectedOrNil?(reason)
		})
	}
	
	public func `catch`(onRejected: ((NSError) -> Void)) -> Promise<T> {
		return `catch` { reason -> Promise<T>? in
			onRejected(reason)
			return nil
		}
	}
	
	public func finally(onSettled: () -> Void) -> Promise<T> {
		return finally { () -> Promise<T>? in
			onSettled()
			return nil
		}
	}
}

private enum PromiseResult<T> {
	case Fulfilled(Container<T>) // Although it should be Fulfilled(T), it causes the compile error with Swift 1.1: unimplemented IR generation feature non-fixed multi-payload enum layout.
	case Rejected(NSError)
}

private class Container<T> {
	let value: T
	init(_ value: T) {
		self.value = value
	}
}