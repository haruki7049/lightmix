//! # ALSA Playback Backend (Linux)
//!
//! Plays a `Buffer` through the ALSA kernel interface, in Pure Zig.
//!
//! This backend does not use `libasound`. It opens a PCM playback device node
//! (`/dev/snd/pcmC<card>D<device>p`) and drives it with the ioctls declared in the kernel's
//! `<sound/asound.h>`, through raw system calls. No library, not even libc, is linked.
//!
//! ## Device and format
//! - The first playback device that can be opened is used, scanning cards and devices in order.
//!   A device held by a sound server (PipeWire, PulseAudio) returns `error.DeviceBusy`.
//! - The sample format is the first one the device accepts among 32-bit float, 32-bit integer
//!   and 16-bit integer, in the native byte order. Integer formats saturate samples outside
//!   `[-1.0, 1.0]` and write NaN as silence.
//! - The sample rate and the channel count are never converted: a device that does not accept
//!   them returns `error.UnsupportedSampleRate` or `error.UnsupportedChannels`.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const Buffer = @import("../backend.zig").Buffer;

pub const name = "alsa";

/// Errors returned by `play`.
pub const Error = error{
    /// No PCM playback device node was found under `/dev/snd`.
    NoOutputDevice,
    /// Every playback device found is held by another process, such as a sound server.
    DeviceBusy,
    /// The playback devices found cannot be opened with the permissions of this process.
    AccessDenied,
    /// The device does not accept the sample rate of the buffer.
    UnsupportedSampleRate,
    /// The device does not accept the channel count of the buffer.
    UnsupportedChannels,
    /// The device accepts none of the sample formats this backend writes.
    UnsupportedFormat,
    /// An ALSA ioctl failed.
    DeviceFailed,
};

/// Highest card and device numbers scanned for a playback device node.
const MAX_CARDS = 32;
const MAX_DEVICES = 32;

/// Number of frames converted at once for integer sample formats.
const CHUNK_FRAMES = 4096;

// <sound/asound.h>: hardware parameter indices
const HW_PARAM_ACCESS = 0;
const HW_PARAM_FORMAT = 1;
const HW_PARAM_SUBFORMAT = 2;
const HW_PARAM_FIRST_INTERVAL = 8;
const HW_PARAM_SAMPLE_BITS = 8;
const HW_PARAM_FRAME_BITS = 9;
const HW_PARAM_CHANNELS = 10;
const HW_PARAM_RATE = 11;

const ACCESS_RW_INTERLEAVED = 3;
const SUBFORMAT_STD = 0;
/// The `integer` bit field of `struct snd_interval`; bit fields start at the most significant
/// bit on big-endian targets.
const INTERVAL_INTEGER: u32 = if (builtin.cpu.arch.endian() == .little) 1 << 2 else 1 << 29;

/// Sample formats this backend writes, in order of preference.
const SampleFormat = enum {
    float32,
    int32,
    int16,

    const preference = [_]SampleFormat{ .float32, .int32, .int16 };

    /// Returns the `SNDRV_PCM_FORMAT_*` value in the native byte order.
    fn code(self: SampleFormat) u32 {
        const little = builtin.cpu.arch.endian() == .little;
        return switch (self) {
            .float32 => if (little) 14 else 15, // FLOAT_LE / FLOAT_BE
            .int32 => if (little) 10 else 11, // S32_LE / S32_BE
            .int16 => if (little) 2 else 3, // S16_LE / S16_BE
        };
    }

    fn bits(self: SampleFormat) u32 {
        return switch (self) {
            .float32, .int32 => 32,
            .int16 => 16,
        };
    }
};

// <sound/asound.h>: ioctl structures
const Mask = extern struct {
    bits: [8]u32,
};

const Interval = extern struct {
    min: u32,
    max: u32,
    /// Bit fields `openmin`, `openmax`, `integer` and `empty`, from the least significant bit.
    flags: u32,
};

