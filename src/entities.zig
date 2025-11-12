const main = @import("main.zig");
const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub const Entity = enum(u64) { null = 0, _ };

const AttributeStoreMap = std.AutoHashMap(utils.TypeId, *anyopaque);
var attributeStores: AttributeStoreMap = undefined;

var nextEntityId: u64 = 1;
pub var entityCount: u64 = 0;

pub fn init() !void {}

pub fn deinit() void {}

pub fn registerAttribute(T: type, store: *anyopaque) void {
    //TODO compile error if T is not struct/union/enum, singular, and non-nullable
    //TODO error on type id collision

    attributeStores = AttributeStoreMap.init(main.alloc);
    attributeStores.put(utils.typeId(T), store) catch unreachable;
}

pub fn createEntity() Entity {
    const ent: Entity = @enumFromInt(nextEntityId);
    nextEntityId += 1;
    entityCount += 1;
    return ent;
}

pub fn deleteEntity(entity: Entity) void {
    var stores = attributeStores.valueIterator();
    while (stores.next()) |store| {
        store.delete(entity);
    }

    entityCount -= 1;
}

pub fn getAttribute(T: type, entity: Entity) ?*const T {
    const store = getAttributeStore(T);
    if (store == null) return null;

    return store.?.get(entity);
}

pub fn setAttribute(T: type, entity: Entity, value: ?T) void {
    const store = getAttributeStore(T);
    store.?.set(entity, if (value == null) null else &value.?);
}

fn getAttributeStore(T: type) ?*AttributeStore(T) {
    return @ptrCast(@alignCast(attributeStores.getPtr(utils.typeId(T))));
}

pub fn AttributeStore(T: type) type {
    return struct {
        const Self = @This();

        //TODO chunked attribute data
        entries: [10]struct { entity: Entity, value: T } = undefined,
        len: usize = 0,

        pub fn findIndex(self: *const Self, entity: Entity) ?usize {
            for (0..self.len) |i| {
                if (self.entries[i].entity == entity) return i;
            }

            return null;
        }

        pub fn get(self: *const Self, entity: Entity) ?*const T {
            const idx = self.findIndex(entity);
            if (idx == null) return null;

            return &self.entries[idx.?].value;
        }

        pub fn set(self: *Self, entity: Entity, value: ?*const T) void {
            const idx = self.findIndex(entity);

            if (value == null) {
                //TODO mark as empty
                return;
            }

            if (idx == null) {
                //TODO dynamic resize
                if (self.entries.len <= self.len) {
                    std.log.err("ATTRIBUTE STORE OUT OF SPACE", .{});
                    return;
                }

                self.entries[self.len] = .{ .entity = entity, .value = value.?.* };
                self.len += 1;
            } else {
                self.entries[idx.?] = .{ .entity = entity, .value = value.?.* };
            }
        }
    };
}
