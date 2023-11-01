const std = @import("std");

const c = @cImport({
    @cInclude("toxcore/tox.h");
});
const Tox = @This();

const log = std.log.scoped(.tox);

/// Type of proxy used to connect to TCP relays.
pub const ProxyType = enum(c.enum_Tox_Proxy_Type) {
    /// Don't use a proxy.
    none = c.TOX_PROXY_TYPE_NONE,
    /// HTTP proxy using CONNECT.
    http = c.TOX_PROXY_TYPE_HTTP,
    /// SOCKS proxy for simple socket pipes.
    socks5 = c.TOX_PROXY_TYPE_SOCKS5,
};

/// Type of savedata to create the Tox instance from.
pub const SavedataType = enum(c.enum_Tox_Savedata_Type) {
    /// No savedata.
    none = c.TOX_SAVEDATA_TYPE_NONE,
    /// Savedata is one that was obtained from tox_get_savedata.
    save = c.TOX_SAVEDATA_TYPE_TOX_SAVE,
    /// Savedata is a secret key of length TOX_SECRET_KEY_SIZE.
    key = c.TOX_SAVEDATA_TYPE_SECRET_KEY,
};

///  Severity level of log messages.
pub const Options = struct {
    /// The type of socket to create.
    ///
    /// If this is set to false, an IPv4 socket is created, which subsequently
    /// only allows IPv4 communication.
    /// If it is set to true, an IPv6 socket is created, allowing both IPv4 and
    /// IPv6 communication.
    ipv6_enabled: bool = true,

    /// Enable the use of UDP communication when available.
    ///
    /// Setting this to false will force Tox to use TCP only. Communications will
    /// need to be relayed through a TCP relay node, potentially slowing them down.
    /// If a proxy is enabled, UDP will be disabled if either toxcore or the
    /// proxy don't support proxying UDP messages.
    udp_enabled: bool = true,

    /// Enable local network peer discovery.
    ///
    /// Disabling this will cause Tox to not look for peers on the local network.
    local_discovery_enabled: bool = true,

    /// Enable storing DHT announcements and forwarding corresponding requests.
    ///
    /// Disabling this will cause Tox to ignore the relevant packets.
    dht_announcements_enabled: bool = true,

    /// Pass communications through a proxy.
    proxy_type: ProxyType = ProxyType.none,

    /// The IP address or DNS name of the proxy to be used.
    ///
    /// If used, this must be non-NULL and be a valid DNS name. The name must not
    /// exceed TOX_MAX_HOSTNAME_LENGTH characters, and be in a NUL-terminated C string
    /// format (TOX_MAX_HOSTNAME_LENGTH includes the NUL byte).
    ///
    /// This member is ignored (it can be NULL) if proxy_type is TOX_PROXY_TYPE_NONE.
    ///
    /// The data pointed at by this member is owned by the user, so must
    /// outlive the options object.
    proxy_host: ?[:0]const u8 = null,

    /// The port to use to connect to the proxy server.
    ///
    /// Ports must be in the range (1, 65535). The value is ignored if
    /// proxy_type is TOX_PROXY_TYPE_NONE.
    proxy_port: ?u16 = null,

    /// The start port of the inclusive port range to attempt to use.
    ///
    /// If both start_port and end_port are 0, the default port range will be
    /// used: `[33445, 33545]`.
    ///
    /// If either start_port or end_port is 0 while the other is non-zero, the
    /// non-zero port will be the only port in the range.
    ///
    /// Having start_port > end_port will yield the same behavior as if start_port
    /// and end_port were swapped.
    start_port: u16 = 0,

    /// The end port of the inclusive port range to attempt to use.
    end_port: u16 = 0,

    /// The port to use for the TCP server (relay). If 0, the TCP server is
    /// disabled.
    ///
    /// Enabling it is not required for Tox to function properly.
    ///
    /// When enabled, your Tox instance can act as a TCP relay for other Tox
    /// instance. This leads to increased traffic, thus when writing a client
    /// it is recommended to enable TCP server only if the user has an option
    /// to disable it.
    tcp_port: u16 = 0,

    /// Enables or disables UDP hole-punching in toxcore. (Default: enabled).
    hole_punching_enabled: bool = true,

    /// The type of savedata to load from.
    savedata_type: SavedataType = SavedataType.none,

    /// The savedata.
    ///
    /// The data pointed at by this member is owned by the user, so must
    /// outlive the options object.
    // const uint8_t *savedata_data;
    savedata_data: ?[:0]const u8 = null,
    // The length of the savedata.
    // size_t savedata_length;
    /// if enabled, log traces as debug messages
    log_traces: bool = true,
    log: bool = true,

    /// Logging callback for the new tox instance.
    //log_cb: ?*log_callback;

    /// User data pointer passed to the logging callback.
    //user_data: ;

    experimental_thread_safety: bool = false,
};

// pub const Tox = struct {
handle: *c.Tox,

const Error = error{
    ToxOptionsMallocFailed,
    ToxOptionsProxyHostTooLong,
    ToxOptionsProxyHostMissing,
    ToxOptionsProxyPortMissing,
    ToxOptionsSavedataDataMissing,
    /// One of the arguments to the function was NULL when it was not expected.
    ToxNewNull,
    /// The function was unable to allocate enough memory to store the events_alloc
    /// structures for the Tox object.
    ToxNewMalloc,
    /// The function was unable to bind to a port. This may mean that all ports
    /// have already been bound, e.g. by other Tox instances, or it may mean
    /// a permission error. You may be able to gather more information from errno.
    ToxNewPortAlloc,
    /// proxy_type was invalid.
    ToxNewProxyBadType,
    /// proxy_type was valid but the proxy_host passed had an invalid format
    /// or was NULL.
    ToxNewProxyBadHost,
    /// proxy_type was valid, but the proxy_port was invalid.
    ToxNewProxyBadPort,
    /// The proxy address passed could not be resolved.
    ToxNewProxyNotFound,
    /// The byte array to be loaded contained an encrypted save.
    ToxNewLoadEncrypted,
    /// The data format was invalid. This can happen when loading data that was
    /// saved by an older version of Tox, or when the data has been corrupted.
    /// When loading from badly formatted data, some data may have been loaded,
    /// and the rest is discarded. Passing an invalid length parameter also
    /// causes this error.
    ToxNewLoadBadFormat,
};

