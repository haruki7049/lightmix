//! # PulseAudio Playback Backend (Linux)
//!
//! Plays a `Buffer` through a PulseAudio server, in Pure Zig. `pipewire-pulse` speaks the same
//! protocol, so this also plays through PipeWire.
//!
//! This backend does not use `libpulse`. It talks the PulseAudio native protocol over the UNIX
//! socket of the server with raw system calls. No library, not even libc, is linked.
//!
//! ## Protocol
//! - The server is `$PULSE_SERVER` (a `unix:` entry or a socket path), else
//!   `$XDG_RUNTIME_DIR/pulse/native`. TCP servers are not supported.
//! - The client authenticates with the cookie (`$PULSE_COOKIE`, `~/.config/pulse/cookie` or
//!   `~/.pulse-cookie`); a missing cookie is sent as zeros, which servers accept from local
//!   sockets. Shared memory is not used: samples are sent through the socket.
//! - The sample rate and the channel count of the `Buffer` are passed to the server as is and
//!   samples are written as 32-bit float. The server converts them to its device, so mono works
//!   on stereo-only hardware.
//!
//! ## Errors
//! `error.ServerUnavailable` is returned when the server cannot be reached or refuses the
//! connection or the stream, before any sample is written, so a caller can fall back to another
//! backend. Every other error happens once the stream exists.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const Buffer = @import("../backend.zig").Buffer;

pub const name = "pulseaudio";

/// Errors returned by `play`.
pub const Error = error{
    /// No server was found, or it refused the connection or the stream. No sample was written.
    ServerUnavailable,
    /// The buffer has no channels, or more than PulseAudio supports.
    UnsupportedChannels,
    /// The server closed the connection.
    ConnectionClosed,
    /// The server did not answer in time.
    TimedOut,
    /// The server sent something this backend does not understand.
    ProtocolError,
    /// The server answered a command with an error.
    ServerError,
    /// The server removed the playback stream.
    StreamKilled,
};

/// Protocol version this client speaks. The server uses the lower of both versions.
const PROTOCOL_VERSION: u32 = 15;
const PROTOCOL_VERSION_MASK: u32 = 0x0000ffff;
const INVALID_INDEX: u32 = 0xffffffff;
const COOKIE_LENGTH = 256;
const MAX_CHANNELS = 32;

/// Seconds to wait for the server before giving up.
const TIMEOUT_SECONDS = 10;

/// Largest number of sample bytes sent in one frame.
const MAX_DATA_FRAME = 64 * 1024;

/// Size of the buffer that receives one command from the server.
const MAX_COMMAND = 4096;

// pulsecore/native-common.h: commands
const COMMAND_ERROR: u32 = 0;
const COMMAND_REPLY: u32 = 2;
const COMMAND_CREATE_PLAYBACK_STREAM: u32 = 3;
const COMMAND_DELETE_PLAYBACK_STREAM: u32 = 4;
const COMMAND_AUTH: u32 = 8;
const COMMAND_SET_CLIENT_NAME: u32 = 9;
const COMMAND_DRAIN_PLAYBACK_STREAM: u32 = 12;
const COMMAND_REQUEST: u32 = 61;
const COMMAND_PLAYBACK_STREAM_KILLED: u32 = 64;

// pulsecore/tagstruct.h: tags
const TAG_STRING = 't';
const TAG_STRING_NULL = 'N';
const TAG_U32 = 'L';
const TAG_SAMPLE_SPEC = 'a';
const TAG_ARBITRARY = 'x';
const TAG_BOOLEAN_TRUE = '1';
const TAG_BOOLEAN_FALSE = '0';
const TAG_CHANNEL_MAP = 'm';
const TAG_CVOLUME = 'v';
const TAG_PROPLIST = 'P';

// pulse/sample.h: sample formats in the native byte order
const SAMPLE_FLOAT32: u8 = if (builtin.cpu.arch.endian() == .little) 5 else 6;

// pulse/channelmap.h: channel positions
const POSITION_MONO: u8 = 0;
const POSITION_FRONT_LEFT: u8 = 1;
const POSITION_FRONT_RIGHT: u8 = 2;
const POSITION_AUX0: u8 = 12;

/// pulse/volume.h: `PA_VOLUME_NORM`.
const VOLUME_NORM: u32 = 0x10000;

/// Length of the frame descriptor: length, channel, offset (high, low) and flags.
const DESCRIPTOR_LENGTH = 20;

/// The channel value of a frame that carries a command instead of stream data.
const COMMAND_CHANNEL: u32 = 0xffffffff;