const HwParams = extern struct {
    flags: u32,
    masks: [3]Mask,
    mres: [5]Mask,
    intervals: [12]Interval,
    ires: [9]Interval,
    rmask: u32,
    cmask: u32,
    info: u32,
    msbits: u32,
    rate_num: u32,
    rate_den: u32,
    fifo_size: c_ulong,
    reserved: [64]u8,

    /// Returns parameters that allow every configuration, like `snd_pcm_hw_params_any`.
    fn any() HwParams {
        var params = std.mem.zeroes(HwParams);
        for (&params.masks) |*mask| mask.bits = @splat(std.math.maxInt(u32));
        for (&params.intervals) |*interval| interval.* = .{ .min = 0, .max = std.math.maxInt(u32), .flags = 0 };
        params.rmask = std.math.maxInt(u32);
        params.info = std.math.maxInt(u32);
        return params;
    }

    /// Restricts the mask parameter `param` to the single value `value`.
    fn setMask(self: *HwParams, param: usize, value: u32) void {
        const mask = &self.masks[param];
        mask.bits = @splat(0);
        mask.bits[value / 32] = @as(u32, 1) << @intCast(value % 32);
    }

    /// Restricts the interval parameter `param` to the single integer `value`.
    fn setInterval(self: *HwParams, param: usize, value: u32) void {
        self.intervals[param - HW_PARAM_FIRST_INTERVAL] = .{ .min = value, .max = value, .flags = INTERVAL_INTEGER };
    }
};

const XferI = extern struct {
    result: c_long,
    buf: ?*const anyopaque,
    frames: c_ulong,
};

// <sound/asound.h>: ioctl requests
const IOCTL_HW_REFINE = linux.IOCTL.IOWR('A', 0x10, HwParams);
const IOCTL_HW_PARAMS = linux.IOCTL.IOWR('A', 0x11, HwParams);
const IOCTL_PREPARE = linux.IOCTL.IO('A', 0x40);
const IOCTL_DRAIN = linux.IOCTL.IO('A', 0x44);
const IOCTL_WRITEI_FRAMES = linux.IOCTL.IOW('A', 0x50, XferI);

// Check the layout against <sound/asound.h> at compile time, so that cross-compiling for a
// target verifies it without running on that target.
comptime {
    const long_size = @sizeOf(c_ulong);
    std.debug.assert(@sizeOf(HwParams) == if (long_size == 8) 608 else 604);
    std.debug.assert(@offsetOf(HwParams, "intervals") == 260);
    std.debug.assert(@offsetOf(HwParams, "rmask") == 512);
    std.debug.assert(@sizeOf(XferI) == 3 * long_size);
    if (builtin.cpu.arch == .x86_64) {
        std.debug.assert(IOCTL_HW_REFINE == 0xc2604110);
        std.debug.assert(IOCTL_HW_PARAMS == 0xc2604111);
        std.debug.assert(IOCTL_PREPARE == 0x00004140);
        std.debug.assert(IOCTL_DRAIN == 0x00004144);
        std.debug.assert(IOCTL_WRITEI_FRAMES == 0x40184150);
    }
}

/// Plays `buffer` through the first available playback device and blocks until playback completes.
///
/// ## Errors
/// Returns `Error` when no usable device is found, the device rejects the buffer's properties,
/// or an ioctl fails. Allocation errors of the integer conversion buffer are returned as well.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    _ = io;
    if (buffer.samples.len == 0) return;

    const fd = try openPlaybackDevice();
    defer _ = linux.close(fd);

    const format = try configure(fd, buffer);
    try ioctl(fd, IOCTL_PREPARE, 0);

    switch (format) {
        .float32 => try writeFrames(f32, fd, buffer.samples, buffer.channels),
        .int32 => try writeConverted(i32, allocator, fd, buffer),
        .int16 => try writeConverted(i16, allocator, fd, buffer),
    }

    // DRAIN blocks until every written frame is played.
    switch (linux.errno(linux.ioctl(fd, IOCTL_DRAIN, 0))) {
        .SUCCESS, .PIPE => {},
        else => return error.DeviceFailed,
    }
}

