const std = @import("std");

pub const entities = @import("entities.zig");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;
const Instant = std.time.Instant;

var shouldExit: bool = false;

var startInstant: Instant = undefined;
var currentInstant: Instant = undefined;
var prevInstant: Instant = undefined;

var elapsedTime: f64 = 0;
var deltaTime: f64 = 0;

pub var gpa: Allocator = undefined;

pub fn Engine(modules: []const type) type {
    return struct {
        pub fn start(alloc: Allocator, startCallback: ?*const fn () void) !void {
            gpa = alloc;

            startInstant = std.time.Instant.now() catch unreachable;
            currentInstant = startInstant;
            prevInstant = startInstant;

            // try entities.init();

            // init modules
            inline for (modules) |mod| {
                if (std.meta.hasFn(mod, "init")) try mod.init();
            }

            if (startCallback) |f| f();

            //TODO start callback

            while (!shouldExit) {
                update();
            }

            //TODO stop callback

            // deinit modules (in reverse init order)
            if (modules.len > 0) {
                inline for (1..modules.len) |i| {
                    const mod = modules[modules.len - i];
                    if (std.meta.hasFn(mod, "deinit")) mod.deinit();
                }
            }

            // entities.deinit();
        }
    };
}

pub fn stop() void {
    shouldExit = true;
}

fn update() void {
    currentInstant = Instant.now() catch unreachable;
    elapsedTime = utils.secondsBetween(startInstant, currentInstant);
    deltaTime = utils.secondsBetween(prevInstant, currentInstant);

    //TODO update callback

    prevInstant = currentInstant;
}

pub inline fn getElapsedTime() f64 {
    return elapsedTime;
}

pub inline fn getDeltaTime() f64 {
    return deltaTime;
}
