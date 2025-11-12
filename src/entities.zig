const main = @import("main.zig");
const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub const Entity = enum(u64) { null = 0, _ };

const AttributeStoreMap = std.AutoHashMap(utils.TypeId, *anyopaque);
var attributeStores: AttributeStoreMap = undefined;

var nextEntityId: u64 = 1;
pub var entityCount: u64 = 0;

pub fn init() !void {
    attributeStores = AttributeStoreMap.init(main.alloc);
}

pub fn deinit() void {
    attributeStores.deinit();
}

pub fn registerAttribute(T: type, store: *anyopaque) void {
    //TODO compile error if T is not struct/union/enum, singular, and non-nullable
    //TODO error on type id collision

    attributeStores.put(utils.typeId(T), store) catch unreachable;
}

pub fn createEntity() Entity {
    const ent: Entity = @enumFromInt(nextEntityId);
    nextEntityId += 1;
    entityCount += 1;
    return ent;
}

//TODO handle with store interface
pub fn deleteEntity(_: Entity) void {
    // var stores = attributeStores.valueIterator();
    // while (stores.next()) |store| {
    //     store.set(entity, null);
    // }

    // entityCount -= 1;
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
        const Entry = struct { entity: Entity, value: T };

        //TODO chunked attribute data
        entries: [10]Entry = undefined,
        len: usize = 0,

        pub fn findIndex(self: *const Self, entity: Entity) ?usize {
            for (0..self.len) |i| {
                if (self.entries[i].entity == entity) return i;
            }

            return null;
        }

        /// Returns the nth entry
        pub fn getNth(self: *const Self, n: usize) *const Entry {
            //TODO handle sparse entities
            return &self.entries[n];
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

fn QueryResult(comptime includeFields: []const std.builtin.Type.StructField) type {
    var fields: [includeFields.len + 1]std.builtin.Type.StructField = undefined;

    for (includeFields, 0..) |include, i| {
        fields[i] = .{
            .name = include.name,
            .type = @Type(.{ .pointer = .{
                .size = .one,
                .is_const = true,
                .is_volatile = false,
                .alignment = @alignOf(include.type),
                .address_space = .generic,
                .child = include.type,
                .is_allowzero = false,
                .sentinel_ptr = null,
            } }),
            .default_value_ptr = include.default_value_ptr,
            .is_comptime = include.is_comptime,
            .alignment = include.alignment,
        };
    }

    fields[includeFields.len] = .{
        .name = "entity",
        .type = Entity,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(Entity),
    };

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .is_tuple = false,
        .decls = &.{},
        .fields = &fields,
    } });
}

//TODO With(T, name), Without(T) wrapper types?
//TODO With(?T, name) is an optional include
pub fn Query(Includes: type, Excludes: []const type) type {
    //TODO compile error when Includes is not a struct or no primary include
    const includeFields = std.meta.fields(Includes);
    const primaryIncludeField = includeFields[0];

    return struct {
        pub const Result = QueryResult(includeFields);

        pub const Iterator = struct {
            primaryIncludeStore: *const AttributeStore(primaryIncludeField.type),
            secondaryIncludeStores: [includeFields.len - 1]*const anyopaque,
            excludeStores: [Excludes.len]*const anyopaque,
            index: usize = 0,

            fn init() Iterator {
                var inclStores: [includeFields.len - 1]*const anyopaque = undefined;
                inline for (1..includeFields.len) |i| inclStores[i - 1] = getAttributeStore(includeFields[i].type).?;

                var exclStores: [Excludes.len]*const anyopaque = undefined;
                inline for (0..Excludes.len) |i| exclStores[i] = getAttributeStore(Excludes[i]).?;

                return .{
                    .primaryIncludeStore = getAttributeStore(primaryIncludeField.type).?,
                    .secondaryIncludeStores = inclStores,
                    .excludeStores = exclStores,
                };
            }

            pub fn next(self: *Iterator) ?Result {
                var valid = false;
                var inclBuffer: [includeFields.len]*const anyopaque = undefined;
                var entity: Entity = undefined;

                if (self.index >= self.primaryIncludeStore.len) return null;

                // iterate until valid value is found or there are no remaining primary include entries
                var counter: usize = 0;
                for (self.index..self.primaryIncludeStore.len) |i| {
                    counter += 1;
                    if (valid) break;

                    const primaryIncl = self.primaryIncludeStore.getNth(i);
                    entity = primaryIncl.entity;

                    valid = true;

                    inclBuffer[0] = &primaryIncl.value;

                    // check for secondary includes
                    inline for (self.secondaryIncludeStores, 1..) |storePtr, j| {
                        const store: *const AttributeStore(includeFields[j].type) = @ptrCast(@alignCast(storePtr));
                        const incl = store.get(primaryIncl.entity);
                        if (incl) |ptr| {
                            inclBuffer[j] = ptr;
                        } else {
                            valid = false;
                            break;
                        }
                    }

                    // if a secondary include was missing, continue
                    if (!valid) continue;

                    // check for excludes
                    inline for (self.excludeStores, 0..) |storePtr, j| {
                        const store: *const AttributeStore(Excludes[j]) = @ptrCast(@alignCast(storePtr));
                        const excl = store.get(primaryIncl.entity);
                        if (excl != null) {
                            valid = false;
                            break;
                        }
                    }
                }

                // build and return query result
                var result: Result = undefined;
                inline for (0..includeFields.len) |i| {
                    @field(result, includeFields[i].name) = @ptrCast(@alignCast(inclBuffer[i]));
                }

                result.entity = entity;

                self.index += counter;
                return result;
            }
        };

        pub fn iterate() Iterator {
            return Iterator.init();
        }

        pub fn first() ?Result {
            var iter = Iterator.init();
            return iter.next();
        }
    };
}
