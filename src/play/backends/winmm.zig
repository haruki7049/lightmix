//! # WinMM Playback Backend (Windows)
//!
//! Plays a `Buffer` through the WinMM `waveOut*` API, in Pure Zig.
//!
//! The functions of `winmm.dll` are declared with `extern` in this file. Zig generates their
//! import library itself, so no Windows SDK and no C source are needed.
//!
//! The samples are written as 32-bit float (`WAVE_FORMAT_IEEE_FLOAT`) to the wave mapper, which
//! picks the default output device. `BUFFER_COUNT` headers point directly into the buffer (no
//! copy) and are queued in turn; `play` polls them for `WHDR_DONE`, requeues each finished one
//! with the next chunk, and returns when every chunk has been played.

const std = @import("std");
const Buffer = @import("../backend.zig").Buffer;

pub const name = "winmm";

/// Errors returned by `play`.
pub const Error = error{
    /// No wave output device is available.
    NoOutputDevice,
    /// The output device does not accept the sample rate or the channel count as 32-bit float.
    UnsupportedFormat,
    /// A `waveOut*` function returned an error.
    WaveOutFailed,
    /// Playback did not finish within the duration of the buffer plus `TIMEOUT_MARGIN_MS`.
    PlaybackTimeout,
};

/// Number of headers queued at once.
const BUFFER_COUNT = 3;

/// Number of frames covered by each header.
const CHUNK_FRAMES = 8192;

/// Interval between checks for finished headers.
const POLL_INTERVAL_MS = 10;

/// Time allowed beyond the duration of the buffer before `play` gives up.
const TIMEOUT_MARGIN_MS = 2000;

// <mmsystem.h>, <mmreg.h>
const MMRESULT = u32;
const HWAVEOUT = *opaque {};

const MMSYSERR_NOERROR: MMRESULT = 0;
const MMSYSERR_BADDEVICEID: MMRESULT = 2;
const MMSYSERR_NODRIVER: MMRESULT = 6;
const WAVERR_BADFORMAT: MMRESULT = 32;

const WAVE_MAPPER: u32 = 0xFFFFFFFF;
const CALLBACK_NULL: u32 = 0;
const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
const WHDR_DONE: u32 = 0x00000001;

const WAVEFORMATEX = extern struct {
    wFormatTag: u16,
    nChannels: u16,
    nSamplesPerSec: u32,
    nAvgBytesPerSec: u32,
    nBlockAlign: u16,
    wBitsPerSample: u16,
    cbSize: u16,
};

const WAVEHDR = extern struct {
    lpData: [*]u8,
    dwBufferLength: u32,
    dwBytesRecorded: u32,
    dwUser: usize,
    dwFlags: u32,
    dwLoops: u32,
    lpNext: ?*WAVEHDR,
    reserved: usize,
};

// <mmsystem.h> is packed to 1 byte, but these structures have no padding either way.
// Check the offsets at compile time, so that cross-compiling verifies them.
comptime {
    std.debug.assert(@offsetOf(WAVEFORMATEX, "cbSize") == 16);
    const is_64bit = @sizeOf(usize) == 8;
    std.debug.assert(@offsetOf(WAVEHDR, "dwBufferLength") == if (is_64bit) 8 else 4);
    std.debug.assert(@offsetOf(WAVEHDR, "dwFlags") == if (is_64bit) 24 else 16);
    std.debug.assert(@offsetOf(WAVEHDR, "reserved") == if (is_64bit) 40 else 28);
    std.debug.assert(@sizeOf(WAVEHDR) == if (is_64bit) 48 else 32);
}

extern "winmm" fn waveOutOpen(phwo: *?HWAVEOUT, uDeviceID: u32, pwfx: *const WAVEFORMATEX, dwCallback: usize, dwInstance: usize, fdwOpen: u32) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutPrepareHeader(hwo: HWAVEOUT, pwh: *WAVEHDR, cbwh: u32) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutUnprepareHeader(hwo: HWAVEOUT, pwh: *WAVEHDR, cbwh: u32) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutWrite(hwo: HWAVEOUT, pwh: *WAVEHDR, cbwh: u32) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutReset(hwo: HWAVEOUT) callconv(.winapi) MMRESULT;
extern "winmm" fn waveOutClose(hwo: HWAVEOUT) callconv(.winapi) MMRESULT;

