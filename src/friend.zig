///! Friend list management
const std = @import("std");
const Friend = @This();
const Tox = @import("tox.zig");
const c = @cImport({
    @cInclude("toxcore/tox.h");
});
const wrap = @import("wrap.zig");
handle: *c.Tox,

pub const ErrAdd = enum(c.Tox_Err_Friend_Add) {
    Ok = c.TOX_ERR_FRIEND_ADD_OK,
    // One of the arguments to the function was NULL when it was not expected.
    Null = c.TOX_ERR_FRIEND_ADD_NULL,
    /// The length of the friend request message exceeded
    /// TOX_MAX_FRIEND_REQUEST_LENGTH.
    TooLong = c.TOX_ERR_FRIEND_ADD_TOO_LONG,
    /// The friend request message was empty. This, and the TOO_LONG code will
    /// never be returned from tox_friend_add_norequest.
    NoMessage = c.TOX_ERR_FRIEND_ADD_NO_MESSAGE,
    /// The friend address belongs to the sending client.
    OwnKey = c.TOX_ERR_FRIEND_ADD_OWN_KEY,
    /// A friend request has already been sent, or the address belongs to a friend
    /// that is already on the friend list.
    AlreadySent = c.TOX_ERR_FRIEND_ADD_ALREADY_SENT,
    /// The friend address checksum failed.
    BadChecksum = c.TOX_ERR_FRIEND_ADD_BAD_CHECKSUM,
    /// The friend was already there, but the nospam value was different.
    SetNewNospam = c.TOX_ERR_FRIEND_ADD_SET_NEW_NOSPAM,
    /// A memory allocation failed when trying to increase the friend list size.
    Malloc = c.TOX_ERR_FRIEND_ADD_MALLOC,
};

/// @brief Add a friend to the friend list and send a friend request.
///
/// A friend request message must be at least 1 byte long and at most
/// TOX_MAX_FRIEND_REQUEST_LENGTH.
///
/// Friend numbers are unique identifiers used in all functions that operate on
/// friends. Once added, a friend number is stable for the lifetime of the Tox
/// object. After saving the state and reloading it, the friend numbers may not
/// be the same as before. Deleting a friend creates a gap in the friend number
/// set, which is filled by the next adding of a friend. Any pattern in friend
/// numbers should not be relied on.
///
/// If more than INT32_MAX friends are added, this function causes undefined
/// behaviour.
///
/// @param address The address of the friend (returned by tox_self_get_address of
///   the friend you wish to add) it must be TOX_ADDRESS_SIZE bytes.
/// @param message The message that will be sent along with the friend request.
/// @param length The length of the data byte array.
///
/// @return the friend number on success, an unspecified value on failure.
pub fn add(self: anytype, address: []const u8, message: []const u8) !u32 {
    return wrap.getResult(
        c.tox_friend_add,
        self,
        .{
            @as([*c]const u8, @ptrCast(address)),
            @as([*c]const u8, @ptrCast(message)),
            message.len,
        },
        ErrAdd,
    );
}

/// @brief Add a friend without sending a friend request.
///
/// This function is used to add a friend in response to a friend request. If the
/// client receives a friend request, it can be reasonably sure that the other
/// client added this client as a friend, eliminating the need for a friend
/// request.
///
/// This function is also useful in a situation where both instances are
/// controlled by the same entity, so that this entity can perform the mutual
/// friend adding. In this case, there is no need for a friend request, either.
///
/// @param public_key A byte array of length TOX_PUBLIC_KEY_SIZE containing the
///   Public Key (not the Address) of the friend to add.
///
/// @return the friend number on success, an unspecified value on failure.
/// @see tox_friend_add for a more detailed description of friend numbers.
pub fn addNoRequest(self: anytype, public_key: []const u8) !u32 {
    return wrap.getResult(
        c.tox_friend_add_norequest,
        self,
        .{@as([*c]const u8, @ptrCast(public_key))},
        ErrAdd,
    );
}