/// A command being built. Every command this backend sends is far below the capacity.
const Command = struct {
    buf: [1024]u8 = undefined,
    len: usize = 0,

    fn put(self: *Command, bytes: []const u8) void {
        std.debug.assert(self.len + bytes.len <= self.buf.len);
        @memcpy(self.buf[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
    }

    fn putTag(self: *Command, tag: u8) void {
        self.put(&.{tag});
    }

    fn putU32(self: *Command, value: u32) void {
        self.putTag(TAG_U32);
        self.put(&std.mem.toBytes(std.mem.nativeToBig(u32, value)));
    }

    fn putBool(self: *Command, value: bool) void {
        self.putTag(if (value) TAG_BOOLEAN_TRUE else TAG_BOOLEAN_FALSE);
    }

    fn putString(self: *Command, value: ?[]const u8) void {
        const string = value orelse return self.putTag(TAG_STRING_NULL);
        self.putTag(TAG_STRING);
        self.put(string);
        self.putTag(0);
    }

    fn putArbitrary(self: *Command, bytes: []const u8) void {
        self.putTag(TAG_ARBITRARY);
        self.put(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(bytes.len))));
        self.put(bytes);
    }

    fn putSampleSpec(self: *Command, channels: u8, rate: u32) void {
        self.putTag(TAG_SAMPLE_SPEC);
        self.putTag(SAMPLE_FLOAT32);
        self.putTag(channels);
        self.put(&std.mem.toBytes(std.mem.nativeToBig(u32, rate)));
    }

    fn putChannelMap(self: *Command, channels: u8) void {
        self.putTag(TAG_CHANNEL_MAP);
        self.putTag(channels);
        for (0..channels) |i| self.putTag(channelPosition(channels, i));
    }

    fn putCvolume(self: *Command, channels: u8) void {
        self.putTag(TAG_CVOLUME);
        self.putTag(channels);
        for (0..channels) |_| self.put(&std.mem.toBytes(std.mem.nativeToBig(u32, VOLUME_NORM)));
    }

    /// A property list holding the single string property `key`.
    fn putProplist(self: *Command, key: []const u8, value: []const u8) void {
        self.putTag(TAG_PROPLIST);
        self.putString(key);
        // The value includes its terminating zero.
        self.putU32(@intCast(value.len + 1));
        self.putTag(TAG_ARBITRARY);
        self.put(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(value.len + 1))));
        self.put(value);
        self.putTag(0);
        self.putString(null);
    }
};

/// Returns the channel position of channel `index` of `channels`: mono, front left and right for
/// one and two channels, and auxiliary positions otherwise.
fn channelPosition(channels: u8, index: usize) u8 {
    return switch (channels) {
        1 => POSITION_MONO,
        2 => if (index == 0) POSITION_FRONT_LEFT else POSITION_FRONT_RIGHT,
        else => POSITION_AUX0 + @as(u8, @intCast(index)),
    };
}

/// A command received from the server.
const Received = struct {
    command: u32,
    tag: u32,
    /// The fields after the command and the tag.
    body: []const u8,

    fn reader(self: Received) FieldReader {
        return .{ .data = self.body };
    }
};

/// Reads the tagged fields of a command.
const FieldReader = struct {
    data: []const u8,
    pos: usize = 0,

    fn take(self: *FieldReader, count: usize) Error![]const u8 {
        if (self.data.len - self.pos < count) return error.ProtocolError;
        defer self.pos += count;
        return self.data[self.pos..][0..count];
    }

    fn expectTag(self: *FieldReader, tag: u8) Error!void {
        const got = try self.take(1);
        if (got[0] != tag) return error.ProtocolError;
    }

    fn readU32(self: *FieldReader) Error!u32 {
        try self.expectTag(TAG_U32);
        return std.mem.readInt(u32, (try self.take(4))[0..4], .big);
    }
};

/// Parses a command payload into its command number, tag and remaining fields.
fn parseCommand(payload: []const u8) Error!Received {
    var reader: FieldReader = .{ .data = payload };
    const command = try reader.readU32();
    const tag = try reader.readU32();
    return .{ .command = command, .tag = tag, .body = payload[reader.pos..] };
}