/// Plays `buffer` through the default output device and blocks until playback completes.
///
/// ## Errors
/// Returns `Error` when no output device is available, the device rejects the format, a
/// `waveOut*` call fails, or playback does not finish in time. `io.sleep` errors are returned
/// as well.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    _ = allocator;
    if (buffer.samples.len == 0) return;

    const format = waveFormat(buffer);
    var maybe_device: ?HWAVEOUT = null;
    try check(waveOutOpen(&maybe_device, WAVE_MAPPER, &format, 0, 0, CALLBACK_NULL));
    const device = maybe_device orelse return error.WaveOutFailed;

    var headers: [BUFFER_COUNT]WAVEHDR = undefined;
    var queued: [BUFFER_COUNT]bool = @splat(false);
    defer {
        // Reset marks every queued header as done, so that it can be unprepared.
        _ = waveOutReset(device);
        for (&headers, queued) |*header, is_queued| {
            if (is_queued) _ = waveOutUnprepareHeader(device, header, @sizeOf(WAVEHDR));
        }
        _ = waveOutClose(device);
    }

    const chunk_len = CHUNK_FRAMES * @as(usize, buffer.channels);
    const duration_ms = buffer.frames() * std.time.ms_per_s / buffer.sample_rate;
    const max_polls = (duration_ms + TIMEOUT_MARGIN_MS) / POLL_INTERVAL_MS;

    var position: usize = 0;
    var polls: usize = 0;
    while (true) : (polls += 1) {
        var any_queued = false;
        for (&headers, &queued) |*header, *is_queued| {
            if (is_queued.* and isDone(header)) {
                try check(waveOutUnprepareHeader(device, header, @sizeOf(WAVEHDR)));
                is_queued.* = false;
            }
            if (!is_queued.* and position < buffer.samples.len) {
                const count = @min(chunk_len, buffer.samples.len - position);
                header.* = headerFor(buffer.samples[position..][0..count]);
                try check(waveOutPrepareHeader(device, header, @sizeOf(WAVEHDR)));
                is_queued.* = true;
                try check(waveOutWrite(device, header, @sizeOf(WAVEHDR)));
                position += count;
            }
            any_queued = any_queued or is_queued.*;
        }
        if (!any_queued) return;
        if (polls >= max_polls) return error.PlaybackTimeout;
        try io.sleep(std.Io.Duration.fromMilliseconds(POLL_INTERVAL_MS), .real);
    }
}

/// Returns the 32-bit float wave format of `buffer`.
fn waveFormat(buffer: Buffer) WAVEFORMATEX {
    const block_align: u16 = buffer.channels * @sizeOf(f32);
    return .{
        .wFormatTag = WAVE_FORMAT_IEEE_FLOAT,
        .nChannels = buffer.channels,
        .nSamplesPerSec = buffer.sample_rate,
        .nAvgBytesPerSec = buffer.sample_rate * block_align,
        .nBlockAlign = block_align,
        .wBitsPerSample = 32,
        .cbSize = 0,
    };
}

/// Returns a header pointing at `samples`. WinMM only reads the data of a playback header.
fn headerFor(samples: []const f32) WAVEHDR {
    const bytes = std.mem.sliceAsBytes(samples);
    return .{
        .lpData = @constCast(bytes.ptr),
        .dwBufferLength = @intCast(bytes.len),
        .dwBytesRecorded = 0,
        .dwUser = 0,
        .dwFlags = 0,
        .dwLoops = 0,
        .lpNext = null,
        .reserved = 0,
    };
}

/// Returns whether WinMM has finished playing `header`. The driver sets the flag from another thread.
fn isDone(header: *const WAVEHDR) bool {
    return @atomicLoad(u32, &header.dwFlags, .acquire) & WHDR_DONE != 0;
}

fn check(result: MMRESULT) Error!void {
    return switch (result) {
        MMSYSERR_NOERROR => {},
        MMSYSERR_BADDEVICEID, MMSYSERR_NODRIVER => error.NoOutputDevice,
        WAVERR_BADFORMAT => error.UnsupportedFormat,
        else => error.WaveOutFailed,
    };
}

test "waveFormat describes interleaved 32-bit float samples" {
    const samples = [_]f32{ 0.0, 0.0 };
    const format = waveFormat(.{ .samples = &samples, .sample_rate = 44100, .channels = 2 });
    try std.testing.expectEqual(WAVE_FORMAT_IEEE_FLOAT, format.wFormatTag);
    try std.testing.expectEqual(@as(u16, 2), format.nChannels);
    try std.testing.expectEqual(@as(u32, 44100), format.nSamplesPerSec);
    try std.testing.expectEqual(@as(u16, 8), format.nBlockAlign);
    try std.testing.expectEqual(@as(u32, 44100 * 8), format.nAvgBytesPerSec);
    try std.testing.expectEqual(@as(u16, 32), format.wBitsPerSample);
}

test "headerFor points at the samples without copying" {
    const samples = [_]f32{ 0.25, -0.5, 1.0 };
    const header = headerFor(&samples);
    try std.testing.expectEqual(@intFromPtr(&samples), @intFromPtr(header.lpData));
    try std.testing.expectEqual(@as(u32, 12), header.dwBufferLength);
    try std.testing.expect(!isDone(&header));
}

test "check maps MMRESULT codes to errors" {
    try check(MMSYSERR_NOERROR);
    try std.testing.expectError(error.NoOutputDevice, check(MMSYSERR_BADDEVICEID));
    try std.testing.expectError(error.NoOutputDevice, check(MMSYSERR_NODRIVER));
    try std.testing.expectError(error.UnsupportedFormat, check(WAVERR_BADFORMAT));
    try std.testing.expectError(error.WaveOutFailed, check(1));
}