/// Opens the first PCM playback device node that can be opened for writing.
fn openPlaybackDevice() Error!linux.fd_t {
    var result: Error = error.NoOutputDevice;
    for (0..MAX_CARDS) |card| {
        for (0..MAX_DEVICES) |device| {
            var path_buf: [64]u8 = undefined;
            const path = std.fmt.bufPrintZ(&path_buf, "/dev/snd/pcmC{d}D{d}p", .{ card, device }) catch unreachable;
            const rc = linux.open(path, .{ .ACCMODE = .WRONLY, .CLOEXEC = true }, 0);
            switch (linux.errno(rc)) {
                .SUCCESS => return @intCast(rc),
                .NOENT, .NODEV, .NXIO => {},
                .BUSY => result = error.DeviceBusy,
                .ACCES, .PERM => if (result != error.DeviceBusy) {
                    result = error.AccessDenied;
                },
                else => {},
            }
        }
    }
    return result;
}

/// Sets the hardware parameters of `fd` for `buffer` and returns the chosen sample format.
fn configure(fd: linux.fd_t, buffer: Buffer) Error!SampleFormat {
    for (SampleFormat.preference) |format| {
        var params = hwParamsFor(buffer, format);
        switch (linux.errno(linux.ioctl(fd, IOCTL_HW_PARAMS, @intFromPtr(&params)))) {
            .SUCCESS => return format,
            .INVAL => {},
            else => return error.DeviceFailed,
        }
    }

    // No format was accepted; find out which property the device rejects.
    var rate_params = HwParams.any();
    rate_params.setInterval(HW_PARAM_RATE, buffer.sample_rate);
    if (!refines(fd, &rate_params)) return error.UnsupportedSampleRate;

    var channel_params = HwParams.any();
    channel_params.setInterval(HW_PARAM_CHANNELS, buffer.channels);
    if (!refines(fd, &channel_params)) return error.UnsupportedChannels;

    return error.UnsupportedFormat;
}

/// Returns the hardware parameters that play `buffer` in `format`, interleaved.
fn hwParamsFor(buffer: Buffer, format: SampleFormat) HwParams {
    var params = HwParams.any();
    params.setMask(HW_PARAM_ACCESS, ACCESS_RW_INTERLEAVED);
    params.setMask(HW_PARAM_FORMAT, format.code());
    params.setMask(HW_PARAM_SUBFORMAT, SUBFORMAT_STD);
    params.setInterval(HW_PARAM_SAMPLE_BITS, format.bits());
    params.setInterval(HW_PARAM_FRAME_BITS, format.bits() * buffer.channels);
    params.setInterval(HW_PARAM_CHANNELS, buffer.channels);
    params.setInterval(HW_PARAM_RATE, buffer.sample_rate);
    return params;
}

/// Returns whether the device accepts `params`, without applying them.
fn refines(fd: linux.fd_t, params: *HwParams) bool {
    return linux.errno(linux.ioctl(fd, IOCTL_HW_REFINE, @intFromPtr(params))) == .SUCCESS;
}

/// Converts the samples of `buffer` to `Int` chunk by chunk and writes them to `fd`.
fn writeConverted(comptime Int: type, allocator: std.mem.Allocator, fd: linux.fd_t, buffer: Buffer) !void {
    const chunk = try allocator.alloc(Int, CHUNK_FRAMES * @as(usize, buffer.channels));
    defer allocator.free(chunk);

    var position: usize = 0;
    while (position < buffer.samples.len) {
        const count = @min(chunk.len, buffer.samples.len - position);
        for (buffer.samples[position..][0..count], chunk[0..count]) |sample, *dest| {
            dest.* = toInt(Int, sample);
        }
        try writeFrames(Int, fd, chunk[0..count], buffer.channels);
        position += count;
    }
}