pub const ErrDelete = enum(c.Tox_Err_Friend_Delete) {
    Ok = c.TOX_ERR_FRIEND_DELETE_OK,
    NotFound = c.TOX_ERR_FRIEND_DELETE_FRIEND_NOT_FOUND,
};
/// @brief Remove a friend from the friend list.
///
/// This does not notify the friend of their deletion. After calling this
/// function, this client will appear offline to the friend and no communication
/// can occur between the two.
/// @param friend_number Friend number for the friend to be deleted.
pub fn delete(self: anytype, friend_number: u32) wrap.ErrSet(ErrDelete)!void {
    _ = try wrap.getResult(c.tox_friend_delete, self, .{friend_number}, ErrDelete);
}

pub const ErrByPublicKey = enum(c.Tox_Err_Friend_By_Public_Key) {
    Ok = c.TOX_ERR_FRIEND_BY_PUBLIC_KEY_OK,
    Null = c.TOX_ERR_FRIEND_BY_PUBLIC_KEY_NULL,
    NotFound = c.TOX_ERR_FRIEND_BY_PUBLIC_KEY_NOT_FOUND,
};
/// @brief Return the friend number associated with that Public Key.
/// @return the friend number on success,
/// @param public_key A byte array containing the Public Key.
pub fn byPublicKey(
    self: anytype,
    public_key: []const u8,
) wrap.ErrSet(ErrByPublicKey)!u32 {
    return wrap.getResult(
        c.tox_friend_by_public_key,
        self,
        .{@as([*c]const u8, @ptrCast(public_key))},
        ErrByPublicKey,
    );
}

/// @brief Checks if a friend with the given friend number exists and returns true if
/// it does.
pub fn exists(self: anytype, friend_number: u32) bool {
    return c.tox_friend_exists(self.handle, friend_number);
}

/// @brief Return the number of friends on the friend list.
///
/// This function can be used to determine how much memory to allocate for
/// tox_self_get_friend_list.
pub fn listSize(self: anytype) usize {
    return c.tox_self_get_friend_list_size(self.handle);
}
/// @brief Copy a list of valid friend numbers into an array.
///
/// Call tox_self_get_friend_list_size to determine the number of elements to allocate.
///
/// @param friend_list A memory region with enough space to hold the friend
/// list.
/// returns the slice of friend numbers or error.BufferTooSmall if buffer is not big enough.
pub fn getList(self: anytype, friend_list: []u32) ![]const u32 {
    const list_size = self.listSize();
    if (list_size > friend_list.len) return error.BufferTooSmall;
    c.tox_self_get_friend_list(self.handle, @ptrCast(friend_list));
    return friend_list[0..list_size];
}

pub const ErrGetPublicKey = enum(c.Tox_Err_Friend_Get_Public_Key) {
    Ok = c.TOX_ERR_FRIEND_GET_PUBLIC_KEY_OK,
    NotFound = c.TOX_ERR_FRIEND_GET_PUBLIC_KEY_FRIEND_NOT_FOUND,
};
/// @brief Copies the Public Key associated with a given friend number to a byte array.
///
/// @param friend_number The friend number you want the Public Key of.
/// @param public_key A memory region of at least TOX_PUBLIC_KEY_SIZE bytes.
///
/// @return the key on success, error.BufferToSmall or error.NotFound.
pub fn getPublicKey(self: anytype, friend_id: u32, public_key: []u8) ![]const u8 {
    return wrap.fillBuffer(
        c.tox_friend_get_public_key,
        self,
        .{friend_id},
        public_key,
        Tox.publicKeySize(),
        ErrGetPublicKey,
    );
}
pub const ErrLastOnline = enum(c.Tox_Err_Friend_Get_Last_Online) {
    Ok = c.TOX_ERR_FRIEND_GET_LAST_ONLINE_OK,
    NotFound = c.TOX_ERR_FRIEND_GET_LAST_ONLINE_FRIEND_NOT_FOUND,
};

/// @brief Return a unix-time timestamp of the last time the friend associated with a given
/// friend number was seen online.
///
/// This function will return error.NotFound on error.
///
/// @param friend_number The friend number you want to query.
pub fn lastOnline(self: anytype, friend_number: u32) !u64 {
    return wrap.getResult(
        c.tox_friend_get_last_online,
        self,
        .{friend_number},
        ErrLastOnline,
    );
}