/// A connection to a server, over any stream socket.
const Connection = struct {
    fd: linux.fd_t,
    next_tag: u32 = 0,
    recv_buf: [MAX_COMMAND]u8 = undefined,

    /// Sends all of `bytes`.
    fn sendAll(self: *Connection, bytes: []const u8) Error!void {
        var sent: usize = 0;
        while (sent < bytes.len) {
            // MSG_NOSIGNAL: a closed connection is an error, not SIGPIPE.
            const rc = linux.sendto(self.fd, bytes[sent..].ptr, bytes.len - sent, linux.MSG.NOSIGNAL, null, 0);
            switch (linux.errno(rc)) {
                .SUCCESS => sent += rc,
                .INTR => {},
                .AGAIN => return error.TimedOut,
                else => return error.ConnectionClosed,
            }
        }
    }

    /// Fills `buf` from the socket.
    fn readExact(self: *Connection, buf: []u8) Error!void {
        var filled: usize = 0;
        while (filled < buf.len) {
            const rc = linux.recvfrom(self.fd, buf[filled..].ptr, buf.len - filled, 0, null, null);
            switch (linux.errno(rc)) {
                .SUCCESS => {
                    if (rc == 0) return error.ConnectionClosed;
                    filled += rc;
                },
                .INTR => {},
                .AGAIN => return error.TimedOut,
                else => return error.ConnectionClosed,
            }
        }
    }

    /// Sends the descriptor of a frame.
    fn sendDescriptor(self: *Connection, length: usize, channel: u32) Error!void {
        var descriptor: [DESCRIPTOR_LENGTH]u8 = @splat(0);
        std.mem.writeInt(u32, descriptor[0..4], @intCast(length), .big);
        std.mem.writeInt(u32, descriptor[4..8], channel, .big);
        // The offset and the flags stay zero: the data is appended to the stream.
        try self.sendAll(&descriptor);
    }

    /// Sends a command frame.
    fn sendCommand(self: *Connection, command: *const Command) Error!void {
        try self.sendDescriptor(command.len, COMMAND_CHANNEL);
        try self.sendAll(command.buf[0..command.len]);
    }

    /// Starts a command with the number `number` and a new tag, and returns the tag.
    fn begin(self: *Connection, command: *Command, number: u32) u32 {
        const tag = self.next_tag;
        self.next_tag += 1;
        command.putU32(number);
        command.putU32(tag);
        return tag;
    }

    /// Receives the next command of the server. Stream data is skipped: a playback stream never
    /// receives any.
    fn receive(self: *Connection) Error!Received {
        while (true) {
            var descriptor: [DESCRIPTOR_LENGTH]u8 = undefined;
            try self.readExact(&descriptor);
            const length = std.mem.readInt(u32, descriptor[0..4], .big);
            const channel = std.mem.readInt(u32, descriptor[4..8], .big);

            if (length > self.recv_buf.len) {
                try self.skip(length);
                continue;
            }
            try self.readExact(self.recv_buf[0..length]);
            if (channel != COMMAND_CHANNEL) continue;
            return parseCommand(self.recv_buf[0..length]);
        }
    }

    fn skip(self: *Connection, count: usize) Error!void {
        var left = count;
        var scratch: [256]u8 = undefined;
        while (left > 0) {
            const step = @min(left, scratch.len);
            try self.readExact(scratch[0..step]);
            left -= step;
        }
    }

    /// Waits for the reply to `tag`. A reply to another command is dropped, and commands the
    /// server sends by itself are passed to `onNotice`.
    fn awaitReply(self: *Connection, tag: u32, onNotice: ?*Stream) Error!Received {
        while (true) {
            const received = try self.receive();
            switch (received.command) {
                COMMAND_REPLY => if (received.tag == tag) return received,
                COMMAND_ERROR => if (received.tag == tag) return error.ServerError,
                else => if (onNotice) |stream| try stream.notice(received),
            }
        }
    }

    /// Authenticates and names the client. Returns the negotiated protocol version.
    fn handshake(self: *Connection, cookie: *const [COOKIE_LENGTH]u8) Error!u32 {
        var auth: Command = .{};
        const auth_tag = self.begin(&auth, COMMAND_AUTH);
        auth.putU32(PROTOCOL_VERSION);
        auth.putArbitrary(cookie);
        try self.sendCommand(&auth);

        var reply = (try self.awaitReply(auth_tag, null)).reader();
        const version = (try reply.readU32()) & PROTOCOL_VERSION_MASK;
        if (version < 13) return error.ProtocolError;

        var client: Command = .{};
        const client_tag = self.begin(&client, COMMAND_SET_CLIENT_NAME);
        client.putProplist("application.name", "lightmix");
        try self.sendCommand(&client);
        _ = try self.awaitReply(client_tag, null);

        return @min(version, PROTOCOL_VERSION);
    }
};

