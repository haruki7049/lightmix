//! # CoreAudio Playback Backend (macOS)
//!
//! Plays a `Buffer` through an AudioToolbox `AudioQueue`, in Pure Zig.
//!
//! AudioToolbox is not linked at build time. It is opened at runtime with `dlopen`, and its
//! functions are looked up with `dlsym`, so building this backend needs no macOS SDK. Only
//! libc (libSystem, bundled with Zig) is linked.
//!
//! The queue cycles `BUFFER_COUNT` buffers: the output callback refills each buffer that has
//! been played. When every sample has been enqueued, the queue is stopped asynchronously, so it
//! stops after the queued buffers are played. A listener on `kAudioQueueProperty_IsRunning`
//! reports the stop to `play`, which waits for it.

const std = @import("std");
const Buffer = @import("../backend.zig").Buffer;

pub const name = "coreaudio";

/// Errors returned by `play`.
pub const Error = error{
    /// AudioToolbox could not be opened with `dlopen`.
    AudioToolboxNotFound,
    /// A required AudioToolbox function was not found with `dlsym`.
    MissingSymbol,
    /// An AudioQueue function returned a non-zero `OSStatus`.
    AudioQueueFailed,
    /// The queue did not stop within the duration of the buffer plus `TIMEOUT_MARGIN_MS`.
    PlaybackTimeout,
};

/// Path of the AudioToolbox framework binary opened with `dlopen`.
const AUDIO_TOOLBOX_PATH = "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox";

/// Number of buffers the queue cycles through.
const BUFFER_COUNT = 3;

/// Number of frames held by each buffer.
const FRAMES_PER_BUFFER = 4096;

/// Interval between checks for the end of playback.
const POLL_INTERVAL_MS = 10;

/// Time allowed beyond the duration of the buffer before `play` gives up.
const TIMEOUT_MARGIN_MS = 2000;

// AudioToolbox constants (four-character codes)
const K_AUDIO_FORMAT_LINEAR_PCM: u32 = fourCharCode("lpcm");
const K_AUDIO_FORMAT_FLAG_IS_FLOAT: u32 = 1 << 0;
const K_AUDIO_FORMAT_FLAG_IS_PACKED: u32 = 1 << 3;
const K_AUDIO_QUEUE_PROPERTY_IS_RUNNING: u32 = fourCharCode("aqrn");

// AudioToolbox types
const OSStatus = i32;
const AudioQueueRef = *opaque {};

const AudioStreamBasicDescription = extern struct {
    mSampleRate: f64,
    mFormatID: u32,
    mFormatFlags: u32,
    mBytesPerPacket: u32,
    mFramesPerPacket: u32,
    mBytesPerFrame: u32,
    mChannelsPerFrame: u32,
    mBitsPerChannel: u32,
    mReserved: u32,
};

const AudioQueueBuffer = extern struct {
    mAudioDataBytesCapacity: u32,
    mAudioData: *anyopaque,
    mAudioDataByteSize: u32,
    mUserData: ?*anyopaque,
    mPacketDescriptionCapacity: u32,
    mPacketDescriptions: ?*anyopaque,
    mPacketDescriptionCount: u32,
};
const AudioQueueBufferRef = *AudioQueueBuffer;

const OutputCallback = *const fn (?*anyopaque, AudioQueueRef, AudioQueueBufferRef) callconv(.c) void;
const PropertyListener = *const fn (?*anyopaque, AudioQueueRef, u32) callconv(.c) void;

/// AudioToolbox functions looked up at runtime.
const Api = struct {
    newOutput: *const fn (*const AudioStreamBasicDescription, OutputCallback, ?*anyopaque, ?*anyopaque, ?*anyopaque, u32, *?AudioQueueRef) callconv(.c) OSStatus,
    allocateBuffer: *const fn (AudioQueueRef, u32, *?AudioQueueBufferRef) callconv(.c) OSStatus,
    enqueueBuffer: *const fn (AudioQueueRef, AudioQueueBufferRef, u32, ?*const anyopaque) callconv(.c) OSStatus,
    start: *const fn (AudioQueueRef, ?*const anyopaque) callconv(.c) OSStatus,
    stop: *const fn (AudioQueueRef, u8) callconv(.c) OSStatus,
    dispose: *const fn (AudioQueueRef, u8) callconv(.c) OSStatus,
    addPropertyListener: *const fn (AudioQueueRef, u32, PropertyListener, ?*anyopaque) callconv(.c) OSStatus,
    getProperty: *const fn (AudioQueueRef, u32, *anyopaque, *u32) callconv(.c) OSStatus,

    /// Looks up every AudioToolbox function from `lib`.
    fn load(lib: *std.DynLib) Error!Api {
        return .{
            .newOutput = try lookup(lib, "newOutput", "AudioQueueNewOutput"),
            .allocateBuffer = try lookup(lib, "allocateBuffer", "AudioQueueAllocateBuffer"),
            .enqueueBuffer = try lookup(lib, "enqueueBuffer", "AudioQueueEnqueueBuffer"),
            .start = try lookup(lib, "start", "AudioQueueStart"),
            .stop = try lookup(lib, "stop", "AudioQueueStop"),
            .dispose = try lookup(lib, "dispose", "AudioQueueDispose"),
            .addPropertyListener = try lookup(lib, "addPropertyListener", "AudioQueueAddPropertyListener"),
            .getProperty = try lookup(lib, "getProperty", "AudioQueueGetProperty"),
        };
    }

    fn lookup(lib: *std.DynLib, comptime field: []const u8, symbol: [:0]const u8) Error!@FieldType(Api, field) {
        return lib.lookup(@FieldType(Api, field), symbol) orelse error.MissingSymbol;
    }
};

