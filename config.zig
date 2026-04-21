const std = @import("std");
const Block = @import("main.zig").Block;
const BlockerFunc = @import("main.zig").BlockerFunc;

const spinner_base_value = "\u{25F4}";
var spinner_offset: u2 = 0;
fn spinnerAnimation(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    spinner_offset = spinner_offset +% 1;
    try output.appendSlice(allocator, &[3]u8{
        spinner_base_value[0],
        spinner_base_value[1],
        spinner_base_value[2] + spinner_offset,
    });
}

fn label(value: []const u8) BlockerFunc {
    const clo = struct {
        fn func(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
            try output.appendSlice(allocator, value);
        }
    };
    return clo.func;
}

var bcounter_ticker: u8 = 0b0;
fn binaryCounter(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    bcounter_ticker = bcounter_ticker +% 1;
    inline for ([_]u8{ 7, 6, 5, 4, 3, 2, 1, 0 }) |index| {
        const mask = bcounter_ticker >> index;
        switch (mask & 1) {
            0 => try output.appendSlice(allocator, "0"),
            1 => try output.appendSlice(allocator, "1"),
            else => unreachable,
        }
    }
}

fn timewTracking(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    var child: std.process.Child = .init(&.{"timew"}, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |exited| {
            switch (exited) {
                0 => try output.appendSlice(allocator, "Time tracking"),
                1 => try output.appendSlice(allocator, "Not time tracking"),
                else => unreachable,
            }
        },
        .Signal => unreachable,
        .Stopped => unreachable,
        .Unknown => unreachable,
    }
}

pub var blks = [_]Block{
    .init(.{ .func = timewTracking }, 5),
    .init(.{ .cmd = &.{"date"} }, 5),
    .init(.{ .cmd = &.{"uptime"} }, 60),
    .init(.{ .cmd = &.{ "acpi", "-b" } }, 5),
    //.init(.{ .cmd = &.{ "acpi", "-t" } }, 30),
    //.init(.{ .func = label("Blocker example") }, 60),
    //.init(.{ .func = binaryCounter }, 1),
    //.init(.{ .func = spinnerAnimation }, 1),
};
