//! Lightmix

const std = @import("std");
const testing = std.testing;

test "builder" {
    _ = Builder.init(.{});
}

test "wave" {
    _ = Wave.init(.{});
    _ = Wave.init(.{}).data;
    _ = Wave.init(.{}).apply();
    _ = Wave.init(.{}).apply().data;
}

/// Builder
/// Used to build
/// Usage: Builder.init(.{})
pub const Builder = struct {
    wave: Wave = Wave.init(.{}),

    const initOption = struct {};

    /// `init` method
    fn init(option: initOption) Builder {
        _ = option;

        return Builder{};
    }
};

/// Wave
/// Contains Wave data
/// Usage: Wave.init(.{}).apply()
const Wave = struct {
    data: std.ArrayList([]const f32) = undefined,

    const initOption = struct {
        data: std.ArrayList([]const f32) = undefined,
    };

    /// `init` method
    fn init(option: initOption) Wave {
        return Wave{
            .data = option.data,
        };
    }

    /// apply method
    /// Used to apply function, such as sine function
    fn apply(self: Wave) Wave {
        return self;
    }
};