/// Playback state shared between `play` and the AudioQueue callbacks.
///
/// `position` is written by `play` while priming the buffers, before the queue starts, and
/// afterwards only by the output callback, which AudioQueue never runs concurrently.
const State = struct {
    api: *const Api,
    buffer: Buffer,
    position: usize = 0,
    stop_requested: std.atomic.Value(bool) = .init(false),
    stopped: std.atomic.Value(bool) = .init(false),
    failed: std.atomic.Value(bool) = .init(false),

    /// Copies the next samples into `queue_buffer` and enqueues it.
    /// Returns false, without enqueueing, when every sample has already been enqueued.
    fn fill(self: *State, queue: AudioQueueRef, queue_buffer: AudioQueueBufferRef) bool {
        const remaining = self.buffer.samples.len - self.position;
        if (remaining == 0) return false;

        const capacity = queue_buffer.mAudioDataBytesCapacity / @sizeOf(f32);
        const count = @min(remaining, capacity - capacity % self.buffer.channels);
        const dest: [*]f32 = @ptrCast(@alignCast(queue_buffer.mAudioData));
        @memcpy(dest[0..count], self.buffer.samples[self.position..][0..count]);
        queue_buffer.mAudioDataByteSize = @intCast(count * @sizeOf(f32));

        if (self.api.enqueueBuffer(queue, queue_buffer, 0, null) != 0) self.failed.store(true, .release);
        self.position += count;
        return true;
    }

    /// Stops the queue after the queued buffers are played. Only the first call stops it.
    fn requestStop(self: *State, queue: AudioQueueRef) void {
        if (self.stop_requested.swap(true, .acq_rel)) return;
        if (self.api.stop(queue, 0) != 0) self.failed.store(true, .release);
    }
};

/// Called by AudioQueue when `queue_buffer` has been played.
fn outputCallback(user_data: ?*anyopaque, queue: AudioQueueRef, queue_buffer: AudioQueueBufferRef) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(user_data.?));
    if (!state.fill(queue, queue_buffer)) state.requestStop(queue);
}

/// Called by AudioQueue when `kAudioQueueProperty_IsRunning` changes.
fn isRunningListener(user_data: ?*anyopaque, queue: AudioQueueRef, property: u32) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(user_data.?));
    if (property != K_AUDIO_QUEUE_PROPERTY_IS_RUNNING) return;

    var is_running: u32 = 1;
    var size: u32 = @sizeOf(u32);
    if (state.api.getProperty(queue, property, &is_running, &size) != 0) {
        state.failed.store(true, .release);
        state.stopped.store(true, .release);
        return;
    }
    if (is_running == 0) state.stopped.store(true, .release);
}

