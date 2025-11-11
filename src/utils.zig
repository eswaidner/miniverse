const std = @import("std");

const Instant = std.time.Instant;

pub fn secondsBetween(previous: Instant, current: Instant) f64 {
    return @as(f64, @floatFromInt(current.since(previous))) / std.time.ns_per_s;
}

pub const TypeId = *const struct { _: u8 };

pub inline fn typeId(comptime T: type) TypeId {
    return &struct {
        comptime {
            _ = T;
        }
        var id: @typeInfo(TypeId).pointer.child = undefined;
    }.id;
}