/// A playback stream on the server.
const Stream = struct {
    /// The channel that stream data is sent to.
    channel: u32,
    /// Bytes the server has asked for and that were not sent yet.
    requested: u64,

    /// Handles a command the server sends by itself.
    fn notice(self: *Stream, received: Received) Error!void {
        switch (received.command) {
            COMMAND_REQUEST => {
                var reader = received.reader();
                const channel = try reader.readU32();
                const bytes = try reader.readU32();
                if (channel == self.channel) self.requested += bytes;
            },
            COMMAND_PLAYBACK_STREAM_KILLED => return error.StreamKilled,
            else => {},
        }
    }
};

/// Creates a playback stream for `buffer` on the default sink, using the default buffer sizes.
fn createStream(connection: *Connection, buffer: Buffer) Error!Stream {
    const channels: u8 = @intCast(buffer.channels);

    var command: Command = .{};
    const tag = connection.begin(&command, COMMAND_CREATE_PLAYBACK_STREAM);
    command.putSampleSpec(channels, buffer.sample_rate);
    command.putChannelMap(channels);
    command.putU32(INVALID_INDEX); // sink index
    command.putString(null); // the default sink
    command.putU32(INVALID_INDEX); // maxlength
    command.putBool(false); // corked
    command.putU32(INVALID_INDEX); // tlength
    command.putU32(INVALID_INDEX); // prebuf
    command.putU32(INVALID_INDEX); // minreq
    command.putU32(0); // sync id
    command.putCvolume(channels);
    // Version 12: no remap, no remix, fix format, fix rate, fix channels, no move, variable rate.
    // The stream must keep the rate and the channels of the buffer, so no `fix` flag is set: a
    // server that cannot honor them fails the creation instead of changing them.
    for (0..7) |_| command.putBool(false);
    // Version 13: muted, adjust latency and the property list.
    command.putBool(false);
    command.putBool(false);
    command.putProplist("media.name", "lightmix");
    // Version 14: volume set and early requests.
    command.putBool(false);
    command.putBool(false);
    // Version 15: muted set, do not inhibit auto suspend and fail on suspend.
    command.putBool(false);
    command.putBool(false);
    command.putBool(false);
    try connection.sendCommand(&command);

    var reply = (try connection.awaitReply(tag, null)).reader();
    const channel = try reply.readU32();
    const index = try reply.readU32();
    const requested = try reply.readU32();
    if (channel == INVALID_INDEX or index == INVALID_INDEX) return error.ProtocolError;
    return .{ .channel = channel, .requested = requested };
}

/// Sends `bytes` as stream data of `channel`.
fn sendStreamData(connection: *Connection, channel: u32, bytes: []const u8) Error!void {
    try connection.sendDescriptor(bytes.len, channel);
    try connection.sendAll(bytes);
}

/// Plays `buffer` on the connection and blocks until the server has played it.
fn playOn(connection: *Connection, cookie: *const [COOKIE_LENGTH]u8, buffer: Buffer) Error!void {
    _ = connection.handshake(cookie) catch return error.ServerUnavailable;
    var stream = createStream(connection, buffer) catch return error.ServerUnavailable;

    const bytes = std.mem.sliceAsBytes(buffer.samples);
    const frame_bytes = @as(usize, buffer.channels) * @sizeOf(f32);
    var sent: usize = 0;
    while (sent < bytes.len) {
        const wanted = @min(@min(stream.requested, bytes.len - sent), MAX_DATA_FRAME);
        const count = @as(usize, @intCast(wanted)) / frame_bytes * frame_bytes;
        if (count == 0) {
            // The server asks for more when it has played some.
            try stream.notice(try connection.receive());
            continue;
        }
        try sendStreamData(connection, stream.channel, bytes[sent..][0..count]);
        sent += count;
        stream.requested -= count;
    }

    var drain: Command = .{};
    const drain_tag = connection.begin(&drain, COMMAND_DRAIN_PLAYBACK_STREAM);
    drain.putU32(stream.channel);
    try connection.sendCommand(&drain);
    _ = try connection.awaitReply(drain_tag, &stream);

    var delete: Command = .{};
    _ = connection.begin(&delete, COMMAND_DELETE_PLAYBACK_STREAM);
    delete.putU32(stream.channel);
    connection.sendCommand(&delete) catch {};
}

/// Plays `buffer` through the PulseAudio server and blocks until playback completes.
///
/// ## Errors
/// Returns `Error`; `error.ServerUnavailable` means that nothing was played.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    _ = io;
    if (buffer.samples.len == 0) return;
    if (buffer.channels == 0 or buffer.channels > MAX_CHANNELS) return error.UnsupportedChannels;

    var environment = Environment.load(allocator);
    defer environment.deinit(allocator);

    var connection = try connect(environment);
    defer _ = linux.close(connection.fd);
    const cookie = loadCookie(environment);
    try playOn(&connection, &cookie, buffer);
}

