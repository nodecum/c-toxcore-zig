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
        const friend_id = try node.addFriendNoRequest(resp.address);
        log.debug("added friend with id:{d}", .{friend_id});
        try Node.check(&node, "friends", friend_id, "name", resp.name);
        try Node.check(&node, "friends", friend_id, "status_message", "responding your messages");
        try node.tox.friend.delete(friend_id);
    }
    // const friend_id = try node.addFriend(
    //     resp.address,
    //     "Here comes the test.",
    // );
    // log.info("added friend with id:{d}", .{friend_id});
    // try Node.check(&node, "friends", friend_id, "name", "response-node");
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
