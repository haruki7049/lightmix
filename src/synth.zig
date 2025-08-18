//! Synth

const std = @import("std");
const build_options = @import("build_options");

const testing = std.testing;

const Self = @This();
const Wave = @import("./wave.zig");

attack: []const f32,
decay: []const f32,
sustain: []const f32,
release: []const f32,

allocator: std.mem.Allocator,

sample_rate: usize,
channels: usize,
bits: usize,

pub const initOptions = struct {
    attack: []const f32,
    decay: []const f32,
    sustain: []const f32,
    release: []const f32,

    sample_rate: usize,
    channels: usize,
    bits: usize,
};

pub fn init(allocator: std.mem.Allocator, options: initOptions) Self {
    const owned_attack = allocator.alloc(f32, options.attack.len) catch @panic("Out of memory");
    @memcpy(owned_attack, options.attack);

    const owned_decay = allocator.alloc(f32, options.decay.len) catch @panic("Out of memory");
    @memcpy(owned_decay, options.decay);

    const owned_sustain = allocator.alloc(f32, options.sustain.len) catch @panic("Out of memory");
    @memcpy(owned_sustain, options.sustain);

    const owned_release = allocator.alloc(f32, options.release.len) catch @panic("Out of memory");
    @memcpy(owned_release, options.release);

    return Self{
        .attack = owned_attack,
        .decay = owned_decay,
        .sustain = owned_sustain,
        .release = owned_release,

        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.attack);
    self.allocator.free(self.decay);
    self.allocator.free(self.sustain);
    self.allocator.free(self.release);
}

pub fn finalize(self: Self) !Wave {
}

test "init & deinit" {
    const allocator = testing.allocator;
    const empty_synth = Self.init(allocator, .{
        .attack = &[_]f32{},
        .decay = &[_]f32{},
        .sustain = &[_]f32{},
        .release = &[_]f32{},

        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer empty_synth.deinit();
}
