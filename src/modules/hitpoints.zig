const std = @import("std");
const entities = @import("../entities.zig");

var hpStore: entities.AttributeStore(Hitpoints) = undefined;

pub const Hitpoints = struct {
    value: f32,
};

pub fn init() !void {
    hpStore = .{};
    entities.registerAttribute(Hitpoints, &hpStore);

    const e1 = entities.createEntity();
    entities.setAttribute(Hitpoints, e1, .{ .value = 100 });
    _ = entities.getAttribute(Hitpoints, e1);
    entities.setAttribute(Hitpoints, e1, null);
}

pub fn deinit() void {}
