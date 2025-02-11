//! Lightmix

const std = @import("std");
const testing = std.testing;

test "wave" {
    const allocator = testing.allocator;

    _ = Wave.init(.{});
    _ = Wave.init(.{}).data;

    const example = Wave.init(.{
        .data = std.ArrayList([]const f32).init(allocator),
    }).data;
    defer example.deinit();
}

/// Wave
/// Contains Wave data
/// Usage: Wave.init(.{}).apply()
const Wave = struct {
    data: std.ArrayList([]const f32) = undefined,

    const initOption = struct {
        data: std.ArrayList([]const f32) = undefined,
    };

    const Self = @This();

    /// `init` method
    fn init(option: initOption) Wave {
        return Wave{
            .data = option.data,
        };
    }

    /// `deinit` method
    fn deinit(self: *Self) void {
        self.data.deinit();
    }
};

/// ノーツの順番
const Order = struct {
    notes: std.ArrayList([]const Note) = undefined,
};

/// 音符
const Note = struct {
    wave: Wave = undefined,

    /// 秒数
    seconds: u32 = undefined,
};
