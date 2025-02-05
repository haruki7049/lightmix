//! Lightmix

const std = @import("std");
const testing = std.testing;

test "wave" {
    _ = Wave.init(.{});
    _ = Wave.init(.{}).data;
    _ = Wave.init(.{}).apply();
    _ = Wave.init(.{}).apply().data;
}

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
