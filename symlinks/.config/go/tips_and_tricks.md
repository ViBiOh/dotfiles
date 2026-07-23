# Golang tips and tricks

> Disclaimer:
>
> This document tends to define common guidelines for writing Golang code in Cloud Platform (and beyond!). The focus is on the syntax, grammar, and everyday idioms of the language. It is not an in-depth design or architecture guide, though some sections (interfaces, error handling) do touch on design.
>
> The guidelines tend to follow the Golang team philosophy with maybe some adjustments. In any case, it should not be used in a dogmatic manner but as a basis of discussion.
>
> The code examples assume Go 1.22+ (integer `range`, per-iteration loop variables).

# Resources

The [CodeReview Comments](https://go.dev/wiki/CodeReviewComments) from the Golang team is a good start to avoid some common caveats.

The [100 Go Mistakes and How to Avoid Them](https://100go.co/) is another source of tips and tricks.

# Go Basics

## Basic types declaration

There are several ways to declare a basic-type variable in Go. Let's see them:

```go
var foo string          // zero value, i.e. ""
var bar string = "bar"  // explicit type and value
baz := "baz"            // short declaration, type inferred
qux := new(string)      // *string pointing to a zero-value string
```

In Go, when you don't specify any initialization, a variable takes the zero value of its type. Thus, `var foo string` is equivalent to `foo := ""`, and `var foo string = "foo"` is equivalent to `foo := "foo"`. Be mindful that `new` does not return a `string` but rather a pointer to a string (`*string`).

Idiomatic Go:

If the zero value is fine, prefer the declaration, e.g. `var foo string`

If you need to initialize while declaring, use the initialization, e.g. `foo := "bar"`

Although there is nothing wrong with using `foo := ""`, it does not convey the exact same meaning.

## Struct pointer declaration

For non basic (struct) types, there are also several ways to declare them as pointers. Let's see:

```go
var s *MyStruct
s := new(MyStruct)
s := &MyStruct{}
```

In the pointer block, the first line declares `s` as a pointer to `MyStruct` without initializing it (i.e. it is `nil`), whereas the two others, in addition to the declaration, also assign it to an empty instance (all `MyStruct` fields having the zero value of their type) of `MyStruct`.

Idiomatic Go: always prefer `var s *MyStruct` for declaration, and `s := &MyStruct{}` for initialization. Note that `s` doesn't need to be initialized to an empty `MyStruct`: this can be done with something like `s := &MyStruct{Field1: value1, Field2: value2}`.

## Slices, Maps, and Channels

Cheat sheet for using slices, maps, and channels. More detailed information follows.

| **How to Instantiate ->** | **Unknown Size**                                                                  | **Known Size**                                      | **Known Values**          |
| ------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------- |
| Slices                    | Don't instantiate. Nil slices are usable for `range`, `len`, `cap`, and `append`. | `make([]int, 0, 10)` Length 0, starting capacity 10 | `[]int{1, 2, 3}`          |
| Maps                      | `make(map[int]int)`                                                               | `make(map[int]int, 10)`                             | `map[int]int{1: 2, 3: 4}` |

Slices, maps and channels are all created using the builtin `make` like in the following example:

```go
// Declarations. These all set the corresponding variable to the zero value
var s []string
var m map[string]string
var c chan string // pretty rare to declare a zero chan

// Initialization (reusing the variables declared above, hence `=` not `:=`)
// DON'T! s = make([]string) or s = []string{}
m = make(map[string]string) // or m = map[string]string{}
c = make(chan string) // unbuffered

// Initialization with known capacity or buffers
s = make([]string, 0, 10) // empty slice with starting capacity 10
m = make(map[string]string, 10) // empty map with capacity hint 10
c = make(chan string, 10) // channel with buffer size 10
```

Be mindful that you can use builtins like `len`, `cap`, or `close` on an empty slice, map, or channel (when applicable), but you usually cannot manipulate them with `[]` (or reading / writing for channels) until they are allocated with `make`, with the exception of `append` with slices.

Idiomatic Go: always use simple declarations when you just want to declare your variable. When it comes to creating them, always prefer `make([]string, 0, len)` if you know how many elements there will be in your slice (works for map as well, and there is also a `cap` parameter that can be used with slices). For a slice specifically, don't `make([]T, 0)` with no capacity: a nil slice (`var s []T`) does the same job. This caveat is about slices only; `make(map[K]V)` and `make(chan T)` take no capacity and are perfectly normal.

As a side note, be careful of the following construct (declaring the `len` and not the `cap`) which may not do what you expect:

```go
sliceWithLen := make([]int, 5)
sliceWithCap := make([]int, 0, 5)

for i := range 5 {
  sliceWithLen = append(sliceWithLen, i)
  sliceWithCap = append(sliceWithCap, i)
}

fmt.Println(sliceWithLen) // [0 0 0 0 0 0 1 2 3 4]
fmt.Println(sliceWithCap) // [0 1 2 3 4]
```

Reference: [Go CodeReview comment](https://go.dev/wiki/CodeReviewComments#declaring-empty-slices)

### Slice append behavior

`append` should not be seen as an immutable `add` to a slice. It's recommended to store the output of `append` to the same variable you appended because it **could** change reference, but it doesn't mean it **does** every time. And even if you don't store the result, the slice could have changed. It depends on the `cap` on the slice.

```go
func observe(good, bad int, tags []string) {
  client.Incr("my_metric", append(tags, "good"), good)
  client.Incr("my_metric", append(tags, "bad"), bad)
}
```

If you are absolutely sure that the slice is used instantly and no reference is taken, it will work as expected. But very often, observability requests are batched, and so temporarily buffered. Depending on the `cap(tags)`, you can have the expected behavior, or not. See [Go Play](https://go.dev/play/p/rHeWtKhw-Uo) for example

When wanting to "just append a single value to a slice for a single call", invert the `append` call so you are sure to create a new reference each time

```go
client.Incr("my_metric", append(tags, "good"), good)
```

becomes

```go
client.Incr("my_metric", append([]string{"good"}, tags...), good)
```

Be aware this places `"good"` **before** the existing tags, changing element order compared to `append(tags, "good")`. If order matters, allocate a new slice with the intended order explicitly.

# Functions arguments

This isn't specific to Golang, but usually arguments are sorted from the most generic to the most specific.

Idiomatic Go: always use the following pattern for your function declaration (except for very rare cases):

`func myFunc(ctx context.Context, param1 type1...) (returnValue1, ..., error)`

## Context

Context is a very common argument in many functions.

Idiomatic Go: **If your function needs one**, `ctx context.Context` is **always** the first argument of the function

When does your function need a context?

- It's making a network call (database, cache, grpc, http, etc.). Almost all network calls accept a context, as a way to manage the request.
- You want to create a trace/span in your function for observability, because it can be CPU intensive, a long running process, etc.
- It calls a function that needs a context

Apart from tests, it's very rare that you need to create a context yourself (i.e. `context.Background()`). Most of the time, the function receives a context that you need to carry. The context carries the tracing and even if a task is run in background, you should not create a new context for that, but remove the cancelation.

### Values

The context allows to store some values in it. While it can be seen as a convenient way to pass data to downstream functions without changing function signature, it doesn't help to understand the behavior of the function.

The values in the context should remain "contextual": if the data is there, good, if not, the function's behavior should remain the same.

e.g.

The `TraceID` is **a good candidate** for Context values, you have tracing if present, otherwise, no tracing.

The `orgID` is **not a good candidate**, your code needs this value to work, it needs to be an argument.

When you do store a value, use an unexported custom key type (not a bare `string`) to avoid collisions between packages that share the same context.

## Channel

When your function receives or return a channel, if relevant, always specify in what manner the channel is intended to be used:

- `chan<- string` is a **send-only** channel: your function sends its results to the channel
- `<-chan string` is a **read-only** channel: your function consumes the channel

It doesn't change the underlying channel, but it is enforced by the compiler (sending on or closing a receive-only channel is a compile error) and adds more semantics to the variable's name.

## Error

Error is a very common return in many functions.

Idiomatic Go: the `error` is **always** the last returned argument of the function (if your function returns one).

### Named return parameter, naked return

Like arguments, you have the possibility to name the return parameters. While possible, it's not very readable and should be avoided except in some defined cases:

- for tracing, especially to report the error in the span when exiting the function. Note that `defer` should be a func and not be a direct call ([explanation here](https://100go.co/?h=defer#ignoring-how-defer-arguments-and-receivers-are-evaluated-argument-evaluation-pointer-and-value-receivers-47))

```go
func do(ctx context.Context) (output any, err error) {
  span, ctx := tracer.StartSpanFromContext(ctx, "do")
  defer func() {
    span.Finish(tracer.WithError(err))
  }()

  ...
}
```

- when using generic, to have a predeclared instance with the right type when exiting the func

```go
func get[T any](ctx context.Context) (instance T, err error) {
  if !isValid(ctx) {
    return instance, ErrNotValid
  }

  ...
}
```

Naked returns hurt readability once a function is more than a few lines, and should be avoided in almost all cases.

```go
func get[T any](ctx context.Context) (instance T, err error) {
  if !isValid(ctx) {
    err = ErrNotValid
    return // DON'T
  }

  ...
}
```

# Packages

Everything is structured under a package in Golang.

There is no overhead of splitting things into separate packages (apart from import loops). The goal is to have a high cohesion but a low coupling. For the same reason, it's totally fine to split your package into multiple files as long as the filename expresses some semantics, e.g. `constants.go`, `model.go`, `errors.go`.

Naming is hard, and your package name and function/structure should tell a story to the user. An external user will call your package with `myPackage.NewMyStruct` so be mindful of naming to have a concise intent on the caller side. Have a look at [strings](https://pkg.go.dev/strings), [time](https://pkg.go.dev/time) or [regexp](https://pkg.go.dev/regexp) package from the standard library. Functions have a short name but are still expressive given the package name.

Do

```go
package content

type Reader struct{}

func NewReader() Reader { return Reader{} }

// Usage will be

content.NewReader()
```

Don't

```go
package contentreader

type ContentReader struct {}

func NewContentReader() ContentReader { return ContentReader{} }

// Usage will be

contentreader.NewContentReader() // it seems a bit redundant
```

# File

The declaration order in a file is not relevant for the compiler as it could be in other languages. But following a common pattern can help to quickly find what we search for. There is no convention, but if we follow the way a package [is described](https://pkg.go.dev/net/http) and the Golang library is written, we should follow the given order.

The overall philosophy is going from global to specific and be able to read the file in a "natural" order: from top to bottom, left to right and in a way that you don't have to go backward to understand something. Having intention-revealing names also help to have a smooth flow [without being too verbose](https://www.karlton.org/2017/12/naming-things-hard/).

```go
package business

import (
  // Use formatting tools like gofumpt to group your import in two category
  // the standard library one
  // then the third-party
)

const (
  // Put your constants first. It describes what is hardcoded or static in the code
  // And help quickly find some default. Except if you put all const in a given file
  // It's generally good to put only the const of the file
  // If you use `iota`, don't be afraid to put multiple const groups for reset
)

var (
  // Next your variables. It can be some sentinel error
  ErrNotFound = errors.New("not found")

  // Some global variables (not recommended)
  register = map[string]string{"hello": "world"}

  // Or any relevant variable
)

// It's generally not recommended to have init function
// But if you have, keep it visible so people don't have to search it
func init() {}

// Declaring the struct after, that will probably use some of the vars
// Group every method of the struct before going to another struct
type Content struct {}

// Constructors can be seen as public functions and put after struct declarations
// Or can be put here because they initialize the struct before using it
func NewContent() Content {
  return Content{}
}

func (c Content) Increment(int) {}
func (c Content) Check() bool { return true }

type Another struct {}

func (a Another) Find(int) {}

// After the struct, the public functions. It's likely that people who
// came to see this file want to know public behavior rather than implementation details

func Compute(ctx context.Context, input Content) Another {
  return Another{}
}

// Finally, private functions are at last. They are likely be called by the public ones
func extract(input Content) bool {
  return true
}
```

## File splitting

There is no extra cost of having multiple file within a package, i.e. you don't need to "import" a file. You are free to split the package content into multiples files to have smaller intent-driven files.

There is no convention for that. Keep your files organized in a way that is convenient for the most. As much as we tend to avoid long lines of code, we also try to avoid long files. "long" here is the subjective part.

You can, for example, do:

- one file per `struct`
  - Be mindful on that, if you have one large struct that is composed of multiples data struct, putting everything in the same file can be easier to read
  - If the struct has many methods or very complex ones, it's fine to split it into multiple files too. e.g. `client.go`, `client_update.go` and `client_delete.go`
- one file for declaring your sentinel errors
- one file for declaring your constants
- one file for declaring your util functions
- every splitting that makes sense for your package…

# Interfaces

One of the Golang mantras is ["accept interface, return struct"](https://go.dev/wiki/CodeReviewComments#interfaces). In theory, you should declare an interface for every behavior you need in your package, defined at the point of consumption, rather than importing a third-party concrete type you intend to mock. (Importing shared interfaces from the standard library, such as `io.Reader`, is of course perfectly idiomatic.) Use judgment here: redeclaring a one-method interface at every call site leads to interface proliferation, and you still depend on the concrete type where you construct it. Reach for a local interface when you genuinely need to decouple or to mock a boundary, not reflexively.

This has many benefits for mocking, having soft coupling between packages and/or domains. Let's review with an example

PS: we are talking here about structs or interfaces that hold a `Service` (a struct doing action, call, etc). It doesn't apply in a strict sense to struct that hold only data ([POGO - Plain Old Golang Object](https://en.wikipedia.org/wiki/Plain_old_Java_object)).

## Mocking benefit

We need to call a thirdparty (database, cache, other services), a naïve approach can be:

```go
package main

func GetInformation(ctx context.Context, client *thirdparty.ClientStruct, id int) (string, error) {
  return client.Get(ctx, id)
}
```

This code is not easy to test, because you need a **real** struct in input, so in your test you might need a real connection to the service. If we change to an interface, we can use a mock, the code will look like:

```go
package main

func GetInformation(ctx context.Context, client thirdparty.Service, id int) (string, error) {
  return client.Get(ctx, id)
}
```

Now you can test it by generating a mock (with `mockgen` for example, or passing another interface that complies with the `Service` interface). It works well, it's fine.

⚠️ But, sooner or later, the thirdparty will change its interface (adding a new method for example), and your generated mock won't comply with the expected interface (your test won't compile). You'll have to regenerate the mock just because you update the thirdparty SDK, even without using the new method.

## Soft coupling

We can avoid being exposed to interface changes by defining only the behavior we need, thanks to the fact that interfaces are dynamic in Golang.

```go
package main

type DatabaseService interface {
  Get(context.Context, int) (string, error)
}

func GetInformation(ctx context.Context, client DatabaseService, id int) (string, error) {
  return client.Get(ctx, id)
}
```

Now, we are properly isolated from thirdparty changes. We have our own mock of our own interface and as long as the `*thirdparty.ClientStruct` has the `Get` method with the matching signature it will work. If the `ClientStruct` no longer implements that method, it will be a compilation issue, but for a good reason (e.g. deprecation/breaking changes).

Furthermore, having an interface doing only the minimum set of needed behaviors complies with the [SOLID](https://en.wikipedia.org/wiki/SOLID) principles ("interface segregation" and a little bit of "single-responsibility principle").

It's a little duplication from the thirdparty package, but it avoids a dependency, following the guideline ["A little copy is better than a dependency"](https://go-proverbs.github.io/).

### Accept interface, return struct

Accepting only interface is good to isolate from thirdparty, and for the same reason, returning struct let the caller use our implementation in the way it wants.

If we return an interface, we are limiting the usage of the implementation (breaking the [Open/Close principle](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle)). Returning an interface also forces the caller to use our interface (or a subset it has to define on its own), so we create the same problem that we faced about the interfaces changing in the thirdparty and the need to regenerate all the mocks relying on it.

Interfaces are good for composition, for example, there are some interfaces in the [standard library](https://pkg.go.dev/io#ReadCloser) that are good at composing:

```go
type RegularFile interface {
  io.Reader
  io.Writer
  io.Closer
}
```

Returning an interface that does all the things break that granularity level.

If we return a struct, having correct public and private methods should be sufficient to limit the usage of a struct. The caller can also choose to use the struct directly or as a pointer to the struct, which is not possible with an interface. This way, the caller can deal with mutable or immutable behavior based on its need.

# Errors

First of all, [errors are values](https://go.dev/blog/errors-are-values).

## Handling

The standard pattern when handling error, should be, in that order:

- handle the error (for example, you receive an `ErrUnauthenticated` in your `loginHandler` and you will handle this by returning 401, and not returning any error)
- if not possible, chain it and propagate it (when you have additional information you can add to the error, see the `fmt.Errorf("...: %w", err)` pattern below.
- if not possible, propagate it as is (usually when there is nothing you can do, like for example if `json.Unmarshal()` fails)

Idiomatic Go (for the sake of clarity curly braces are omitted):

`if errors.Is(err, ErrUnauthenticated) http.Error(w, "Unauthorized", 401)`

``if err != nil return fmt.Errorf("authenticate user `%d`: %w", userID, err)``

`if err != nil return err`

Here note the `%w` which allows the embedding of the error, and later on, the use of `errors.Is()`.

Most of the time, if you receive an error with some extra values in the output of a func, you should only look at the values after checking that the `err == nil`.

```go
data, metadata, err := get(ctx)
if err != nil {
  // handle error without `data` or `metadata`
}

// you're allowed to use `data` and `metadata`
```

## `panic()`

In Go, we keep our calm and never panic. Like NEVER. Panicking is only used in very rare circumstances, like in CLI, where there is no way to recover. Whenever you are tempted to `panic()` just return a nice error instead and check it / propagate it upstream.

Idiomatic Go: never `panic()` in library code. The rare accepted exceptions are package-level `Must...` helpers (e.g. `regexp.MustCompile`), invariant checks in `init()`, and truly unrecoverable CLI errors.

## Recover

While we don't want to start a `panic` in our code, it can still happen sometimes for common mistakes like index out of bound, nil pointer exception, etc. A `panic` is crashing the entire process: not just the current goroutine being in error, but everything. While convenient to avoid indeterministic behavior in the code, in a service handling multiples tasks at once, we don't want to crash everyone for only one case.

You can `recover` from a `panic` by using a `defer`.

```go
func myFunc() {
  defer func() {
    if e := recover(); e != nil {
      slog.Error(fmt.Sprintf("panic: %s", e))
      debug.PrintStack() // Simple example, in real world, use error with stack
    }
  }()

  // do something
}
```

You cannot `recover` from everything. For example, in the case of concurrent map writes, the runtime cannot determine which path is faulty and crashes the process entirely, there is nothing you can do about that.

The `recover` built-in should not be used as an error flow control. The built-in error mechanism in Golang is already powerful enough to handle all the cases. Recover is a safeguard that if things go badly, you can "catch" the error so it won't propagate in the entire process.

Idiomatic Go: when a function starts a goroutine, it's its responsibility to handle recovery (by logging, catching it as an error).

There is no "hierarchy" in goroutines. If a function starts two goroutines, each started goroutine needs to have its own `recover` call. You cannot "catch" the failure of both in the "parent" function, because there is no such "parent" goroutine concept.

## Chaining

The idiomatic way of handling errors in Golang is by [returning](https://akavel.com/go-errors) the `err` directly. Let's use the example below of a function parsing a raw CSV string and returning the identifier integer, in the second column.

```go
var ErrNoIdentifier = errors.New("no identifier")

func GetID(raw string) (int64, error) {
  columns := strings.Split(raw, ",")
  if len(columns) < 2 {
    return 0, ErrNoIdentifier
  }

  id, err := strconv.ParseInt(columns[1], 10, 64)
  if err != nil {
    return 0, err
  }

  return id, nil
}
```

There is inherently nothing wrong with this function. But suppose that this function is called by another function in a loop, that does the `return err` and so on. You can end-up having a high-level function that received a `no identifier` error without any context or code path, that is hard to debug.

To avoid that, we can do an error chaining that wrap every error exit path with a small message. If you look at [the output](https://go.dev/play/p/4Hpz7WWu5V8) of the `strconv.ParseInt` in case of error, you get something like `strconv.ParseInt: parsing "qw": invalid syntax`.

Every underlying call is declared in the form `<context of the error>: underlying error`.

So, instead of returning the `err` directly, let's wrap it to explain from where it comes with `fmt.Errorf`.

```go
var ErrNoIdentifier = errors.New("no identifier")

func GetID(raw string) (int64, error) {
  columns := strings.Split(raw, ",")
  if len(columns) < 2 {
    return 0, fmt.Errorf("split: %w", ErrNoIdentifier)
  }

  id, err := strconv.ParseInt(columns[1], 10, 64)
  if err != nil {
    return 0, fmt.Errorf("parse: %w", err)
  }

  return id, nil
}
```

Using the `%w` to wrap the error is a key part to keep the error behaving as if it were not wrapped (with `errors.Is` for example).

Now, if every function in the call chain wraps the errors like this, the high-level function will receive an error like ``parse request: parse csv `first line of my csv`: get id: split: no identifier``. You clearly see the path of the error and how to solve it.

Idiomatic Go

- don't be too verbose on the context, the function being called is often enough to understand
- an error is… an error, i.e. no need to add "failed to do something" or "error while doing something". We already know that it's an error.
- add content of relevant variables in the error message (e.g. `first line of my csv` is the content being parsed)
- don't add any input parameters in the error message, it's up to the caller to decide to add it in the error or in the log. Exception if you're in a loop.
- as for any error, start it with a lower case
- the chained error may expose some internal behavior that you don't want to expose to the outside world (e.g. HTTP Server). At some point it can be relevant to log the chained error, and return a new public-related error "oops something went wrong".

## Inspecting and combining errors

Beyond `errors.Is` (matching a sentinel), use `errors.As` to extract a typed error and read its fields, and `errors.Join` (or multiple `%w` verbs in a single `fmt.Errorf`, Go 1.20+) to combine several errors into one.

# defer

`defer` is a powerful tool in Go, but has some tricks worth knowing. [This article](https://victoriametrics.com/blog/defer-in-go/index.html) will probably describe them better than what I can do.

Don't `defer` in a loop: the deferred calls only run when the surrounding function returns, so a `defer` inside a long or unbounded loop accumulates resources (e.g. open files) until the end. Wrap the body in its own function, or call the cleanup explicitly at the end of each iteration.

# Mutexes

If you need to read and edit a variable from multiple goroutines at the same time, you end up having a data race condition. One easy way to prevent that is using a [mutex](https://pkg.go.dev/sync#Mutex). But "easy" doesn't mean it's the "right" way.

The mantra of go for that is ["Do not communicate by sharing memory; instead, share memory by communicating"](https://go.dev/blog/codelab-share). This is a design guideline, not a performance one: for simply protecting shared state, a mutex (or `sync/atomic`) is usually faster and simpler than a channel. You pick a channel when it makes ownership and coordination clearer, not because it is quicker.

The short answer is also synthesized in this article https://go.dev/wiki/MutexOrChannel .

As a rule of thumb: to protect the fields of a struct, reach for a mutex (or `sync/atomic` for a simple counter or flag); to transfer ownership of data or coordinate goroutines, reach for a channel.

If after reading these articles, you still want to use a Mutex, some guidelines can be relevant because even if the interface is easy, concurrent programming is very hard to debug and error prone.

## Read or write, not both

Default to a plain [Mutex](https://pkg.go.dev/sync#Mutex). A [RWMutex](https://pkg.go.dev/sync#RWMutex) lets multiple readers hold the lock at once (only writers need an exclusive lock), but it carries more overhead and only pays off when you have many concurrent readers holding the lock for a non-trivial duration. Under low contention or short critical sections it is often slower than a `Mutex`. Reach for `RWMutex` only when profiling shows read contention, not by default.

Be aware that even if a goroutine has a read lock, it needs [to release the read lock before gaining the write lock](https://go.dev/play/p/WKezNlD4BuS): this pattern appears frequently if you read a value, and then decide to change it (nil check for example).

## Always unlock

Most of the time, do the `mutex.Unlock()` in a `defer` statement. With a `defer`, you have the guarantee that, even in `panic`, the function (unlock) will be called. Also, minimize the duration on which you hold the lock: if your function is making expensive computation, release the `Lock` as soon as possible, maybe not in a `defer`.

For example, the following code, even if it's very simple, can panic if the `map` is not initialized, and the lock will remain for ever, hanging the application.

```go
func (s *Cache) Put(key, value string) {
    s.mutex.Lock()
    s.content[key] = value
    s.mutex.Unlock()
}
```

So instead, write it like this

```go
func (s *Cache) Put(key, value string) {
    s.mutex.Lock()
    defer s.mutex.Unlock()

    s.content[key] = value
}
```

Note the **pointer receiver**: a value receiver would copy the `Cache` (and its mutex) on every call, so the lock would protect nothing (`go vet` flags this).

Beware that `defer` is executed when you exit the function, so don't `defer` [within a loop](https://blog.learngoprogramming.com/gotchas-of-defer-in-go-1-8d070894cb01).

## Run with `-race` flag

Golang has a built-in data race detector that you can enable when running or testing your application. It's not recommended to use it in a "live" environment because it's very slow. But during unit tests, it's a good option to enable just to ensure that your code behaves in a deterministic way.

When testing, always add the `t.Parallel()` [option](https://pkg.go.dev/testing#T.Parallel) to try to run your code in parallel and thus be more prone to data races. It's better to detect them in tests rather than in production.

The race detector works by guarding every variable read or write and check that no other goroutine is accessing it at the same time. It tests live execution: if a run doesn't trigger a data race, it doesn't mean your code is safe. You may simply not have taken the bad path, depending on your execution coverage.

# Code coverage

You may not know that Go can also measure and precisely show your code coverage line per line.
To see this in action, run the following command (`c.out` is quite a standard name, so it should be added to your `.gitignore`):

```
go test -coverprofile=c.out ./... && go tool cover -html="c.out"
```

This will present you with an HTML page with your test coverage per file as well as your source code highlighted in 3 colors:

- gray doesn't need to / cannot be tested
- green covered
- red not covered

It seems like `go cover` is installed by default on our laptops, but in case you don't have it, you can install it by running:

```
go install golang.org/x/tools/cmd/cover@latest
```

# Tooling

## Formatting

While Golang comes with [its own formatting tool](https://go.dev/blog/gofmt) to avoid useless debate, there is a common tool used among the community to go a bit further with [gofumpt](https://github.com/mvdan/gofumpt): it satisfies the `go fmt` format but can also do some simplifications / refactor to make it easier to read (a lot of examples are present in the GitHub repository documentation).

Also, manually importing/sorting/grouping packages can be a pain and [goimports](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) aims to solve that.

When saving a .go file, run `goimports` and then `gofumpt` on the file to format it easily.

## Testing

Using Go's built-in testing package is usually the simplest and most reliable choice for most test scenarios because it integrates tightly with the language, has zero external dependencies, and works seamlessly with the `go test` tooling and coverage reports. Adding a few lightweight assertions from Testify can improve readability without pulling in a large framework. In contrast, Testify's Suite runner introduces extra boilerplate, hides the natural flow of table-driven tests, and can make debugging harder since failures are reported through the suite's wrapper rather than the standard `testing.T`. Sticking mostly to the standard library keeps tests fast, clear, and easy to maintain.

When testing a .go file, use native `testing` package or `testify/assert` for checks but avoid wrapping them in `testify.Suite` as it doesn't support parallelism and breaks most out-of-the-box test integrations.