/// Plays `buffer` through the default output device and blocks until playback completes.
///
/// ## Errors
/// Returns `Error` when AudioToolbox cannot be loaded, an AudioQueue call fails, or the queue
/// does not stop in time. `io.sleep` errors are returned as well.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    _ = allocator;
    if (buffer.samples.len == 0) return;

    var lib = std.DynLib.open(AUDIO_TOOLBOX_PATH) catch return error.AudioToolboxNotFound;
    defer lib.close();
    const api = try Api.load(&lib);

    const bytes_per_frame: u32 = @as(u32, buffer.channels) * @sizeOf(f32);
    const format: AudioStreamBasicDescription = .{
        .mSampleRate = @floatFromInt(buffer.sample_rate),
        .mFormatID = K_AUDIO_FORMAT_LINEAR_PCM,
        .mFormatFlags = K_AUDIO_FORMAT_FLAG_IS_FLOAT | K_AUDIO_FORMAT_FLAG_IS_PACKED,
        .mBytesPerPacket = bytes_per_frame,
        .mFramesPerPacket = 1,
        .mBytesPerFrame = bytes_per_frame,
        .mChannelsPerFrame = buffer.channels,
        .mBitsPerChannel = 32,
        .mReserved = 0,
    };

    var state: State = .{ .api = &api, .buffer = buffer };

    var maybe_queue: ?AudioQueueRef = null;
    try check(api.newOutput(&format, outputCallback, &state, null, null, 0, &maybe_queue));
    const queue = maybe_queue orelse return error.AudioQueueFailed;
    // Disposing the queue also frees its buffers.
    defer _ = api.dispose(queue, 1);

    try check(api.addPropertyListener(queue, K_AUDIO_QUEUE_PROPERTY_IS_RUNNING, isRunningListener, &state));

    // Prime the buffers. A short sound may be fully enqueued before every buffer is used.
    for (0..BUFFER_COUNT) |_| {
        var maybe_queue_buffer: ?AudioQueueBufferRef = null;
        try check(api.allocateBuffer(queue, FRAMES_PER_BUFFER * bytes_per_frame, &maybe_queue_buffer));
        const queue_buffer = maybe_queue_buffer orelse return error.AudioQueueFailed;
        if (!state.fill(queue, queue_buffer)) break;
    }
    const fully_primed = state.position == buffer.samples.len;
    if (state.failed.load(.acquire)) return error.AudioQueueFailed;

    try check(api.start(queue, null));
    if (fully_primed) state.requestStop(queue);

    const duration_ms = buffer.frames() * std.time.ms_per_s / buffer.sample_rate;
    const max_polls = (duration_ms + TIMEOUT_MARGIN_MS) / POLL_INTERVAL_MS;
    var polls: usize = 0;
    while (!state.stopped.load(.acquire)) : (polls += 1) {
        if (state.failed.load(.acquire)) return error.AudioQueueFailed;
        if (polls >= max_polls) return error.PlaybackTimeout;
        try io.sleep(std.Io.Duration.fromMilliseconds(POLL_INTERVAL_MS), .real);
    }
    if (state.failed.load(.acquire)) return error.AudioQueueFailed;
}

fn check(status: OSStatus) Error!void {
    if (status != 0) return error.AudioQueueFailed;
}

fn fourCharCode(comptime code: *const [4]u8) u32 {
    return std.mem.readInt(u32, code, .big);
}

test "fourCharCode matches the AudioToolbox constants" {
    try std.testing.expectEqual(@as(u32, 0x6C70636D), K_AUDIO_FORMAT_LINEAR_PCM);
    try std.testing.expectEqual(@as(u32, 0x6171726E), K_AUDIO_QUEUE_PROPERTY_IS_RUNNING);
}

test "State.fill splits the samples into whole frames per buffer" {
    const Fake = struct {
        var enqueued_bytes: [4]u32 = undefined;
        var enqueue_count: usize = 0;

        fn enqueueBuffer(queue: AudioQueueRef, queue_buffer: AudioQueueBufferRef, packets: u32, descriptions: ?*const anyopaque) callconv(.c) OSStatus {
            _ = queue;
            _ = packets;
            _ = descriptions;
            enqueued_bytes[enqueue_count] = queue_buffer.mAudioDataByteSize;
            enqueue_count += 1;
            return 0;
        }
    };

    var api: Api = undefined;
    api.enqueueBuffer = Fake.enqueueBuffer;

    // 5 stereo frames into buffers holding 2 frames (5 floats of capacity, rounded down to 4).
    const samples = [_]f32{ 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 };
    var state: State = .{ .api = &api, .buffer = .{ .samples = &samples, .sample_rate = 44100, .channels = 2 } };

    var data: [5]f32 = undefined;
    var queue_buffer: AudioQueueBuffer = .{
        .mAudioDataBytesCapacity = @sizeOf(@TypeOf(data)),
        .mAudioData = &data,
        .mAudioDataByteSize = 0,
        .mUserData = null,
        .mPacketDescriptionCapacity = 0,
        .mPacketDescriptions = null,
        .mPacketDescriptionCount = 0,
    };
    var dummy: u8 = 0;
    const queue: AudioQueueRef = @ptrCast(&dummy);

    try std.testing.expect(state.fill(queue, &queue_buffer));
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.1, 0.2, 0.3 }, data[0..4]);
    try std.testing.expect(state.fill(queue, &queue_buffer));
    try std.testing.expect(state.fill(queue, &queue_buffer));
    try std.testing.expectEqualSlices(f32, &.{ 0.8, 0.9 }, data[0..2]);
    try std.testing.expect(!state.fill(queue, &queue_buffer));

    try std.testing.expectEqual(@as(usize, 3), Fake.enqueue_count);
    try std.testing.expectEqualSlices(u32, &.{ 16, 16, 8 }, Fake.enqueued_bytes[0..3]);
    try std.testing.expect(!state.failed.load(.acquire));
}

test "Api.load finds every AudioToolbox function" {
    var lib = try std.DynLib.open(AUDIO_TOOLBOX_PATH);
    defer lib.close();
    _ = try Api.load(&lib);
}
