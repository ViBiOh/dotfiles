# Concurrency

This page aims to explain the concepts and pitfalls of [Go concurrency](https://go.dev/tour/concurrency/1). Go derives its name from the `go` keyword, which launches a goroutine and thereby enables concurrent execution.

However, most Go developers do not use this keyword on a daily basis because it isn't always applicable and demands strict discipline to use correctly. Nevertheless, it remains at the core of the language.

Before diving into Go's implementation, it's worth noting that **concurrency is notoriously difficult** in computer science. Numerous [books](https://www.oreilly.com/library/view/concurrency-in-go/9781491941294/) and articles discuss this challenge. Even though modern processors are fast and multi-core, developers must reason as if **everything were slow** and **never assume** that one operation will finish before another begins. Concurrency is also notoriously hard to debug; often, simply reading the code provides more insight than stepping through it with a debugger.

Most modern languages are imperative: developers write statements in the exact order they should be executed. Concurrency breaks that assumption. Simply writing `go` does not guarantee that the goroutine will begin before the subsequent line runs. To **make concurrency behave deterministically**, while handling errors correctly and avoiding resource exhaustion, a disciplined mindset is essential.

Concurrency is **not always a performance win**. Before diving down that rabbit hole, you should profile and trace the program to identify bottlenecks and decide whether concurrency is appropriate, and, if so, what magnitude of improvement you can realistically expect.

Code examples provided in this page will try to grasp only the point explained in the section. Some production-ready code might be omitted for the sake of clarity.

The examples assume a recent Go toolchain: integer `range` and per-iteration loop variables require Go 1.22+, `b.Loop` requires Go 1.24+, and `sync.WaitGroup.Go` requires Go 1.25+.

# What's a goroutine?

A goroutine is an **independent**, _thread-like_ construct (it isn't exactly a thread) that runs concurrently with the _main_ goroutine, the program's entry point.

The word _independent_ is important because goroutines have no hierarchical relationship. One goroutine can spawn another, but if the parent stops, the child continues to run. Conversely, if a goroutine panics, it brings down the entire program and produces a stack dump.

The need for a goroutine arises when you want to perform work without blocking the current thread. For example, reading a file over the network is much slower than CPU or memory operations. By reading the file in the background and processing the data in the main goroutine, you keep the CPU busy and make better use of network bandwidth.

Each goroutine executes a specific function; the _main_ goroutine runs the `main` function. Goroutine lifetimes vary widely. Some are very short-lived, for instance, refreshing a cache entry _asynchronously_ after fetching data from a database, while others persist for the entire lifetime of the process, such as a goroutine that waits for a `SIGTERM` signal to shut the application down gracefully.

```go
func main() {
  // Start a new goroutine
  go func() { println("Hello World") }()
}
```

A goroutine can be thought of as assigning a task to a dedicated actor, where each actor performs only one operation at a time.

# What's a channel?

We cannot discuss concurrency and goroutines in Go without mentioning channels.

A goroutine runs as an independent lightweight thread, but it must communicate with other goroutines, either synchronously or asynchronously, without depending on external services such as a database or the filesystem. This communication can go both ways: a goroutine may receive input to process or emit a result. Go provides a built-in primitive called a **channel** (often abbreviated `chan`) for exactly this purpose.

The channel API is deliberately simple and can be likened to a water pipe: you **open** it, **close** it, **send** water, or **receive** water. This simplicity enables many useful patterns, but it also introduces the language's most challenging feature to master. Channels lack built-in error handling, and **misuse can lead to panics, deadlocks, or resource leaks**.

## "Open" and close

A channel must be created before you can use it. While you can technically send to or receive from a `nil` channel, those operations block forever and never succeed, so they have virtually no practical use.

```go
ch := make(chan string) // Declare and open a channel

var anotherCh chan string // Declare without opening, very rare use case
```

A channel **should** be closed when you're done using it. Closing isn't required for garbage collection, but attempting to close a channel that is either `nil` or already closed will cause a panic.

```go
ch := make(chan string)
close(ch) // OK
close(ch) // panic: close of closed channel

var anotherCh chan string
close(anotherCh) // panic: close of nil channel
```

Closing a channel sends a termination signal. When you iterate over a channel with `range`, this signal is handled automatically, ending the loop. You can also detect the closure manually, by checking the second value returned from a receive operation, to react to it in custom logic.

## Send and receive

Sending to and receiving from a channel uses an arrow-style notation.

```go
ch := make(chan string)

ch <- "Hello" // "Hello" is sent to `ch`

greeting := <-ch // `greeting` receives from `ch`
```

Both send and receive operations are blocking.

A send statement `ch <- content` blocks until one of two conditions is satisfied:

- The channel is buffered and there is free capacity in its buffer
- The channel is unbuffered and a receiving goroutine is ready to accept the value.

The receive statement `myVar := <-ch` completes when a value is available **or** when the channel has been closed.

If a single value is sent on a channel and several goroutines are waiting to receive from it, only one goroutine will obtain that value, which naturally distributes work among the receivers.

When a channel is closed, any values that remain in its buffer can still be retrieved by the receiving goroutines. After the buffer is drained, further receives return the zero value of the channel's element type (and, in the two-value form, a boolean `ok` that is `false`). At that point all goroutines waiting on the receive will unblock simultaneously.

This arrow-style notation can also appear in a function's parameters to indicate how a channel is intended to be used in the method signature.

```go
func consumer(inputCh <-chan string) {} // Receive-only chan usage

func producer(inputCh chan<- string) {} // Send-only chan usage
```

### Who has the responsibility to close?

The function that sends on a channel, or that sends the close signal, is responsible for closing the channel. Declaring a channel together with its intended usage in a function signature makes the ownership explicit and easier to understand. Attempting to close a _receive-only_ channel is a compile-time error. Failing to close a channel properly can result in deadlocks or goroutine leaks.

The code below illustrates a **goroutine leak**. The spawned function iterates over `ch` with a `for … range` loop and closes the channel when it finishes. However, this creates a chicken-and-egg situation: the loop terminates only when the channel is closed, yet the channel is closed only after the loop exits. As a result, the goroutine can block forever, leaking resources.

This problem disappears if the consumer of the values is defined as a separate function that has a **receive-only** channel (`<-chan string`). In that case, the consumer cannot close the channel.

```go
func main() {
  // Suppose we are receiving identifiers
  ch := make(chan string, 10)

  // We want to compute some stats in background
  go func (){
    defer close(ch)

    for id := range ch {
      // Do something
    }
  }()

  // Rest of the code pushing to `ch`
}
```

A goroutine leak eventually becomes a memory leak because every goroutine consumes at least a couple of kilobytes of stack space (about 2 KB in recent Go versions, though the exact size can change). If the code that spawns the leaking goroutine runs frequently, the accumulated memory usage can grow rapidly, exhausting system resources.

In tests, tools such as [goleak](https://github.com/uber-go/goleak) can detect leaked goroutines before they reach production.

### Close signal

Depending on how many variables you place on the left-hand side of a receive expression, you can capture the close signal, typically by assigning the result to an `ok` (or similarly named) variable. This pattern is most commonly used inside a `select` statement (which we'll cover in the next section).

```go
func main () {
  ch := make(chan int, 1)
  go sendOneAndClose(ch)

  println(<-ch) // print 1

  // ch receiving "resolves" on channel close, but print 0
  // it's the zero-value of an int
  println(<-ch)

  secondCh := make(chan int, 1)
  go sendOneAndClose(secondCh)

  for {
    item, ok := <- secondCh
    if !ok {
      // ok catch if the ch receive was a "real" one or just the close
      break
    }

    println(item) // print 1
  }
}

func sendOneAndClose(ch chan<- int) {
  ch <- 1
  close(ch)
}
```

You don't need to handle the close signal explicitly when you iterate over a channel with `range`; the runtime takes care of it automatically. In this case the arrow notation isn't required either, `range` implicitly receives from the channel.

```go
func main() {
  ch := make(chan int, 1)
  go sendOneAndClose(ch)

  for item := range ch {
    println(item) // print 1
  }
}

func sendOneAndClose(ch chan<- int) {
  ch <- 1
  close(ch)
}
```

### Race condition with `select`

Sending a value into a channel is a blocking operation. Whether the send succeeds quickly, blocks for a while, or never returns depends on the channel's state, whether it's `nil`, unbuffered, or full. Because of this, a send is often in a race with another event, such as a `Context`'s Done channel, a [Ticker](https://pkg.go.dev/time#Ticker)'s time channel, or any other competing channel. In a "bad" scenario (e.g., sending to a full unbuffered channel with no receiver), the operation can block indefinitely.

A `select` statement does **not** impose any priority among its cases. The order in which the cases appear in the source code does not affect which one is chosen. When several channel operations are ready simultaneously, the Go runtime picks one **at** [**random**](https://go.dev/tour/concurrency/5). Consequently, the program below can produce different outputs on different runs because the selection is nondeterministic.

```go
func main() {
  // Create a chan
  inputCh := make(chan int, 10)

  // Create a context and cancel it straight now
  ctx, cancel := context.WithCancel(context.Background())
  cancel()

  // Use a synchronization chan to wait for printing goroutine to finish
  done := make(chan struct{})

  // Print item we received, intuitively, it should not print anything
  // because context is already canceled
  go func() {
    defer close(done)

    for item := range inputCh {
      println(item)
    }
  }()

  writeUntilDone(ctx, inputCh)

  // Wait for printing goroutine to stop.
  <- done
}

func writeUntilDone(ctx context.Context, output chan<- int) {
  defer close(output)

  for i := range 10 {
    select {
      // ⚠️ This won't exit in the first try for sure
      case <-ctx.Done():
         return
      case output <- i:
    }
  }
}
```

## Buffered vs unbuffered

Like a slice, a chan can have a size. In that case, it's considered a **buffered** channel.

```go
bufferedCh := make(chan string, 10)
```

Even a size of 1 is considered a buffered channel.

A buffered channel can hold up to **n** items before it blocks further sends. This _buffer_ lets a sender place a value onto the channel even when no other goroutine is ready to receive it. That's the key distinction from an **unbuffered** channel, which has no capacity at all; every send must rendezvous with a corresponding receive, otherwise the sender blocks.

```go
unbufferedCh := make(chan string)
```

## Data race

While **racing channels against each other** is a common, and often recommended, technique for coordinating concurrency, a **data race** (reading and writing the same variable simultaneously) should be avoided. Some data structures tolerate data races, exhibiting nondeterministic behavior (for example, concurrently appending to a slice can cause lost elements). Others, such as maps, will crash with a fatal error (which cannot be recovered) if a data race occurs.

One of the Go [mantras](https://go.dev/blog/codelab-share) is

> _Don't communicate by sharing, share by communicating_

Sharing a data structure directly between two goroutines to "communicate" should be avoided. Channels exist precisely to pass data safely and to coordinate execution.
For example, instead of letting several goroutines read and write a map concurrently, you can run a single dedicated goroutine that owns the map and expose a request channel. All other goroutines send their operations through that channel and receive the results back (see the example below).

### The `sync` package – when to reach for it

The standard library's `sync` package offers primitives for cases where channels alone are not enough.

| Primitive     | Typical use-case                                                                          | Caveats                                                                               |
| ------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Mutex**     | Protecting a small amount of shared state or a cache.                                     | Over-use leads to lock contention; often a channel-based design can replace it.       |
| **sync.Map**  | Concurrent read-heavy maps where keys are stable and writes are rare.                     | Limited API; not a drop-in replacement for a normal map.                              |
| **WaitGroup** | Waiting for a set of goroutines to finish before proceeding.                              | Must call `Add` before spawning the goroutines and `Done` exactly once per goroutine. |
| **Once**      | Ensuring an initialization routine runs exactly once, even if many goroutines request it. | Useful for lazy loading of configuration, singleton objects, etc.                     |

The "easy-looking" solutions (a global mutex or a `sync.Map`) can be tempting, but they often hide subtle race conditions. Channels may be a bit more verbose, but they give you explicit communication pathways and avoid hidden shared state.

Whenever you suspect a data race, run your code with the race detector:

```shell
go test -race ./...
# or
go run -race main.go
```

The `-race` flag slows execution noticeably, but it will flag unsynchronized accesses to the same variable, helping you catch bugs before they reach production.

# When to `go`?

The `go` keyword launches a new goroutine. Sometimes you'll see it wrapped in helper methods such as [WaitGroup.Go](https://pkg.go.dev/sync#WaitGroup.Go) to make the intent explicit.

A function or method **should not** decide on its own to run in the background; [synchronous functions](https://go.dev/wiki/CodeReviewComments#synchronous-functions) are generally preferable. When a function spawns its own goroutine, the caller loses control over its lifecycle and cannot reliably ensure that the goroutine terminates correctly (see the next section for details).

```go
func do(ctx context.Context) {
  // Do something with the context
}

func dont(ctx context.Context) {
  go func (){
    // Do something with the context
  }()
}

func main() {
  ctx := context.Background()

  go do(ctx) // This is obvious that code is now concurrent
  dont(ctx)  // There is no indication that this code is concurrent
}
```

To make use of concurrency, a goroutine must receive a channel (or channels) as an argument so it can exchange data with the rest of the program. Passing channels explicitly marks a function as "concurrent."

Whenever possible, keep the pure, non-concurrent logic separate from the concurrency-related code. Pure functions are easier to reason about, test, and reuse. By isolating the concurrency concerns in dedicated wrapper functions, you let those wrappers handle only scheduling, synchronization, and communication, while the core business logic remains straightforward and free of threading intricacies.

```go
// Forced concurrent implementation
// Should we close `ch` on error or leave it open because other goroutines use it?
// Should we race between the `ctx.Done` and the `ch`?
func listPaginateToStream(ctx context.Context, ch chan<- any) error

// This is a synchronous function, easy to test, one page, one result.
// It's up to the caller to then stream the results into the chan
func listPaginate(ctx context.Context, page int) ([]any, error)
```

# _Stop starting, start finishing_

When you learn to drive or ski, the first lesson is always "how to brake or stop," because before you can move confidently you need a reliable way to return to a safe state. The same principle applies to concurrent programming. Before you launch a goroutine, you must decide exactly how [it will be stopped](https://dave.cheney.net/2016/12/22/never-start-a-goroutine-without-knowing-how-it-will-stop).

An uncontrolled goroutine that keeps running forever is a liability. It's the creator's responsibility to guarantee that every goroutine has a well-defined termination path, otherwise you risk "leaving someone behind" in the form of leaked resources, deadlocks, or runaway processes.

## Goroutine stop patterns

### Context and timeout

This is the simplest way to launch a goroutine when you just need to run some work in the background and the task itself doesn't require any additional input. The goroutine's lifetime is bounded by the atomic operation it performs; you can further control its lifespan by wrapping the work in a `context.Context` with a timeout or cancellation. When the context expires, the goroutine can abort early, guaranteeing that it won't run indefinitely.

When you launch a goroutine from another goroutine, you usually want the new goroutine to **outlive its "parent."** (Remember, goroutines have no hierarchical relationship.)

In many cases the parent's `context.Context` is cancelled as soon as the parent finishes, e.g., each HTTP request gets its own context that is cancelled once the response has been written to the wire.

If you need the child goroutine to keep running after the parent's context is cancelled, create a **detached context** with [context.WithoutCancel](https://pkg.go.dev/context#WithoutCancel) before passing it to the child.

**Important:** Even when you detach from the parent's cancellation, you should still attach a timeout or deadline to the child's context so that the goroutine cannot run forever. This guarantees that the detached goroutine remains bounded in time while remaining independent of the parent's lifecycle.

### Receiving from a chan

When you need to process a batch of independent jobs in parallel, a common approach is to spin up a pool of worker goroutines that all read from a shared channel. Each worker pulls a task from the channel, executes it, and then loops back for the next one. This transforms a simple sequential `for`-loop into concurrent execution, dramatically reducing the total elapsed time.

The pattern only works when the individual tasks are **independent** (they don't rely on each other's results) and **not CPU-bound**. Network-bound work, such as HTTP calls, database queries, or remote RPCs, is typically I/O-bound, making it ideal for this kind of concurrency. By delegating those I/O-heavy operations to multiple workers, you keep the CPU busy only with coordination while the network latency is overlapped across many requests.

When a goroutine is pulling values from a channel, it has effectively committed to processing that work. You **should not** silently abandon the loop midway. If an individual task panics, recover inside the loop (log it or convert it to an error) and keep consuming the next items. If you must stop entirely, signal the producer to stop, then allow the channel to drain cleanly.

Think of a channel as an assembly line in a car factory. Once a car (a value) enters the line, it must travel all the way to the end; otherwise the whole line stalls. If the line becomes full and you can't add a new chassis, the upstream trucks delivering raw metal can't unload, causing a cascade of blockage.

Modern factories solve this with an [_andon_](<https://en.wikipedia.org/wiki/Andon_(manufacturing)>) system: a worker (the channel consumer) can raise a stop-line signal to the producer, allowing the line to be repaired before work resumes. In Go, you achieve the same effect by:

1. **Using a cancellation context** (or a dedicated "stop" channel) that the consumer can close or send on when it needs to quit.
2. **Ensuring the producer watches that signal** and stops sending new items.
3. **Draining the channel** (or using `for range` with a closed channel) so that any in-flight items are processed before the goroutine exits.
4. **Recovering from panics** with `defer recover()` so the cleanup logic still runs.

By coordinating termination this way, you prevent "goroutine leaks," deadlocks, and resource starvation, just as an andon keeps a manufacturing line from grinding to a halt.

### Panic and error handling

A panic is the Go runtime's way of signaling an unrecoverable error. The most common cases are `nil pointer dereference`, `index out of range`, and `send on a closed channel`. These are runtime errors. They should not happen, but life is not always scripted.

`panic` is **not an error flow** mechanism.

Your code should never call `panic` as a way to "exit" a function quickly. The built-in `error` is the sole expected answer from a function.

Many [people complain about](https://go.dev/blog/error-handling-and-go) the `if err != nil {}` conditions everywhere in Go. Take it as a gift: you have to deal with errors, not throw them over the fence.

_Shit happens, deal with it_ in a very literal sense.

A `panic` will stop the entire execution of the program (all goroutines, dumping each stack trace along the way) unless it's caught by a `recover` **inside** that goroutine that panicked.

In the example below, the first goroutine will catch the panic and can act on it (usually by emitting a log or converting it to a proper error). The second goroutine is not catching anything, it will stop the entire process, even the first goroutine that was properly handling the situation.

```go
func startFire() {
  panic("🔥")
}

func main() {
  go func() {
    defer func() {
      if e := recover(); e != nil {
        fmt.Printf("run: %s\n", e)
      }
    }()

    startFire()
  }()

  go func() {
    startFire()
  }()
}
```

When a function starts a goroutine, it's **the function's responsibility to handle recovery** (by logging, converting the panic to an error).

You cannot `recover` from everything. For example, in the case of concurrent map writes, the runtime cannot determine which goroutine is at fault and crashes the process entirely, there is nothing you can do about that.

The `recover` built-in is tied to a deep understanding of how `defer` [works](https://victoriametrics.com/blog/defer-in-go/index.html).

## Uncontrolled parallelism

Spawning a goroutine is cheap, the Go runtime schedules them for you, so it's easy to fall into the trap of launching everything concurrently. However, goroutines still run on a finite set of OS threads that map to the physical cores of the machine. If you create far more goroutines than the hardware can actually execute, you pay the price of excessive context switches, scheduler overhead, and contention for shared resources, which can _reduce_ performance instead of improving it.

### The goal of concurrency

Concurrency is meant to shrink elapsed time by exploiting the underlying hardware: CPU cores for compute-bound work, and network bandwidth for I/O-bound work. The key is to keep the hardware busy without overwhelming it.

### Example: throttling parallel uploads

Suppose the destination server caps each upload at **50 MiB/s**, while the network link can carry **1 GiB/s**. If you start **20 uploads** simultaneously, the link is saturated and each file can use its full 50 MiB/s allowance, achieving the maximum possible throughput.

Now imagine you launch **1 000 uploads** at once. The 1 GiB/s link is now divided among 1 000 streams, giving each file roughly **1 MiB/s** on average. A 200 MiB file that could finish in ~4 seconds under optimal conditions now takes **>3 minutes**, and many transfers may time out. In addition, the scheduler must constantly switch between thousands of goroutines, adding further overhead and slowing the whole process.

### Practical guidance

1. **Measure the bottleneck** – Identify whether the workload is CPU-bound, network-bound, or I/O-bound.
2. **Set a sensible concurrency limit** – Use a semaphore, a worker-pool, or a bounded channel to cap the number of active goroutines to a level that matches the available resources (e.g., `runtime.GOMAXPROCS`, network bandwidth, API rate limits).
3. **Monitor and adjust** – Observe latency, throughput, and error rates; tune the limit until you achieve the best trade-off between speed and stability.

By consciously limiting concurrency rather than launching an unbounded swarm of goroutines, you keep the system responsive, avoid timeouts, and make the most efficient use of the hardware.

Imagine a highway with many lanes. If you open too many lanes for traffic, cars constantly weave in and out, forcing drivers behind them to brake and accelerate repeatedly. Those lane changes create friction and slow the overall flow.

By reducing the number of active lanes, i.e., limiting the number of concurrent goroutines, you eliminate most of the lane-changing maneuvers. Cars can stay in their lane, maintain a steady speed, and the traffic moves more smoothly and quickly overall.

**Rule of thumb:** Never let concurrency grow unchecked. Always bound the number of goroutines that can run simultaneously, either with a custom semaphore-style limiter (see the example below) or by using the [SetLimit](https://pkg.go.dev/golang.org/x/sync/errgroup#Group.SetLimit) method provided by the popular `errgroup` package.

When you have many short-lived tasks, prefer a **worker-pool** pattern over spawning a brand-new goroutine for each task. A fixed pool of workers reuses existing goroutines, which eliminates the overhead of constant creation and destruction and keeps the scheduler happy, resulting in noticeably better performance.

```go
func operation(n int) int {
  return n * n
}

// Spawn one goroutine per item to compute
func spawn(count int) {
  var wg sync.WaitGroup

  for i := range count {
    wg.Go(func() { operation(i) })
  }

  wg.Wait()
}

// Start a limited number of goroutines to receive and compute
func worker(count, limiter int) {
  ch := make(chan int, limiter)

  var wg sync.WaitGroup

  for range limiter {
    wg.Go(func() {
      for i := range ch {
        operation(i)
      }
    })
  }

  for i := range count {
    ch <- i
  }

  close(ch)
  wg.Wait()
}

func BenchmarkSequence(b *testing.B) {
  size := 1_000
  concurrency := 16

  b.Run("spawn", func(b *testing.B) {
    for b.Loop() {
      spawn(size)
    }
  })

  b.Run("worker", func(b *testing.B) {
    for b.Loop() {
      worker(size, concurrency)
    }
  })
}
```

The result of the above code shows that the "worker" approach is 3 times faster with ~98% less memory consumption.

```
BenchmarkSequence/spawn-10                  3375            308853 ns/op           40165 B/op       2001 allocs/op
BenchmarkSequence/worker-10                 9984            112209 ns/op            1050 B/op         34 allocs/op
```

Both `spawn` and `worker` are concurrent; the difference is that `worker` reuses a fixed pool of goroutines instead of creating one per item. That reuse makes it roughly **3× faster** (~112 ns/op vs ~309 ns/op for the whole 1 000-item run) with about **98% less memory**. The takeaway is narrow: **when you do go concurrent, a bounded worker pool beats spawning one goroutine per item.**

Be careful not to over-read this benchmark. The `square` operation is deliberately adversarial: it is so tiny and purely CPU-bound that a plain serial loop (not benchmarked here) would beat both concurrent versions, because the compiler can inline `operation` and the cost of goroutine scheduling, channel communication, and synchronization dwarfs the work itself. The worker pool's real advantage shows up with I/O-bound work, where each task spends most of its time waiting (see the webhook fan-out example later). For cheap CPU-bound work, don't go concurrent at all.

# Usage and example

## Streaming items

The most common and fundamental use of a channel is to stream values from one goroutine to another.

```go
func main() {
  // Create an unbuffered channel to send data
  itemCh := make(chan int)

  // Create a sync channel to signal that the consumer is done
  done := make(chan struct{})

  // Read items and print them
  go func() {
    defer close(done)

    // The range will stop when `itemCh` is **empty and closed**
    for item := range itemCh {
      println(item)
    }
  }()

  // Send 10 items
  for i := range 10 {
    itemCh <- i
  }

  // Send stop signal by closing itemCh
  close(itemCh)

  // Wait for consumer to stop
  <-done
}
```

## A simple buffer

In some situations the producer-consumer pattern becomes imbalanced: the producer generates data faster than the consumer can process it (or vice-versa). Adding a buffer between them lets the faster side continue working at full speed while the slower side catches up, preventing bottlenecks and keeping overall throughput as high as possible.

```go
func main() {
  // Create a channel aligned with the page size
  // Without buffering, the first 99 items need to be processed before
  // the producer can fetch the next page, wasting nearly 1s doing nothing
  itemCh := make(chan string, 100)

  // 1s to get 100 items on the producer
  // 100ms to process each item
  // We need 10 goroutines to catch up
  for range 10 {
    go func() { consumer(itemCh) }()
  }

  // The producer will never stop iterating
  producer(itemCh)
}

func producer(output chan<- string) {
  for page.HasMore() {
    // Call to a slow API that takes 1s to retrieve 100 items

    for _, item := range page.Results {
      // Enqueue to output
      output <- item
    }
  }
}

func consumer(input <-chan string) {
  for item := range input {
    _ = item // Computation that takes 100ms to process the item
  }
}
```

## A limiter

A buffered channel can act as a limiter to at most **n** concurrent actions.

```go
func concurrentFibonacci(number int) {
  // We want to process at most 4 items concurrently
  limiter := make(chan struct{}, 4)

  for i := range number {
    // Enqueue to the limiter, this is a blocking call
    // If the chan is full, it waits
    limiter <- struct{}{}

    go func() {
      // Dequeue from limiter when exiting, to leave one room
      defer func() { <-limiter }()

      fibonacci(i)
    }()
  }
}
```

## A synchronization signal

Closing a channel emits a termination signal that can be used to synchronize goroutines. When a channel is used solely for synchronization, only the close signal matters. By sending a zero-size value (`struct{}`) and using an unbuffered channel, you achieve the minimal possible memory footprint.

```go
func main() {
  // Create a start chan to synchronize race cars
  // It's often named `done` when needed to synchronize termination
  start := make(chan struct{})

  // We use a WaitGroup to wait for race cars' readiness
  // Usually, it's used to wait for goroutines completion
  var wg sync.WaitGroup

  // Align the 20 cars on the grid
  for i := range 20 {
    wg.Add(1)
    go func() { raceCar(&wg, i, start) }()
  }

  // Wait for all goroutines to start and report they're ready
  wg.Wait()

  // Green light
  // Start the race by sending the close signal to all goroutine at the same time
  close(start)
}

func raceCar(wg *sync.WaitGroup, number int, start <-chan struct{}) {
  wg.Done() // race car is ready on the grid

  // Wait for the green light
  // The <- instruction is blocking and resolve when either:
  //   - content is sent on the channel and consumed by a goroutine
  //   - channel is closed, in this case all goroutines resolve at the same time
  <-start

  println(number)
}
```

## Synchronous communication with reply-to channel

An **unbuffered** channel enforces synchronous communication: the sender blocks until a receiver is ready, and vice-versa. A **buffered** channel, on the other hand, permits asynchronous interaction because the sender can place values into the buffer without waiting for an immediate receiver.

This distinction is especially useful for a publish/subscribe pattern that includes a _reply-to_ channel. The publishing goroutine can send a request on a buffered channel, allowing the subscriber to process the item at its own pace. When the subscriber finishes, it replies on the caller-provided reply channel, giving the original goroutine a synchronous response even though the processing happened asynchronously in a separate goroutine.

```go
type Message struct {
  Name string
  Reply chan int
}

func main() {
  // Create a buffered channel for sending message, so caller is asynchronous
  inputCh := make(chan Message, 4)

  // Concurrent write is forbidden in map, only one goroutine will be in charge
  identifiers := make(map[int]string)
  go func() {
    var sequencer int

    for message := range inputCh {
      // Create an identifier
      sequencer += 1

      // Return the identifier to unblock caller
      message.Reply <- sequencer
      close(message.Reply) // not mandatory, better for clarity

      // Write in the map
      identifiers[sequencer] = message.Name
    }
  }()

  // Start multiple goroutines that need an identifier
  go createUser("Alice", inputCh)
  go createUser("Bob", inputCh)

  // In real code, block here (e.g. with a WaitGroup) so main doesn't return
  // before the goroutines complete.
}

func createUser(name string, inputCh chan<- Message) {
  message := Message{
    Name: name,
    Reply: make(chan int),
  }
  inputCh <- message

  identifier := <-message.Reply

  // continue
}
```

For production-ready behavior, the above scenario would be better suited with a buffered channel of size 1, otherwise one lazy/slow goroutine can block the "identifier" goroutine with the synchronous call.

## Push in cache after reading from database

In an HTTP API, we first try to serve a request from the cache and fall back to the database if the cache misses. When we retrieve a value from the database that isn't already cached, we want to populate the cache so that subsequent requests are faster.

Updating the cache, however, is not on the critical path, the client is already waiting for the response that comes from the database. Therefore we off-load the cache-write to a background goroutine. The request handler returns the data immediately, while the goroutine silently inserts the fresh value into the cache (optionally with a timeout or cancellation context to avoid runaway work). This keeps latency low for the user while still keeping the cache warm for future calls.

```go
func (s *Service) Get(ctx context.Context, id int) (any, error) {
  // Read content
  content, fromCache, err := s.read(ctx, id)
  if err != nil {
    return nil, err
  }

  // We want to push in the cache if the answer we got was not from there
  if !fromCache {
    // The `ctx` might be `Done` before this goroutine even start
    // because HTTP request ended
    go func(ctx context.Context) {
      // Put our own timeout
      ctx, cancel := context.WithTimeout(ctx, time.Second*30)
      defer cancel()

      // do stuff
    }(context.WithoutCancel(ctx)) // Remove parent's ctx dependency
  }

  return content, err
}
```

## Fan-out to perform concurrent HTTP requests

When a customer updates a resource we need to notify a set of configured webhooks. Because the latency of each webhook endpoint can differ, we must not let a slow endpoint delay the delivery to the others, especially the last webhook in the list.

The solution is to fire all webhook calls **concurrently** (e.g., by launching a goroutine for each request or by using a worker-pool). Each goroutine sends its payload independently, so the overall notification latency is bounded by the slowest successful call rather than by the sum of all calls. If you need to report results (success/failure) back to the caller, collect them on an additional channel; the example below simply waits for completion with a `sync.WaitGroup` and logs errors. When you also need first-error propagation and automatic cancellation of the sibling goroutines, reach for [errgroup.WithContext](https://pkg.go.dev/golang.org/x/sync/errgroup#WithContext) instead of a bare `WaitGroup`.

This is a fan-out scenario: one producer, multiple consumers.

```go
func consumer(ctx context.Context, payload any, input <-chan string) {
  for url := range input {
    // send $payload to $url
    // In case of error, log but continue
  }
}

func sendWebhooks(ctx context.Context, payload any, urls []string) {
  // Create a communication channel
  inputCh := make(chan string)

  // Start 4 (arbitrary number) goroutines to perform webhooks
  var wg sync.WaitGroup
  for range 4 {
    wg.Go(func() { consumer(ctx, payload, inputCh) })
  }

  // Send the urls to consumers via the communication channel
  for _, url := range urls {
    inputCh <- url
  }

  // When all urls have been submitted
  // Send the termination signal by closing the chan
  close(inputCh)

  // Wait for consumers to stop
  wg.Wait()
}
```

## Pipeline of actions

Suppose the following spec:

- Fetch a list of identifiers from an API
- For each identifier:
  - Call another API to gather extra content
  - Aggregate the sum of one field in the extra content

Three functions can be identified there:

- `list(context.Context) ([]item, error)`
- `fetch(context.Context, id string) (content, error)`
- `aggregate(int)`

Doing it sequentially will be slow. Doing it with 1 goroutine listing and 4 goroutines fetching, we'll have a data race on the aggregate (deliberately ignoring possible other solutions here). Doing it with 1 goroutine listing, 4 goroutines fetching, and 1 goroutine doing the aggregation seems like a solution.

### Start your goroutines in "reverse" order

Goroutines communicate with channels, and to avoid errors, start your goroutines from the last receiver and work back to the first (reverse order): the producer is started last.

At the end, wait and close in the "natural" order from producer to consumer.

Error management is temporarily ignored in the following snippet and will be dealt with right after.

```go
const concurrency = 4

func crawl(ctx context.Context) int {
  // Create our communication channel
  identifierCh := make(chan string, concurrency)
  itemCh := make(chan Item, concurrency)

  // We have only one aggregation goroutine
  // a synchronization chan is enough to wait for the end
  aggregateDone := make(chan struct{})

  var sum int
  go func() {
    // Closing the aggregation signals the outer goroutine that `sum` can be read.
    // It must run *after* the loop drains itemCh, hence the defer.
    defer close(aggregateDone)

    for item := range itemCh {
      // Because there is one goroutine, we can safely overwrite outer variable
      sum = aggregate(sum, item)
    }
  }()

  // We have multiple goroutines running, a synchronization chan is not possible
  // A WaitGroup is the correct approach
  var wg sync.WaitGroup

  for range concurrency {
    // This is a go1.25 syntax, otherwise do wg.Add() / wg.Done()
    wg.Go(func() {
      for id := range identifierCh {
        item, _ := fetch(ctx, id)
        // handle your error

        _ = safeSender(ctx, itemCh, item)
        // handle your error
      }
    })
  }

  // Now that all consumers have been started, we can start emit identifiers
  identifiers, err := list(ctx)
  // handle your error

  // Send identifiers to the channel and trust the process
  for _, identifier := range identifiers {
    _ = safeSender(ctx, identifierCh, identifier)
    // handle your error
  }

  // When we arrive here, it means that we send all identifiers into the channel
  // We close the channel to send that signal
  close(identifierCh)

  // The fetchers continue to run until the end of the channel, that we just sent
  // We wait for the WaitGroup to terminate (so all fetchers)
  wg.Wait()

  // All fetchers are done, we close the aggregation channel to send that signal
  close(itemCh)

  // The aggregation continue to run until the end of the channel, that we just sent
  // We wait for the done channel to be closed
  <-aggregateDone

  // Everyone is done, we can now safely read the `sum` variable
  return sum
}

// This function ensure a safe send into a chan, guarded by the cancel of a Context
func safeSender[T any](ctx context.Context, ch chan T, instance T) error {
  select {
  case <-ctx.Done():
    return ctx.Err()
  default:
  }

  select {
  case <-ctx.Done():
    return ctx.Err()
  case ch <- instance:
    return nil
  }
}
```

## Race condition by printing time every 5s until we receive SIGINT

A simple example where a ticker will print the time until the end of the program, materialized by a `SIGINT` [signal](https://pkg.go.dev/os/signal#Notify) (in a [terminal](https://www.fosslinux.com/121761/the-abcs-of-linux-signals-sigint-sigterm-and-sigkill-explained.htm)).

```go
func main() {
  signalsChan := make(chan os.Signal, 1)
  defer close(signalsChan)

  signal.Notify(signalsChan, syscall.SIGINT)
  defer signal.Stop(signalsChan)

  ticker := time.NewTicker(time.Second * 5)
  defer ticker.Stop()

  for {
    select {
    case now := <-ticker.C:
      fmt.Printf("%s\n", now)
    case <-signalsChan:
      return
    }
  }
}
```

# Concurrency vs parallelism

One key concept to understand go concurrency is the subtle difference between Concurrency and Parallelism. There are plenty of blog articles on that online. This [video](https://www.youtube.com/watch?v=oV9rvDllKEg) from Rob Pike (core contributor of Golang) is a good introduction.

**Concurrency** is a _design philosophy_: it's about structuring a program so that it can **deal with** many tasks at once, regardless of whether those tasks are actually running simultaneously.

**Parallelism** is an _execution strategy_: it's about **doing** multiple tasks at the same time. Parallelism only becomes possible when enough resources are available to run separately.

## Concurrency

[Gantt](https://en.wikipedia.org/wiki/Gantt_chart) charts were invented to squeeze the most productivity out of industrial machines during World War I and later became a staple of project-management planning. [PERT](https://en.wikipedia.org/wiki/Program_evaluation_and_review_technique) diagrams extended the idea, showing task dependencies and the critical path so that a project could be completed in the shortest possible time while honoring those dependencies.

That very principle, _arranging tasks to minimize elapsed time regardless of how many people (or resources) are involved_, is what we call **concurrency** in computing. A Gantt chart is only a visual plan; it doesn't run anything by itself. Someone must read the chart, allocate workers, and coordinate the work.

The same relationship holds for code. Writing a program is merely producing a set of instructions that are handed to a CPU. The source code itself does nothing until the runtime schedules those instructions for execution. Concurrency is the technique we use to schedule many independent pieces of work so that they progress together, reducing overall latency even though the underlying hardware may have a limited number of cores.

**Making coffee as a concurrency metaphor**

To brew a cup of coffee you need several steps: boil water, grind the beans, steam the milk, force hot water through the grounds, and so on. Many of these steps can overlap. While the beans are grinding you can start heating the water; while the water is heating you can prepare the milk or ready the espresso machine. Only a few points require strict ordering, e.g., you must pour the espresso before adding the steamed milk.

If a single person does everything alone, at any moment only one activity can truly be in focus (even though you have two hands, attention is limited). By treating each independent step as its own "task" that can run concurrently, you reduce the total time needed to make the coffee, just as concurrent goroutines reduce the elapsed time of independent operations in a program.

## Parallelism

After the plan is laid out, you can calculate how many resources (workers, machines, CPU cores, etc.) are required to execute the tasks most efficiently. That's the point where **parallelism**, the actual simultaneous execution of those tasks, can be introduced.

### Parallelism – cars in separate lanes

On a highway with four lanes, up to four cars can travel forward **simultaneously**. As long as each car stays in its own lane, none of them blocks the others. This is the essence of **parallelism**: multiple units of work are _actually_ executing at the same instant on different resources (CPU cores, lanes, etc.).

### Concurrency – traffic-light coordination

In a city grid, intersections are controlled by traffic lights. At any given moment only one direction may have a green light, so cars from the other streets must wait. The lights act like a **semaphore**, orchestrating the flow so that every street eventually moves. From a high-level perspective all streets make progress "around the same time," even though only one street moves at any instant. This is **concurrency**: the system arranges many tasks so they can _interleave_ safely, following a plan (the light cycle) that prevents collisions.

**Parallelism** means that multiple tasks really run at the same instant because there are enough independent resources to execute them simultaneously.

In computer science, a single-core processor can only perform one operation at a time; the feeling that many things are happening together is just the operating system rapidly switching contexts. When you have a multi-core CPU, each core can execute its own instruction stream, so several goroutines (or threads) can truly run in parallel from both the computer's and the human observer's perspective.

## Illustration: race car pit stop

A race car pit stop has to replace four tyres. The work can be broken into a series of steps that have ordering constraints:

1. **Lift the car** – must happen before any wheel can be removed.
2. **Unscrew the wheel bolts** – must finish before the old tyre can be taken off but can start before lifting
3. **Remove the old tyre** and set it aside.
4. **Put the new tyre** on the hub.
5. **Tighten the wheel bolts**.
6. **Lower the car** – the final step.

#### Concurrency (interleaved work)

If a single crew member performs _all_ of those steps sequentially, the stop is long because the person can only do one thing at a time.
If several crew members are assigned _different_ steps, e.g., one person lifts the car while another unscrews the bolts on a different wheel, they can **interleave** their activities. The overall process proceeds faster, but at any instant only a subset of the crew is actually doing work; the rest may be waiting for a prerequisite step. This interleaving of independent tasks is **concurrency**: the plan lets multiple actions overlap, but they are not necessarily happening simultaneously.

#### Parallelism (true simultaneous work)

When the pit crew assigns a dedicated person (or three people) to each wheel **and** a separate person to operate the lift, all four wheels can be serviced at the same time. While the lift is raised, the four wheel crews work in parallel, each performing steps 2–5 on its own wheel without waiting on the others (except for the initial lift and final lowering). Here the work is **parallel**: multiple independent units of labor execute simultaneously on distinct resources (four sets of tools and hands).

#### The critical "middle" phase

Even in the parallel version, the steps that involve the lift (raising and lowering) are a _synchronization point_. All wheel crews must wait until the car is lifted before they can start, and they must all finish before the car can be lowered. Those points act like a barrier that coordinates the parallel workers, illustrating how **concurrency** (the overall coordination) and **parallelism** (the simultaneous wheel changes) coexist in the same operation.

![Figure: Parallelism and concurrency masterclass](https://media1.tenor.com/m/tg28WEO2hLoAAAAd/f1-pitstop.gif)