/// Writes the interleaved `samples` to `fd`, blocking until every frame is queued.
fn writeFrames(comptime Sample: type, fd: linux.fd_t, samples: []const Sample, channels: u16) Error!void {
    const frames = samples.len / channels;
    var written: usize = 0;
    while (written < frames) {
        var xfer: XferI = .{
            .result = 0,
            .buf = samples[written * channels ..].ptr,
            .frames = @intCast(frames - written),
        };
        switch (linux.errno(linux.ioctl(fd, IOCTL_WRITEI_FRAMES, @intFromPtr(&xfer)))) {
            .SUCCESS => written += @intCast(xfer.result),
            .INTR, .AGAIN => {},
            // An underrun stops the stream; prepare it again and continue.
            .PIPE => try ioctl(fd, IOCTL_PREPARE, 0),
            else => return error.DeviceFailed,
        }
    }
}

fn ioctl(fd: linux.fd_t, request: u32, arg: usize) Error!void {
    if (linux.errno(linux.ioctl(fd, request, arg)) != .SUCCESS) return error.DeviceFailed;
}

/// Converts `sample` to a signed integer sample, saturating outside `[-1.0, 1.0]`.
/// NaN becomes silence (`0`).
fn toInt(comptime Int: type, sample: f32) Int {
    if (std.math.isNan(sample)) return 0;
    // Scale in f64: f32 rounds maxInt(i32) up to 2^31, which overflows i32 at 1.0.
    const max: f64 = @floatFromInt(std.math.maxInt(Int));
    const clamped: f64 = std.math.clamp(sample, -1.0, 1.0);
    return @intFromFloat(@round(clamped * max));
}

test "hwParamsFor restricts every parameter to a single value" {
    const samples = [_]f32{ 0.0, 0.0 };
    const params = hwParamsFor(.{ .samples = &samples, .sample_rate = 48000, .channels = 2 }, .int16);

    try std.testing.expectEqual(@as(u32, 1 << ACCESS_RW_INTERLEAVED), params.masks[HW_PARAM_ACCESS].bits[0]);
    try std.testing.expectEqual(@as(u32, 1) << @intCast(SampleFormat.int16.code()), params.masks[HW_PARAM_FORMAT].bits[0]);
    try std.testing.expectEqual(@as(u32, 1 << SUBFORMAT_STD), params.masks[HW_PARAM_SUBFORMAT].bits[0]);

    const Expected = struct { param: usize, value: u32 };
    const expected = [_]Expected{
        .{ .param = HW_PARAM_SAMPLE_BITS, .value = 16 },
        .{ .param = HW_PARAM_FRAME_BITS, .value = 32 },
        .{ .param = HW_PARAM_CHANNELS, .value = 2 },
        .{ .param = HW_PARAM_RATE, .value = 48000 },
    };
    for (expected) |e| {
        const interval = params.intervals[e.param - HW_PARAM_FIRST_INTERVAL];
        try std.testing.expectEqual(e.value, interval.min);
        try std.testing.expectEqual(e.value, interval.max);
    }
}

test "toInt saturates out-of-range samples and silences NaN" {
    try std.testing.expectEqual(@as(i16, 0), toInt(i16, 0.0));
    try std.testing.expectEqual(@as(i16, 16384), toInt(i16, 0.5));
    try std.testing.expectEqual(@as(i16, 32767), toInt(i16, 1.0));
    try std.testing.expectEqual(@as(i16, 32767), toInt(i16, 1.5));
    try std.testing.expectEqual(@as(i16, -32767), toInt(i16, -2.0));
    try std.testing.expectEqual(@as(i16, 0), toInt(i16, std.math.nan(f32)));
    try std.testing.expectEqual(@as(i32, std.math.maxInt(i32)), toInt(i32, 1.0));
    try std.testing.expectEqual(@as(i32, std.math.maxInt(i32)), toInt(i32, 1.5));
    try std.testing.expectEqual(@as(i32, -std.math.maxInt(i32)), toInt(i32, -1.0));
    try std.testing.expectEqual(@as(i32, 0), toInt(i32, std.math.nan(f32)));
}
