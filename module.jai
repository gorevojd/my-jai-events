// Synchronous, single-threaded events. Keep each Event at a stable address and do not copy it.
// Callbacks run in subscription order. Removing a subscription takes effect immediately.
// New subscriptions wait until the next outermost broadcast, including during nested broadcasts.
// Callback code owns its captured state; include an explicit pointer among Types when needed.

Subscription :: struct {
    owner: *void;
    id: u64;
}

Event :: struct (Types: ..Type) {
    #insert -> string {
        builder: String_Builder;
        defer free_buffers(*builder);
        print_to_builder(*builder, "Callback :: #type (");
        for Types {
            if it_index > 0 {
                print_to_builder(*builder, ", ");
            }
            print_to_builder(*builder, "Types[%]", it_index);
        }
        print_to_builder(*builder, ");\n");

        print_to_builder(*builder, "dispatch :: (event: *Event(..Types)");
        for Types {
            print_to_builder(*builder, ", arg%: Types[%]", it_index, it_index);
        }
        print_to_builder(*builder, ") {\n");
        print_to_builder(*builder, "    if event.dispatch_depth == 0 {\n");
        print_to_builder(*builder, "        event.dispatch_limit = event.callbacks.count;\n");
        print_to_builder(*builder, "    }\n");
        print_to_builder(*builder, "    event.dispatch_depth += 1;\n");
        print_to_builder(*builder, "    defer finish_broadcast(event);\n");
        print_to_builder(*builder, "    for index: 0..event.dispatch_limit - 1 {\n");
        print_to_builder(*builder, "        callback := event.callbacks[index].callback;\n");
        print_to_builder(*builder, "        if !callback {\n");
        print_to_builder(*builder, "            continue;\n");
        print_to_builder(*builder, "        }\n");
        print_to_builder(*builder, "        callback(");
        for Types {
            if it_index > 0 {
                print_to_builder(*builder, ", ");
            }
            print_to_builder(*builder, "arg%", it_index);
        }
        print_to_builder(*builder, ");\n    }\n}\n");
        return builder_to_string(*builder);
    }

    Entry :: struct {
        id: u64;
        callback: Callback;
    }

    callbacks: [..]Entry;
    next_id: u64 = 1;
    dispatch_depth: int;
    dispatch_limit: int;
    needs_compaction: bool;
}

subscribe :: (event: *$E/Event, callback: E.Callback) -> Subscription {
    assert(callback != null, "An event callback cannot be null.");
    assert(event.next_id != 0, "Event subscription identifiers exhausted.");
    id := event.next_id;
    event.next_id += 1;
    array_add(*event.callbacks, E.Entry.{id, callback});
    return .{event, id};
}

unsubscribe :: (event: *$E/Event, subscription: Subscription) -> bool {
    if subscription.owner != event || subscription.id == 0 {
        return false;
    }
    for *entry: event.callbacks {
        if entry.id == subscription.id && entry.callback != null {
            entry.callback = null;
            event.needs_compaction = true;
            if event.dispatch_depth == 0 {
                compact(event);
            }
            return true;
        }
    }
    return false;
}

// Code arguments preserve contextual enum literals and compile-time callback signature checking.
// Each argument is evaluated once before the first callback, even when there are no subscribers.
broadcast :: (event: *$E/Event, $args: ..Code) #expand {
    target := event;
    #insert -> string {
        builder: String_Builder;
        defer free_buffers(*builder);
        print_to_builder(*builder, "E.dispatch(target");
        for args {
            print_to_builder(*builder, ", #insert args[%]", it_index);
        }
        print_to_builder(*builder, ");\n");
        return builder_to_string(*builder);
    }
}

clear :: (event: *$E/Event) {
    for *entry: event.callbacks {
        entry.callback = null;
    }
    if event.dispatch_depth == 0 {
        event.callbacks.count = 0;
        event.needs_compaction = false;
    }
    else {
        event.needs_compaction = true;
    }
}

// Release storage outside a callback. Preserving next_id prevents stale handles matching after reuse.
destroy :: (event: *$E/Event) {
    assert(event.dispatch_depth == 0, "Cannot destroy an event during broadcast.");
    array_reset(*event.callbacks);
    event.dispatch_limit = 0;
    event.needs_compaction = false;
}

#scope_file

#import "Basic";

finish_broadcast :: (event: *$E/Event) {
    event.dispatch_depth -= 1;
    if event.dispatch_depth == 0 && event.needs_compaction {
        compact(event);
    }
}

compact :: (event: *$E/Event) {
    count: int;
    for entry: event.callbacks {
        if entry.callback != null {
            event.callbacks[count] = entry;
            count += 1;
        }
    }
    event.callbacks.count = count;
    event.needs_compaction = false;
}