pub fn init(opt: Options) !Tox {
    var self: Tox = Tox{ .handle = undefined };
    var err_opt: c.Tox_Err_Options_New = c.TOX_ERR_OPTIONS_NEW_OK;
    var o: [*c]c.struct_Tox_Options =
        c.tox_options_new(&err_opt);
    if (err_opt != c.TOX_ERR_OPTIONS_NEW_OK)
        return error.ToxOptionsMallocFailed;
    defer c.tox_options_free(o);
    c.tox_options_set_ipv6_enabled(o, opt.ipv6_enabled);
    c.tox_options_set_udp_enabled(o, opt.udp_enabled);
    c.tox_options_set_hole_punching_enabled(o, opt.hole_punching_enabled);
    c.tox_options_set_local_discovery_enabled(o, opt.local_discovery_enabled);
    c.tox_options_set_dht_announcements_enabled(o, opt.dht_announcements_enabled);
    c.tox_options_set_experimental_thread_safety(o, opt.experimental_thread_safety);
    c.tox_options_set_proxy_type(o, @intFromEnum(opt.proxy_type));
    if (opt.proxy_type != ProxyType.none) {
        if (opt.proxy_host) |host| {
            if (host.len > c.TOX_MAX_HOSTNAME_LENGTH)
                return error.ToxOptionsProxyHostTooLong;
            c.tox_options_set_proxy_host(o, host);
        } else return error.ToxOptionsProxyHostMissing;
        if (opt.proxy_port) |port| {
            c.tox_options_set_proxy_port(o, port);
        } else return error.ToxOptionsProxyPortMissing;
    }
    c.tox_options_set_savedata_type(o, @intFromEnum(opt.savedata_type));
    if (opt.savedata_type != SavedataType.none) {
        if (opt.savedata_data) |data| {
            c.tox_options_set_savedata_data(o, data, data.len);
        } else return error.ToxOptionsSavedataDataMissing;
    }
    if (opt.log) {
        c.tox_options_set_log_callback(o, &tox_log);
    }
    var err: c.Tox_Err_New = undefined;
    const maybe_tox = c.tox_new(o, &err);
    switch (err) {
        c.TOX_ERR_NEW_OK => {},
        c.TOX_ERR_NEW_NULL => {
            return error.ToxNewNull;
        },
        c.TOX_ERR_NEW_MALLOC => {
            return error.ToxNewMalloc;
        },
        c.TOX_ERR_NEW_PORT_ALLOC => {
            return error.ToxNewPortAlloc;
        },
        c.TOX_ERR_NEW_PROXY_BAD_TYPE => {
            return error.ToxNewProxyBadType;
        },
        c.TOX_ERR_NEW_PROXY_BAD_HOST => {
            return error.ToxNewProxyBadHost;
        },
        c.TOX_ERR_NEW_PROXY_BAD_PORT => {
            return error.ToxNewProxyBadPort;
        },
        c.TOX_ERR_NEW_PROXY_NOT_FOUND => {
            return error.ToxNewProxyNotFound;
        },
        c.TOX_ERR_NEW_LOAD_ENCRYPTED => {
            return error.ToxNewLoadEncrypted;
        },
        c.TOX_ERR_NEW_LOAD_BAD_FORMAT => {
            return error.ToxNewLoadBadFormat;
        },
        else => {},
    }
    if (maybe_tox) |tox| {
        self.handle = tox;
    } else {
        return error.ToxNewFailed;
    }
    log.info("Created new tox instance", .{});
    return self;
}

fn tox_log(
    tox: ?*c.Tox,
    level: c.Tox_Log_Level,
    file: [*c]const u8,
    line: u32,
    func: [*c]const u8,
    message: [*c]const u8,
    user_data: ?*anyopaque,
) callconv(.C) void {
    const fmt = "[{s}:{d}:{s}]:{s}";
    const arg = .{ file, line, func, message };

    switch (level) {
        c.TOX_LOG_LEVEL_TRACE => {
            log.debug(fmt, arg);
        },
        // Debug messages such as which port we bind to.
        c.TOX_LOG_LEVEL_DEBUG => {
            log.debug(fmt, arg);
        },
        // Informational log messages such as video call status changes.
        c.TOX_LOG_LEVEL_INFO => {
            log.info(fmt, arg);
        },
        // Warnings about events_alloc inconsistency or logic errors.
        c.TOX_LOG_LEVEL_WARNING => {
            log.warn(fmt, arg);
        },
        // Severe unexpected errors caused by external or events_alloc inconsistency.
        c.TOX_LOG_LEVEL_ERROR => {
            log.err(fmt, arg);
        },
        else => {
            log.err(fmt, arg);
        },
    }
    _ = tox;
    _ = user_data;
}

pub fn deinit(self: Tox) void {
    c.tox_kill(self.handle);
}

//pub const std_options = struct {
//    pub const log_level = .debug;
//};

test "tox_new" {
    var tox = try init(.{});
    defer tox.deinit();
}
