# my-jai-events

Synchronous, typed events with no game or platform dependencies.

## Dependencies

No other `my-jai-*` modules are required.

Jai standard library: `Basic`.

Add the directory containing `my-jai-events` to the compiler's module search path.

For example, a standalone checkout at `modules/my-jai-events` needs `modules` on
the search path. A bundled checkout at `modules/my-jai-core/my-jai-events` needs
`modules/my-jai-core` instead.
Initialize the bundled submodules with `git submodule update --init --recursive`.
The event module itself still requires no other modules.

## Usage

```jai
Events :: #import "my-jai-events";

ConfigEventType :: enum {
    Loaded;
    Reloaded;
    Error;
}

MyConfigType :: struct {
    volume: float = 1.0;
}

on_change :: (config_type: Type, event_type: ConfigEventType) {
    // React to the committed value, or to an error retaining the previous value.
}

main :: () {
    config_changed: Events.Event(Type, ConfigEventType);
    defer Events.destroy(*config_changed);
    subscription := Events.subscribe(*config_changed, on_change);
    Events.broadcast(*config_changed, MyConfigType, .Loaded);
    Events.unsubscribe(*config_changed, subscription);
}
```

`Event(Types: ..Type)` generates the callback signature. Broadcast arguments are checked
against that signature at compilation, including shorthand enum literals, and evaluated
exactly once before dispatch. Empty argument lists are supported.

Subscriptions run in registration order. Each `subscribe` creates an independent subscription,
even for the same callback. `unsubscribe` returns false for an absent, already removed or
foreign handle. `clear` removes every subscription while retaining allocated storage;
`destroy` releases storage and allows the event to be reused without reusing previous IDs.

Callbacks may subscribe, unsubscribe, clear, or broadcast the same event recursively.
Unsubscription and clearing take effect immediately; listeners added during dispatch first
run on the next outermost broadcast. Nested broadcasts use the outermost listener boundary.
The outermost broadcast compacts callback storage only after removal or clearing; an
unchanged subscription list needs no second traversal after dispatch.

Events are single-threaded. Keep an event at a stable address, do not copy it after use, and
only destroy it outside its callbacks. A subscription handle belongs to that event instance.
Callback lifetimes and external state belong to the caller; include a state pointer in the
event argument types when a callback needs explicit context.

To check delivery, increment a counter in `on_change`, broadcast once, and assert
that the counter is one. After unsubscribing, broadcast again and assert that the
counter is unchanged. The complete program above supplies the event, callback and
subscription lifecycle needed for this check.
