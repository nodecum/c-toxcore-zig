const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");
const Node = @import("Node.zig");
const NodeInfo = @import("NodeInfo.zig");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.QueryNode);

fn run_(
    allocator: Allocator,
    query: NodeInfo,
    boot: NodeInfo,
    resp: NodeInfo,
    keep_running: *bool,
) !void {
    var node = try Node.init(
        allocator,
        .{
            .name = query.name,
            .secret_key = query.secret_key,
            .nospam = query.nospam,
            .port = query.port,
            .timeout = 20000,
            .keep_running = keep_running,
        },
    );
    defer node.deinit();
    try node.setName(node.name, "test the tox api");
    log.debug("my address is: {s}", .{try node.getAddress()});
    try node.bootstrap(boot.host, boot.port, boot.public_key);
    {
        const friend_id = try node.friendAddNoRequest(resp.address);
        log.debug("added friend with id:{d}", .{friend_id});
        try Node.check(&node, "friends", friend_id, "name", resp.name);
        try Node.check(&node, "friends", friend_id, "status_message", "responding your messages");
        try node.tox.friend.delete(friend_id);
    }
    const friend_id = try node.friendAdd(resp.address, "Here comes the test.");
    log.debug("added friend with id:{d}", .{friend_id});
    try Node.check(&node, "friends", friend_id, "name", resp.name);
    const friend_id_pk = try node.friendByPublicKey(resp.public_key);
    if (friend_id != friend_id_pk) {
        log.err("friend by public key returns {d}, expected {d}", .{ friend_id_pk, friend_id });
        return error.Mismatch;
    }
    if (!node.tox.friend.exists(friend_id)) {
        log.err("friend with id {d} should exist.", .{friend_id});
        return error.Mismatch;
    }
    if (node.tox.friend.listSize() != 1) {
        log.err("friend list size should be 1.", .{});
        return error.Mismatch;
    }
    var friend_list: [1]u32 = undefined;
    _ = try node.tox.friend.getList(&friend_list);
    if (friend_list[0] != friend_id) {
        log.err("friend list should contain friend id {d}.", .{friend_id});
        return error.Mismatch;
    }
}

pub fn run(
    allocator: Allocator,
    query: NodeInfo,
    boot: NodeInfo,
    resp: NodeInfo,
    keep_running: *bool,
    failed: *bool,
) void {
    defer @atomicStore(bool, keep_running, false, .SeqCst);
    run_(allocator, query, boot, resp, keep_running) catch |err| {
        log.err("{s}", .{@errorName(err)});
        @atomicStore(bool, failed, true, .SeqCst);
    };
}
