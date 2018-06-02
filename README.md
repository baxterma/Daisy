## Introduction

Working with asynchronous APIs can be a pain. Chaining work with callbacks often leads to a [pyramid of doom](https://en.wikipedia.org/wiki/Pyramid_of_doom_(programming)), making data flow hard to follow, and error handling difficult. It's easy to end up several layers deep in nested callbacks, unsure of where data have come from, and where they're going, and with error handling scattered, seemingly at random, all over the place.

Promises and futures solve these problems. They let you focus on the flow of your data, and the work you perform with them. They allow you to centralise your error handling, and simplify otherwise complex techniques like synchronising concurrent tasks.

Daisy aims to provide a thread-safe Swift implementation of promises and futures, along with a rich collection of methods for chaining asynchronous work. The `Task` and `CancellationPool` types also help make building higher-level abstractions easier.

Daisy is compatible with macOS, iOS, watchOS, tvOS, and Linux. For information on adding it as a dependency using either the Swift Package Manager, or Carthage, please see the [Installing](#installing) section below.

## Promises and Futures

### Futures

A future is a read-only, single-assignment container for the result of a piece of work. On the face of it, that definition might seem a little confusing: if a future is read-only, how can you assign to them? That's where promises come in, which we'll get to in a moment. 

"Assigning" a future is called "resolving;" we don't assign to a future, we resolve it. A future can be resolved to one of these three states:

#### Fulfilled (with a result)

A future is fulfilled when the work it represents has finished successfully, and produced a result. That result is then used to resolve the future; fulfilling it.

#### Rejected (with an error)

A future is rejected when the work it represents encounters an error, preventing it from producing a result. The error the work encountered is used to resolve the future, rejecting it.

#### Cancelled (possibly with an indirect error)

A future is cancelled when the work it represents has been cancelled. It is possible in this situation, that the work was cancelled because some other part of the system encountered an error, meaning our work could no longer be carried out. Daisy calls these errors "indirect errors." Indirect errors are errors that occurred elsewhere, but caused a piece of work to be cancelled. A future doesn't have to be cancelled with an indirect error, it can be cancelled without one just fine.

The `Future` instance representing a piece of work should be exposed publicly by your asynchronous API, either as a return value from a function, or as a property. To get a value from a future, you can use one of the following methods on `Future`:

* `whenResolved(executeOn:_:)`
* `whenFulfilled(executeOn:_:)`
* `whenRejected(executeOn:_:)`
* `whenCancelled(executeOn:_:)`
* `whenAnyError(executeOn:_:)`

To find out more about these methods, please see their in-code documentation. In practice, however, you won't ever need to use these methods, and instead will use the chaining family of functions discussed below. You can also obtain the result of a future using the `unsafeAwait()` method, which will block until the future is resolved. As the name implies, however, it is unsafe, as it can easily lead to deadlocks when the work of the future upon which you are awaiting is needing to execute code on the blocked queue.

### Promises

A promise is how you resolve a future. Unlike futures, promises are write-only. However, like futures, they are still single-assignment; you can only resolve them once. 

Each promise has a one-to-one relationship with a future, a link which is determined when you initialise a promise. Initialising a promise will also initialise a future, which you can access via the `future` property on `Promise`. You cannot initialise `Future` instances yourself, only `Promise` instances. 

Resolving a promise will resolve its future to the same state. You can resolve a promise using one of the following methods:

* `fulfil(with:)`
* `reject(with:)`
* `cancel(withIndirectError:)`

You will use these methods extensively in practice to resolve promises you are managing yourself. Attempting to resolve a promise more than once will print a warning, but otherwise do nothing. 

Unlike `Future` instances, `Promise` instances are kept strictly private by your asynchronous APIs. This makes reasoning about asynchronous work easier, as you know that when you get back a `Future`, only one object is capable of resolving it, and that it can only ever be resolved once. 

### Using Promises and Futures In Practice

1. Inside your asynchronous work (which could be a function, or an object), initialise a `Promise`.
2. Start your work, resolving the `Promise` you created earlier when finished.
3. Expose your `Promise` instance's `future` property publicly, either as the return value from a function, or via a property. 

For example, a function might look like:

```swift
func computeAnswer() -> Future<Int> {
    
    let promise = Promise<Int>()
    
    DispatchQueue.global(qos: .background).async {
        
        do {
            
            let answer = try ...
            promise.fulfil(with: answer)
        }
        
        catch {
            
            promise.reject(with: error)
        }
    }
    
    return promise.future
}
```

Or an object might look like:

```swift
final class DownloadTask {
    
    // MARK: - Properties
    
    private let promise = Promise<Data>()
    var future: Future<Data> { return promise.future }
    
    let url: URL
    
    private lazy var dataTask: URLSessionDataTask = {
       
        return URLSession.shared.dataTask(with: url) { (data, _, error) in
            
            guard let data = data else {
                
                self.promise.reject(with: error ?? UnknownError())
                return
            }
            
            self.promise.fulfil(with: data)
            
        }
    }()
    
    // MARK: - Init
    
    init(url: URL) {
        
        self.url = url
    }
    
    // MARK: - Starting
    
    func start() {
        
        guard !promise.isResolved, dataTask.state == .suspended else { return }
        
        dataTask.resume()
    }
}
```

This pattern of having a single-use 'task' object (similar to `Foundation.Operation`) can prove to be quite common. Especially if each type could be a self-contained abstraction of a single piece of work, include a shared concept of 'input' and 'output', and more rigidly enforce the single-use requirement. With these benefits, however, comes the potential for a lot of synchronisation boilerplate, state management, etc. Daisy provides a higher-level abstraction, above `Promise` and `Future`, to make this kind of pattern easier to live with.

## `Task`

`Task` is an abstract class used to represent a single unit of asynchronous work. `Task` includes all the aforementioned boilerplate, meaning that subclasses need only focus on implementing the work they represent. `Task` has full support for taking input, and producing output, in addition to supporting cancellation (_see the [Cancellation](#cancellation) section below on how Daisy handles cancellation_). 

Creating a custom task is as simple as subclassing `Task`, and overriding `start(with:)`. Your implementation should begin with:
```swift
guard preStart() else { return }
```
This line is needed to perform some bookkeeping, and ensure that tasks are only started once. When your work is finished, you should call either `complete(with:)`, or `fail(with:)`. 

_For more information on `Task`, and creating `Task` subclasses, please see its in-code documentation._

To start a `Task`, it is recommended that you use `Daisy.start`. You can use the `start` family of functions to start individual tasks, or a group of tasks, there is also a version of `start` that takes a closure. Every version of `start` returns a future with a result type matching either the task's output type, or the closure's return type. This means that both tasks, and closures can be used to start a chain of work in Daisy.

## Chaining Work with Daisy

Daisy provides a series of functions on `Future` that let you chain work together, allowing you to have data pass from one piece of work to another, without descending into multiple layers of nested callbacks. 

Any chaining function that takes a closure will, by default, execute that closure on the main queue. Any chaining function that takes a `Task` will, by default, execute that task on the global utility queue. Both behaviours can be customised by passing a different queue for the `queue` parameter on the chaining functions.

Every time you use a chaining function in Daisy, you are creating a new future (which the chaining function returns), and Daisy is managing the promise that will resolve that future. Each section of a chain in Daisy takes the result of the previous future in the chain (the future you're chaining onto) as input. This input can be passed as an argument to a closure, or as the input to a `Task`. When you chain work in Daisy, you are enqueueing work to be executed when the future you're chaining on to fulfils.

If an error occurs at some point in a chain, it will propagate down, cancelling the futures representing any chained work, using the original error as an indirect error. The same rules apply for cancellation; if a future is cancelled, the cancellation will propagate down, cancelling the futures representing any chained work. The result of these two behaviours is that in the event of a future being rejected or cancelled, the error (if there is one) will trickle down as an indirect error, cancelling the other futures in the chain, and causing any chained work not to be executed. This means you only need to handle errors in one place, and you don't need to manage the dependencies between pieces of work yourself.

_See below for more information on methods that let you handle errors, recover from them, or let you execute code regardless of whether an error occurred._

_For details on each of the methods below, please see their in-code documentation._

### `then`

#### Result-Returning Closure `then`

```swift
func then<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (_ input: Result) throws -> Output) -> Future<Output>
```

Takes the result of the receiving future, and passes it to `closure`. Your closure should either return its result, or throw an error. Returning a result will fulfil the returned future with that result. Throwing an error will reject the returned future.

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then { data in
    
    try JSONSerialization.jsonObject(with: data, options: [])
}
```

#### Task `then`

```swift
func then<Output>(_ task: Task<Result, Output>, on queue: DispatchQueue = .global(qos: .utility), using cancellationPool: CancellationPool? = nil) -> Future<Output>
```

Takes the result of the receiving future, and passes it to `task` as its input. The returned future will resolve to the same state as `task` (it is the task's future).

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then(ParseJSONTask())
```

#### Future-Returning Closure `then`

```swift
func then<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (_ input: Result) -> Future<Output>) -> Future<Output>
```

Takes the result of the receiving future, and passes it to `closure`. Your closure should return a future that will eventually resolve. 

This method can serve many different purposes, including the ability to create nested or recursive chains, or dispatch multiple pieces of work and then collect them together (using `Future.whenFulfilled`, discussed below) within an existing chain.

The returned future will resolve to the same state of the future you return from `closure`.

Example usage:
```swift
func fetchProfileImage(withProfileJSON profileJSON: [String : Any]) -> Future<NSImage> { 
 
    return // ...
}

start(running: DataDownloadTask(), with: profileURL)
.then(ParseJSONTask())
.then { json in
    
    fetchProfileImage(withProfileJSON: json)
}
.then { profileImage in
    
    // ...
}
```

#### Task Group `then`

```swift
func then<Output>(_ tasks: [Task<Result, Output>], on queue: DispatchQueue = .global(qos: .utility), using cancellationPool: CancellationPool? = nil) -> Future<[Output]>
```

Takes the result of the receiving future, and passes it to each task in `tasks` as their input. The returned future will either fulfil with an array of the combined output of `tasks`, or reject or cancel if any task in `tasks` fails or is cancelled.

Example usage:
```swift
let filterTasks = [ImageFilterTask(type: .gaussianBlur), ImageFilterTask(type: .sepiaTone), ImageFilterTask(type: .mono)]
    
let filteredImages = fetchHeroImage().then(filterTasks)
```

### `additionally`

`additionally` allows you to take the result from one future, use it to do some work, but carry it forward (in addition to a new result) to the next section of a chain. This is achieved by the result type of the returned future being a tuple.

#### Result-Returning Closure `additionally`

```swift
func additionally<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (Result) throws -> Output) -> Future<(Result, Output)>
```

Takes the result of the receiving future, and passes it to `closure`. Your closure should either return its result, or throw an error. Returning a result will fulfil the returned future with a tuple containing said return value, and the original result of the receiving future. Throwing an error will reject the returned future. 

Example usage:
```swift
func fetchHeroImage() -> Future<NSImage> { 

    return // ...
}

fetchHeroImage()
.additionally(on: .global(qos: .background)) { heroImage -> NSImage in
    
    let filteredHeroImage = // ...
    
    return filteredHeroImage
}
.then { (originalImage, filteredImage) in
    
    // ...
}
```

#### Task `additionally`

```swift 
func additionally<Output>(_ task: Task<Result, Output>, on queue: DispatchQueue = .global(qos: .utility), using cancellationPool: CancellationPool? = nil) -> Future<(Result, Output)>
```

Takes the result of the receiving future and passes it to `task` as its input. If `task` finishes successfully, the returned future will be fulfilled with a tuple containing the output of `task`, and the original result of the receiving future. Otherwise, the returned future will resolve to the same state as `task`.

Example usage:
```swift
fetchHeroImage()
.additionally(ImageFilterTask(type: .mono))
.then { (originalImage, filteredImage) in
    
    // ...
}
```

#### Future-Returning Closure `additionally`

```swift 
func additionally<Output>(on queue: DispatchQueue = .main, execute closure: @escaping (Result) throws -> Output) -> Future<(Result, Output)>
```

Takes the result of the receiving future and passes it to `closure`. Your closure should return a future that will eventually resolve. If the future returned by `closure` fulfils, the future returned by `additionally` will be fulfilled with a tuple containing the result of the future returned by `closure`, and the original result of the receiving future. Otherwise, the returned future will resolve to the same state as the future returned by `closure`.

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then(ParseJSONTask())
.additionally { profileJSON in
    
    fetchProfileImage(withProfileJSON: profileJSON)
}
.then { (profileJSON, profileImage) in
    
    // ...
}
```

### `Future.fulfillingWhen`

While strictly not in the "chaining family of functions" (insofar as the following methods are not instance methods on `Future`), the `Future.fulfillingWhen` family of functions are very closely related to the other chaining functions, and serve similar purposes. These functions allow you to group, or merge, a collection of `Future` instances into one. 

#### Future Array `fulfillingWhen`

```swift 
static func fulfillingWhen<R>(_ futures: [Future<R>]) -> Future<[R]> where Result == [R]
```

Takes an array of `Future` instances with the same result type. Returns a new future that fulfils with the results of the supplied futures combined into an array, with the position of each result matching the position of its corresponding future in the originally supplied array. 

Example usage:
```swift
let posts: [Future<Post>] = // ...
    
Future.fulfillingWhen(posts)
.then { posts in
        
    // ...
}
```

_For more details on how the resolved state of the returned future is determined by the supplied futures, please see the in-code documentation._

#### (Up To) Arity 6 `fulfillingWhen`

```swift
static func fulfillingWhen<R0, R1>(_ f0: Future<R0>, _ f1: Future<R1>) -> Future<(R0, R1)> where Result == (R0, R1)
```
Takes a series of futures (with different result types) as separate parameters (up to arity 6). Returns a new future that fulfils with the results of the supplied future instances combined into a tuple; maintaining the type information of each result.

Example usage:
```swift
let profileJSON = start(running: DataDownloadTask(), with: profileURL).then(ParseJSONTask())
    
Future.fulfillingWhen(profileJSON, fetchHeroImage())
.then { (profileJSON, heroImage) in
    
    // ...
}
```

_For more details on how the resolved state of the returned future is determined by the supplied futures, please see the in-code documentation._

### `catch`

```swift
func `catch`(on queue: DispatchQueue = .main, includingIndirectErrors includeIndirectErrors: Bool = true, using closure: @escaping (_ error: Error) -> Void) -> Future<Result>
```

`catch` allows you to respond to errors that occur in a chain. The presence of a `catch` section will not prevent errors from propagating (see [`recover`](#recover)), but it informs you of them. You might use `catch` to display an error to the user, for example, or update the UI. 

By default, the closure you pass to `catch` will be called for both rejection errors, and indirect errors. You can control this with the `includeIndirectErrors` parameter. `catch` will not be called for futures that were cancelled without an indirect error. Furthermore, `catch` is the one (with exception of, technically, the task-taking chaining methods) chaining method that does not create a new future; it returns the receiver.

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then { data in
        
    try JSONSerialization.jsonObject(with: data, options: [])
}
.catch { error in
        
    // either an error from DataDownloadTask or JSONSerialization, if one occurred
}
```

### `recover`

`recover` allows you to recover from errors by providing an alternative result (of the same type) to the next section in a chain. By default, the means of recovery you supply will be used in the event of both rejection errors, and indirect errors. You can control this behaviour with the `includeIndirectErrors` parameter. If you choose to ignore indirect errors, they will propagate as normal. `recover` will not be called for futures that were cancelled without an indirect error.

#### Optional-Result `recover`

```swift
func recover(on queue: DispatchQueue = .main, includingIndirectErrors includeIndirectErrors: Bool = true, using closure: @escaping (_ error: Error) -> Result?) -> Future<Result>
```

Takes the error that occurred further up in the chain, and passes it to `closure`. Your closure should return either an alternative result, or `nil` if one cannot be provided given the error that occurred. If you do supply an alternative result, it will be used to fulfil the returned future. If you do not supply an alternative result, the returned future will be resolved to the same state as the receiver. This is to give the impression of the recover being 'invisible;' the same reason `catch` returns `self`.

Example usage:
```swift
fetchHeroImage()
.recover { error in
    
    if canRecoverFromError {
        
        return placeholderImage
    }
    
    else {
        
        return nil
    }
}
.then { heroImage in
    
    // ...
}
```

#### Autoclosure-Result `recover`

```swift
func recover(includingIndirectErrors includeIndirectErrors: Bool = true, using alternativeResult: @autoclosure @escaping () -> Result) -> Future<Result>
```

Allows you to supply an error-independent (and as such, non-optional) alternative result. The fact that your alternative result will be wrapped in a closure (courtesy of `@autoclosure`) will mean that it will only be computed if it is needed (i.e. the receiver encounters an error). 

Example usage:
```swift
func makePlaceholderImage() -> NSImage { 

    return // ...
}

fetchHeroImage()
.recover(using: makePlaceholderImage()) // makePlaceholderImage() will only be called if fetchHeroImage() encounters an error
.then { heroImage in
        
    // ...
}
```

### `always`

`always` allows you to supply either a closure or a `Task` that will always be executed, regardless of the receiver's resolved state. 

#### Closure `always`

```swift
func always(on queue: DispatchQueue = .main, execute closure: @escaping () -> Void) -> Future<Void>
```

Executes `closure` when the receiver is resolved.

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then { data in
        
    throw DemoError()
}
.always {
    
    // will still be called, despite error thrown above
}
```

#### Task `always`

```swift
func always(on queue: DispatchQueue = .global(qos: .utility), execute task: Task<Void, Void>) -> Future<Void>
```

Executes `task` when the receiver is resolved.

Example usage:
```swift
start(running: DataDownloadTask(), with: profileURL)
.then { data in
        
    throw DemoError()
}
.always(execute: CleanUpTask()) // CleanUpTask will still be started
```

## Cancellation

Daisy provides a couple of abstractions to make cancelling your asynchronous work easier.

### `Cancellable`

`Cancellable` is a very simple protocol that contains only one method: `attemptCancel()`. Implementations of this method should  cancel the receiver, providing it is in a state where it can be (hence the "attempt" in the method name), otherwise, it should do nothing. `Task` already conforms to `Cancellable`.

### `CancellationPool`

A cancellation pool is used to collect a series of `Cancellable` items, where they can later be cancelled without needing to manually store a collection of the aforementioned items. 

Combined with the `cancellationPool` parameter on the `Task`-taking chaining functions, a cancellation pool makes it easy to cancel a chain of tasks at any time, without needing to manage a collection yourself. In practice you might, for example, build a chain to load some data the user has requested. In this scenario, you would initialise a cancellation pool, store it as a property somewhere, and pass it to the chaining functions you're calling. If the user navigates away from the screen in question, making the ongoing data fetch unnecessary, you can cancel the chain with one call to `drain()` on the cancellation pool.

Furthermore, because `CancellationPool` supports anything that conforms to `Cancellable`, you can add your own custom types too, even if they don't inherit from `Task`.

## Installing

### Swift Package Manager

Add the following to your `dependencies` array:

```swift
.package(url: "https://github.com/baxterma/Daisy", .upToNextMinor(from: "1.0.0")),
```

### Carthage

Add the following to your Cartfile:

```
github "baxterma/Daisy" ~> 1.0
```

## Acknowledgements

Daisy was inspired by [PromiseKit](https://github.com/mxcl/PromiseKit), and `Operation` in Foundation.
