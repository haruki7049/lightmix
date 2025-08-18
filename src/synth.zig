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

const Part = enum {
    attack,
    decay,
    sustain,
    release,
};

pub fn set(self: Self, part: Part, data: []const f32) Self {
    switch (part) {
        .attack => self.allocator.free(self.attack),
        .decay => self.allocator.free(self.decay),
        .sustain => self.allocator.free(self.sustain),
        .release => self.allocator.free(self.release),
    }

    const owned_data = self.allocator.alloc(f32, data.len) catch @panic("Out of memory");
    @memcpy(owned_data, data);

    var result: Self = self;

    switch (part) {
        .attack => {
            result.attack = owned_data;
        },
        .decay => {
            result.decay = owned_data;
        },
        .sustain => {
            result.sustain = owned_data;
        },
        .release => {
            result.release = owned_data;
        },
    }

    return result;
}

//pub fn finalize(self: Self) !Wave {}

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

test "init -> set -> deinit" {
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

    const result: Self = empty_synth.set(.release, &[_]f32{ 0.0, 0.0, 0.0 });
    defer result.deinit();

    for (0..result.release.len) |i| {
        try testing.expectApproxEqAbs(result.release[i], 0.0, 0.001);
    }
}
