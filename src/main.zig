const std = @import("std");
const modules = @import("modules.zig");

var a = std.heap.DebugAllocator(.{}){};
const alloc = a.allocator();

const engine = modules.Engine(&[_]type{});

pub fn main() void {
    engine.start(alloc, start) catch unreachable;
}

fn start() void {
    std.log.debug("Hello Miniverse!", .{});
}
