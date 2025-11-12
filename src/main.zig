const std = @import("std");
const modules = @import("modules.zig");

var a = std.heap.DebugAllocator(.{}){};
pub const alloc = a.allocator();

const engine = modules.Engine(&[_]type{
    @import("modules/hitpoints.zig"),
});

pub fn main() void {
    engine.start(alloc, start) catch unreachable;
}

fn start() void {
    std.log.debug("Hello Miniverse!", .{});
}