/// Returns whether a server accepts this client, without playing anything.
pub fn probe(allocator: std.mem.Allocator) bool {
    var environment = Environment.load(allocator);
    defer environment.deinit(allocator);

    var connection = connect(environment) catch return false;
    defer _ = linux.close(connection.fd);
    const cookie = loadCookie(environment);
    _ = connection.handshake(&cookie) catch return false;
    return true;
}

/// Connects to the server and sets the time the server may take to answer.
fn connect(environment: Environment) Error!Connection {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = serverPath(environment, &path_buf) orelse return error.ServerUnavailable;

    var address: linux.sockaddr.un = .{ .path = @splat(0) };
    if (path.len >= address.path.len) return error.ServerUnavailable;
    @memcpy(address.path[0..path.len], path);

    const socket_rc = linux.socket(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
    if (linux.errno(socket_rc) != .SUCCESS) return error.ServerUnavailable;
    const fd: linux.fd_t = @intCast(socket_rc);
    errdefer _ = linux.close(fd);

    if (linux.errno(linux.connect(fd, @ptrCast(&address), @sizeOf(linux.sockaddr.un))) != .SUCCESS) {
        return error.ServerUnavailable;
    }

    setTimeouts(fd);
    return .{ .fd = fd };
}

/// Limits the time a read or a write on `fd` may block.
fn setTimeouts(fd: linux.fd_t) void {
    const timeout: linux.timeval = .{ .sec = TIMEOUT_SECONDS, .usec = 0 };
    for ([_]u32{ linux.SO.RCVTIMEO, linux.SO.SNDTIMEO }) |option| {
        _ = linux.setsockopt(fd, linux.SOL.SOCKET, option, std.mem.asBytes(&timeout), @sizeOf(linux.timeval));
    }
}

/// The environment variables this process started with.
///
/// The variables are read from `/proc/self/environ`, because no libc is linked. Variables set
/// after the process started are not seen.
pub const Environment = struct {
    /// `KEY=value` entries separated by zero bytes; empty when the file cannot be read.
    bytes: []u8,

    pub fn load(allocator: std.mem.Allocator) Environment {
        return .{ .bytes = readFile(allocator, "/proc/self/environ") orelse &.{} };
    }

    pub fn deinit(self: *Environment, allocator: std.mem.Allocator) void {
        if (self.bytes.len > 0) allocator.free(self.bytes);
    }

    /// Returns the value of `key`, valid until `deinit`.
    pub fn get(self: Environment, key: []const u8) ?[]const u8 {
        var entries = std.mem.splitScalar(u8, self.bytes, 0);
        while (entries.next()) |entry| {
            if (entry.len > key.len and entry[key.len] == '=' and std.mem.eql(u8, entry[0..key.len], key)) {
                return entry[key.len + 1 ..];
            }
        }
        return null;
    }
};

/// Reads the whole file at `path`, or returns null if it cannot be read or is empty.
fn readFile(allocator: std.mem.Allocator, path: [:0]const u8) ?[]u8 {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    if (linux.errno(rc) != .SUCCESS) return null;
    const fd: linux.fd_t = @intCast(rc);
    defer _ = linux.close(fd);

    var content: std.ArrayList(u8) = .empty;
    errdefer content.deinit(allocator);
    var chunk: [4096]u8 = undefined;
    while (true) {
        const count = linux.read(fd, &chunk, chunk.len);
        switch (linux.errno(count)) {
            .SUCCESS => {},
            .INTR => continue,
            else => {
                content.deinit(allocator);
                return null;
            },
        }
        if (count == 0) break;
        content.appendSlice(allocator, chunk[0..count]) catch {
            content.deinit(allocator);
            return null;
        };
    }
    if (content.items.len == 0) {
        content.deinit(allocator);
        return null;
    }
    return content.toOwnedSlice(allocator) catch null;
}

/// Returns the path of the server socket, written to `buf`, or null when there is none to try.
fn serverPath(environment: Environment, buf: []u8) ?[]const u8 {
    if (environment.get("PULSE_SERVER")) |value| {
        if (parseServer(value)) |path| {
            if (path.len > buf.len) return null;
            @memcpy(buf[0..path.len], path);
            return buf[0..path.len];
        }
    }

    if (environment.get("XDG_RUNTIME_DIR")) |dir| {
        return std.fmt.bufPrint(buf, "{s}/pulse/native", .{dir}) catch null;
    }
    return std.fmt.bufPrint(buf, "/run/user/{d}/pulse/native", .{linux.getuid()}) catch null;
}

/// Returns the first UNIX socket path of a `PULSE_SERVER` value, which is a list separated by
/// spaces. Entries may start with a `{machine id}` and `unix:`; TCP entries are skipped.
fn parseServer(value: []const u8) ?[]const u8 {
    var entries = std.mem.tokenizeScalar(u8, value, ' ');
    while (entries.next()) |entry| {
        var rest = entry;
        if (rest.len > 0 and rest[0] == '{') {
            const close = std.mem.indexOfScalar(u8, rest, '}') orelse continue;
            rest = rest[close + 1 ..];
        }
        if (std.mem.startsWith(u8, rest, "unix:")) rest = rest["unix:".len..];
        if (rest.len > 0 and rest[0] == '/') return rest;
    }
    return null;
}

/// Loads the authentication cookie from `$PULSE_COOKIE`, `$XDG_CONFIG_HOME/pulse/cookie`,
/// `~/.config/pulse/cookie` or `~/.pulse-cookie`, in this order. Without a usable file the cookie
/// is all zeros, which a server accepts from a local socket.
fn loadCookie(environment: Environment) [COOKIE_LENGTH]u8 {
    var cookie: [COOKIE_LENGTH]u8 = @splat(0);
    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;

    if (environment.get("PULSE_COOKIE")) |path| {
        if (std.fmt.bufPrintZ(&path_buf, "{s}", .{path})) |z| {
            if (readCookie(z, &cookie)) return cookie;
        } else |_| {}
    }
    const candidates = [_]struct { variable: []const u8, format: []const u8 }{
        .{ .variable = "XDG_CONFIG_HOME", .format = "{s}/pulse/cookie" },
        .{ .variable = "HOME", .format = "{s}/.config/pulse/cookie" },
        .{ .variable = "HOME", .format = "{s}/.pulse-cookie" },
    };
    inline for (candidates) |candidate| {
        if (environment.get(candidate.variable)) |dir| {
            if (std.fmt.bufPrintZ(&path_buf, candidate.format, .{dir})) |z| {
                if (readCookie(z, &cookie)) return cookie;
            } else |_| {}
        }
    }
    return @splat(0);
}

/// Reads a cookie file into `cookie`. Returns false when it is missing or shorter than a cookie.
fn readCookie(path: [:0]const u8, cookie: *[COOKIE_LENGTH]u8) bool {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    if (linux.errno(rc) != .SUCCESS) return false;
    const fd: linux.fd_t = @intCast(rc);
    defer _ = linux.close(fd);

    const count = linux.read(fd, cookie, cookie.len);
    return linux.errno(count) == .SUCCESS and count == cookie.len;
}

test "commands are encoded as tagged big-endian fields" {
    var command: Command = .{};
    command.putU32(0x01020304);
    try std.testing.expectEqualSlices(u8, &.{ 'L', 1, 2, 3, 4 }, command.buf[0..command.len]);

    command = .{};
    command.putString("ab");
    command.putString(null);
    command.putBool(true);
    command.putBool(false);
    try std.testing.expectEqualSlices(u8, &.{ 't', 'a', 'b', 0, 'N', '1', '0' }, command.buf[0..command.len]);

    command = .{};
    command.putSampleSpec(2, 44100);
    try std.testing.expectEqualSlices(u8, &.{ 'a', SAMPLE_FLOAT32, 2, 0, 0, 0xac, 0x44 }, command.buf[0..command.len]);

    command = .{};
    command.putProplist("k", "v");
    try std.testing.expectEqualSlices(u8, &.{ 'P', 't', 'k', 0, 'L', 0, 0, 0, 2, 'x', 0, 0, 0, 2, 'v', 0, 'N' }, command.buf[0..command.len]);
}

test "channel maps use standard positions for mono and stereo" {
    try std.testing.expectEqual(POSITION_MONO, channelPosition(1, 0));
    try std.testing.expectEqual(POSITION_FRONT_LEFT, channelPosition(2, 0));
    try std.testing.expectEqual(POSITION_FRONT_RIGHT, channelPosition(2, 1));
    try std.testing.expectEqual(POSITION_AUX0 + 5, channelPosition(6, 5));
}

test "parseCommand splits the command, the tag and the fields" {
    const payload = [_]u8{ 'L', 0, 0, 0, 2, 'L', 0, 0, 0, 7, 'L', 0, 0, 0, 9 };
    const received = try parseCommand(&payload);
    try std.testing.expectEqual(COMMAND_REPLY, received.command);
    try std.testing.expectEqual(@as(u32, 7), received.tag);
    var reader = received.reader();
    try std.testing.expectEqual(@as(u32, 9), try reader.readU32());
    try std.testing.expectError(error.ProtocolError, reader.readU32());
    try std.testing.expectError(error.ProtocolError, parseCommand(&.{ 'x', 0 }));
}

test "parseServer picks the first UNIX socket of a PULSE_SERVER list" {
    try std.testing.expectEqualStrings("/run/pulse/native", parseServer("/run/pulse/native").?);
    try std.testing.expectEqualStrings("/run/pulse/native", parseServer("unix:/run/pulse/native").?);
    try std.testing.expectEqualStrings("/a/native", parseServer("{abc}unix:/a/native").?);
    try std.testing.expectEqualStrings("/b/native", parseServer("tcp:host:4713 unix:/b/native").?);
    try std.testing.expectEqual(@as(?[]const u8, null), parseServer("tcp:host:4713"));
    try std.testing.expectEqual(@as(?[]const u8, null), parseServer(""));
}

test "Environment finds a variable by its full name" {
    const bytes = try std.testing.allocator.dupe(u8, "HOME=/home/a\x00XDG_RUNTIME_DIR=/run/user/1\x00EMPTY=\x00");
    var environment: Environment = .{ .bytes = bytes };
    defer environment.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("/home/a", environment.get("HOME").?);
    try std.testing.expectEqualStrings("/run/user/1", environment.get("XDG_RUNTIME_DIR").?);
    try std.testing.expectEqualStrings("", environment.get("EMPTY").?);
    try std.testing.expectEqual(@as(?[]const u8, null), environment.get("HOM"));
    try std.testing.expectEqual(@as(?[]const u8, null), environment.get("PATH"));
}

/// A server that runs in a thread on the other end of a socket pair and records what it gets.
const FakeServer = struct {
    connection: Connection,
    /// Answer the stream creation with an error.
    refuse_stream: bool = false,
    /// Bytes requested from the client at first, and after each frame of stream data.
    first_request: u32 = 64,
    /// The sample spec field of the stream creation command.
    sample_spec: [7]u8 = @splat(0),
    data: [4096]u8 = undefined,
    data_len: usize = 0,
    drained: bool = false,

    const stream_channel: u32 = 7;

    fn run(self: *FakeServer) void {
        self.serve() catch {};
        _ = linux.close(self.connection.fd);
    }

    fn reply(self: *FakeServer, tag: u32, value: u32) !void {
        var command: Command = .{};
        command.putU32(COMMAND_REPLY);
        command.putU32(tag);
        command.putU32(value);
        try self.connection.sendCommand(&command);
    }

    fn request(self: *FakeServer, bytes: u32) !void {
        var command: Command = .{};
        command.putU32(COMMAND_REQUEST);
        command.putU32(INVALID_INDEX);
        command.putU32(stream_channel);
        command.putU32(bytes);
        try self.connection.sendCommand(&command);
    }

    fn serve(self: *FakeServer) !void {
        const auth = try self.connection.receive();
        try std.testing.expectEqual(COMMAND_AUTH, auth.command);
        var auth_fields = auth.reader();
        try std.testing.expectEqual(PROTOCOL_VERSION, try auth_fields.readU32());
        try self.reply(auth.tag, 35);

        const name_command = try self.connection.receive();
        try std.testing.expectEqual(COMMAND_SET_CLIENT_NAME, name_command.command);
        try self.reply(name_command.tag, 1);

        const create = try self.connection.receive();
        try std.testing.expectEqual(COMMAND_CREATE_PLAYBACK_STREAM, create.command);
        @memcpy(&self.sample_spec, create.body[0..7]);
        if (self.refuse_stream) {
            var command: Command = .{};
            command.putU32(COMMAND_ERROR);
            command.putU32(create.tag);
            command.putU32(2);
            return self.connection.sendCommand(&command);
        }
        var created: Command = .{};
        created.putU32(COMMAND_REPLY);
        created.putU32(create.tag);
        created.putU32(stream_channel);
        created.putU32(3); // stream index
        created.putU32(self.first_request);
        try self.connection.sendCommand(&created);

        while (true) {
            var descriptor: [DESCRIPTOR_LENGTH]u8 = undefined;
            try self.connection.readExact(&descriptor);
            const length = std.mem.readInt(u32, descriptor[0..4], .big);
            const channel = std.mem.readInt(u32, descriptor[4..8], .big);
            if (channel != COMMAND_CHANNEL) {
                try std.testing.expectEqual(stream_channel, channel);
                try self.connection.readExact(self.data[self.data_len..][0..length]);
                self.data_len += length;
                // The frames are consumed at once, so the client is asked for the same amount.
                try self.request(length);
                continue;
            }
            var payload: [256]u8 = undefined;
            try self.connection.readExact(payload[0..length]);
            const received = try parseCommand(payload[0..length]);
            switch (received.command) {
                COMMAND_DRAIN_PLAYBACK_STREAM => {
                    self.drained = true;
                    try self.reply(received.tag, 0);
                },
                COMMAND_DELETE_PLAYBACK_STREAM => return,
                else => return error.UnexpectedCommand,
            }
        }
    }
};

/// Returns both ends of a connected socket pair, with time limits so a bug cannot hang a test.
fn socketPair() ![2]linux.fd_t {
    var fds: [2]i32 = undefined;
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM, 0, &fds)));
    setTimeouts(fds[0]);
    setTimeouts(fds[1]);
    return fds;
}

