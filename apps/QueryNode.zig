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
            .timeout = query.timeout,
            .keep_running = keep_running,
        },
    );
    defer node.deinit();
    try node.setName(node.name, "test the tox api");
    var addrBuf: [Tox.address_size * 2]u8 = undefined;
    log.debug("my address is: {s}", .{try node.getAddress(&addrBuf)});
    try node.bootstrap(boot.host, boot.port, boot.public_key);
    const friend_status_message = "responding your messages";
    //{
    const friend_id = try node.friendAddNoRequest(resp.address);
    log.debug("added friend with id:{d}", .{friend_id});
    try Node.check(&node, "friends", friend_id, "name", resp.name);
    try Node.check(&node, "friends", friend_id, "status_message", friend_status_message);
    // if we delete we loose te name ... etc
    // so we just leave it out here
    //try node.tox.friend.delete(friend_id);
    //}
    // friend.add
    //const friend_id = try node.friendAdd(resp.address, "Here comes the test.");
    //log.debug("added friend with id:{d}", .{friend_id});
    //try Node.check(&node, "friends", friend_id, "name", resp.name);
    // friend.byPublicKey
    {
        const friend_id_pk = try node.friendByPublicKey(resp.public_key);
        if (friend_id != friend_id_pk) {
            log.err("friend by public key returns {d}, expected {d}", .{ friend_id_pk, friend_id });
            return error.Mismatch;
        }
    }
    // friend.exists
    if (!node.tox.friend.exists(friend_id)) {
        log.err("friend with id {d} should exist.", .{friend_id});
        return error.Mismatch;
    }
    // friend.listSize
    if (node.tox.friend.listSize() != 1) {
        log.err("friend list size should be 1.", .{});
        return error.Mismatch;
    }
    // friend.getList
    {
        var friend_list: [1]u32 = undefined;
        _ = try node.tox.friend.getList(&friend_list);
        if (friend_list[0] != friend_id) {
            log.err("friend list should contain friend id {d}.", .{friend_id});
            return error.Mismatch;
        }
    }
    // friend.getPublicKey
    {
        const public_key_hex_size = sodium.crypto_box.public_key_size * 2;
        var public_key: [public_key_hex_size]u8 = undefined;
        const public_key_hex = try node.friendGetPublicKey(friend_id, &public_key);
        if (!std.mem.eql(u8, public_key_hex, resp.public_key)) {
            log.err(
                "friend({d}) public key does not match,\nexpected:'{s}'\nfound:'{s}'",
                .{ friend_id, resp.public_key, public_key_hex },
            );
            return error.Mismatch;
        }
    }
    // friend.lastOnline
    {
        const time = try node.tox.friend.lastOnline(friend_id);
        log.debug("friend({d}) last online:{d}", .{ friend_id, time });
    }
    // friend.nameSize & friend.name
    {
        const size = try node.tox.friend.nameSize(friend_id);
        const name_buf = try allocator.alloc(u8, size);
        defer allocator.free(name_buf);
        const name = try node.tox.friend.name(friend_id, name_buf);
        if (!std.mem.eql(u8, name, resp.name)) {
            log.err(
                "friend({d}) name not match,expected:'{s}',found:'{s}',nameSize:{d}",
                .{ friend_id, resp.name, name, size },
            );
            return error.Mismatch;
        }
    }
    // friend.statusMessageSize & friend.statusMessage
    {
        const size = try node.tox.friend.statusMessageSize(friend_id);
        const msg_buf = try allocator.alloc(u8, size);
        defer allocator.free(msg_buf);
        const msg = try node.tox.friend.statusMessage(friend_id, msg_buf);
        if (!std.mem.eql(u8, msg, friend_status_message)) {
            log.err(
                "friend({d}) name not match,expected:'{s}',found:'{s}',nameSize:{d}",
                .{ friend_id, friend_status_message, msg, size },
            );
            return error.Mismatch;
        }
    }
    // friend.userStatus
    {
        const status = try node.tox.friend.userStatus(friend_id);
        log.debug(
            "friend({d}) user status:{d}",
            .{ friend_id, @intFromEnum(status) },
        );
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
    defer @atomicStore(bool, keep_running, false, .seq_cst);
    run_(allocator, query, boot, resp, keep_running) catch |err| {
        log.err("{s}", .{@errorName(err)});
        @atomicStore(bool, failed, true, .seq_cst);
    };
}
