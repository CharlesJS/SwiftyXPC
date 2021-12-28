# SwiftyXPC

## Hmm, what’s this?

SwiftyXPC is a wrapper for Apple’s XPC interprocess communication library that gives it an easy-to-use, idiomatic Swift interface.

## But there’s already `NSXPCConnection`!

Well, yes, but with its protocol-and-proxy-based interface, it’s far better suited to Objective-C than Swift.
Using `NSXPCConnection` from Swift has always felt somewhat awkward, and with the advent of Swift Concurrency, it’s even worse, given that everything has to be wrapped in `withCheckedThrowingContinuation` blocks.
`NSXPCConnection` has also tended to be behind `libxpc` in certain important ways—notably, in the ability to verify the code signature of a remote process via an audit token.

By contrast, SwiftyXPC:
- Offers a fully Swift Concurrency-aware interface. Use `try` and `await` to call your helper code with no closures necessary.
- Gives you a straightforward interface for your helper functions; take an argument, return a value async. No fussing around with Objective-C selectors and reply blocks.
- Built around the `Codable` protocol, so you can use any types you want for the argument and return value, as long as both types conform to `Codable`, and it Just Works™. Error types are preserved as well, if they are `Codable` and you register their domains with the shared `XPCErrorRegistry` object.
- Only links against XPC and Security (the latter for the code signature validation), so there’s no need to link Foundation into your app, deal with Objective-C bridging magic, or involve the Objective-C runtime at all (excluding any places where XPC or the Security framework may be using it internally).

## But I want to support older macOS versions! Using Swift Concurrency means that it requires macOS 12!

Actually, it turns out that’s not true anymore! With Xcode 13.2, Swift concurrency now works all the way back to macOS 10.15 “Catalina”, and consequently, so does this library.

## What’s the license on this?

MIT.