test "playOn sends every sample to a server that requests them in pieces" {
    const fds = try socketPair();
    var server: FakeServer = .{ .connection = .{ .fd = fds[1] } };
    const thread = try std.Thread.spawn(.{}, FakeServer.run, .{&server});

    var samples: [200]f32 = undefined;
    for (&samples, 0..) |*sample, i| sample.* = @as(f32, @floatFromInt(i)) / 200.0;
    var connection: Connection = .{ .fd = fds[0] };
    const cookie: [COOKIE_LENGTH]u8 = @splat(0);
    try playOn(&connection, &cookie, .{ .samples = &samples, .sample_rate = 48000, .channels = 2 });
    _ = linux.close(fds[0]);
    thread.join();

    try std.testing.expect(server.drained);
    try std.testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&samples), server.data[0..server.data_len]);
    try std.testing.expectEqualSlices(u8, &.{ 'a', SAMPLE_FLOAT32, 2, 0, 0, 0xbb, 0x80 }, &server.sample_spec);
}

test "playOn keeps every data frame a whole number of sample frames" {
    const fds = try socketPair();
    // The server asks for 10 bytes, which is not a multiple of the 8 bytes of a stereo frame.
    var server: FakeServer = .{ .connection = .{ .fd = fds[1] }, .first_request = 10 };
    const thread = try std.Thread.spawn(.{}, FakeServer.run, .{&server});

    const samples = [_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 };
    var connection: Connection = .{ .fd = fds[0] };
    const cookie: [COOKIE_LENGTH]u8 = @splat(0);
    try playOn(&connection, &cookie, .{ .samples = &samples, .sample_rate = 44100, .channels = 2 });
    _ = linux.close(fds[0]);
    thread.join();

    try std.testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&samples), server.data[0..server.data_len]);
}

