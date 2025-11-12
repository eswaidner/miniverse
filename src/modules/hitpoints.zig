const std = @import("std");
const entities = @import("../entities.zig");

var hpStore: entities.AttributeStore(Hitpoints) = undefined;
var playerStore: entities.AttributeStore(Player) = undefined;

pub const Hitpoints = struct {
    value: f32,
};

pub const Player = struct {};

pub fn init() !void {
    hpStore = .{};
    playerStore = .{};
    entities.registerAttribute(Hitpoints, hpStore.interface());
    entities.registerAttribute(Player, playerStore.interface());

    const e1 = entities.createEntity();

    entities.setAttribute(Hitpoints, e1, .{ .value = 100 });

    _ = entities.getAttribute(Hitpoints, e1);

    const e2 = entities.createEntity();
    entities.setAttribute(Hitpoints, e2, .{ .value = 50 });

    const e3 = entities.createEntity();
    entities.setAttribute(Hitpoints, e3, .{ .value = 75 });
    entities.setAttribute(Player, e3, .{});

    std.log.debug("-----------------", .{});

    const HitpointsQ = entities.Query(struct { hp: Hitpoints }, &[_]type{Player});
    var hpIter = HitpointsQ.iterate();
    while (hpIter.next()) |r| {
        std.log.debug("HP QUERY: {any}", .{r});
    }

    std.log.debug("-----------------", .{});

    const PlayerQ = entities.Query(struct { player: Player, hp: Hitpoints }, &[_]type{});
    var playerIter = PlayerQ.iterate();
    while (playerIter.next()) |r| {
        std.log.debug("PLAYER QUERY: {any}", .{r});
    }

    std.log.debug("-----------------", .{});

    entities.deleteEntity(e1);
}

pub fn deinit() void {}