pub const ErrQuery = enum(c.Tox_Err_Friend_Query) {
    Ok = c.TOX_ERR_FRIEND_QUERY_OK,
    Null = c.TOX_ERR_FRIEND_QUERY_NULL,
    NotFound = c.TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND,
};

/// @brief Return the length of the friend's name.
///
/// If the friend number is invalid, the return value is unspecified.
///
/// The return value is equal to the `length` argument received by the last
/// `friend_name` callback.
pub fn nameSize(self: anytype, friend_number: u32) wrap.ErrSet(ErrQuery)!usize {
    return wrap.getResult(
        c.tox_friend_get_name_size,
        self,
        .{friend_number},
        ErrQuery,
    );
}

/// @brief Write the name of the friend designated by the given friend number to a byte
/// array.
///
/// Call tox_friend_get_name_size to determine the allocation size for the `name`
/// parameter.
///
/// The data written to `name` is equal to the data received by the last
/// `friend_name` callback.
///
/// @param name A valid memory region large enough to store the friend's name.
///
pub fn name(self: anytype, friend_number: u32, name_buffer: []u8) ![]const u8 {
    return wrap.fillBuffer(
        c.tox_friend_get_name,
        self,
        .{friend_number},
        name_buffer,
        try nameSize(self, friend_number),
        ErrQuery,
    );
}

/// Sets the name callback handler.
/// `context` may be a pointer or `{}`.
pub fn nameCallback(self: anytype, ctx: anytype, comptime hd: anytype) void {
    wrap.setCallback(
        self,
        ctx,
        c.tox_callback_friend_name,
        .{ u32, .{ []const u8, [*c]const u8, usize } },
        .{},
        hd,
    );
}

/// @brief Return the length of the friend's status message.
/// If the friend number is invalid error.NotFound will be returned.
pub fn statusMessageSize(self: anytype, friend_id: u32) wrap.ErrSet(ErrQuery)!usize {
    return wrap.getResult(
        c.tox_friend_get_status_message_size,
        self,
        .{friend_id},
        ErrQuery,
    );
}

/// @Brief Write the status message of the friend designated by the given friend number to a byte
/// array.
/// Call tox_friend_get_status_message_size to determine the allocation size for the `status_message`
/// parameter.
/// The data written to `status_message` is equal to the data received by the last
/// `friend_status_message` callback.
///
/// @param status_message A valid memory region large enough to store the friend's status message.
pub fn statusMessage(self: anytype, friend_number: u32, status_message_buffer: []u8) ![]const u8 {
    return wrap.fillBuffer(
        c.tox_friend_get_status_message,
        self,
        .{friend_number},
        status_message_buffer,
        try statusMessageSize(self, friend_number),
        ErrQuery,
    );
}

/// Sets the status message callback handler.
/// `context` may be a pointer or `{}`.
pub fn statusMessageCallback(
    self: anytype,
    ctx: anytype,
    comptime hd: anytype,
) void {
    wrap.setCallback(
        self,
        ctx,
        c.tox_callback_friend_status_message,
        .{ u32, .{ []const u8, [*c]const u8, usize } },
        .{},
        hd,
    );
}

/// @brief Return the friend's user status (away/busy/...).
///
/// If the friend number is invalid, the return value is unspecified.
///
/// The status returned is equal to the last status received through the
/// `friend_status` callback.
///
/// @deprecated This getter is deprecated. Use the event and store the status
///   in the client state.
pub fn userStatus(self: Friend, friend_id: u32) wrap.ErrSet(ErrQuery)!Tox.UserStatus {
    return @enumFromInt(
        try wrap.getResult(
            c.tox_friend_get_status,
            self,
            .{friend_id},
            ErrQuery,
        ),
    );
}

//pub const tox_friend_status_cb = fn (?*Tox, u32, Tox_User_Status, ?*anyopaque) callconv(.C) void;
//pub extern fn tox_callback_friend_status(tox: ?*Tox, callback: ?*const tox_friend_status_cb) void;

//Tox_User_Status tox_friend_get_status(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error);
// @brief Set the callback for the `friend_status` event.
// Pass NULL to unset.
// This event is triggered when a friend changes their user status.
//void tox_callback_friend_status(Tox *tox, tox_friend_status_cb *callback);

test "Friend test" {
    var tox = try Tox.init(.{});
    defer tox.deinit();
}