test "playOn reports a refused stream as ServerUnavailable before sending samples" {
    const fds = try socketPair();
    var server: FakeServer = .{ .connection = .{ .fd = fds[1] }, .refuse_stream = true };
    const thread = try std.Thread.spawn(.{}, FakeServer.run, .{&server});

    const samples = [_]f32{ 0.1, 0.2 };
    var connection: Connection = .{ .fd = fds[0] };
    const cookie: [COOKIE_LENGTH]u8 = @splat(0);
    try std.testing.expectError(error.ServerUnavailable, playOn(&connection, &cookie, .{ .samples = &samples, .sample_rate = 44100, .channels = 1 }));
    _ = linux.close(fds[0]);
    thread.join();
    try std.testing.expectEqual(@as(usize, 0), server.data_len);
}

test "playOn reports a server that hangs up as ServerUnavailable" {
    const fds = try socketPair();
    _ = linux.close(fds[1]);

    const samples = [_]f32{0.1};
    var connection: Connection = .{ .fd = fds[0] };
    defer _ = linux.close(fds[0]);
    const cookie: [COOKIE_LENGTH]u8 = @splat(0);
    try std.testing.expectError(error.ServerUnavailable, playOn(&connection, &cookie, .{ .samples = &samples, .sample_rate = 44100, .channels = 1 }));
}

test "play rejects a channel count PulseAudio does not support" {
    const samples = [_]f32{0.0};
    try std.testing.expectError(error.UnsupportedChannels, play(std.testing.allocator, std.testing.io, .{ .samples = &samples, .sample_rate = 44100, .channels = 33 }));
}
