const std = @import("std");
const Block = @import("main.zig").Block;

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

var ticker: u8 = 0b0;
fn binaryCounter(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    ticker = ticker +% 1;
    inline for ([_]u8{ 7, 6, 5, 4, 3, 2, 1, 0 }) |index| {
        const mask = ticker >> index;
        switch (mask & 0b1) {
            0 => try output.appendSlice(allocator, "0"),
            1 => try output.appendSlice(allocator, "1"),
            else => undefined,
        }
    }
}

fn blockerExampleLabel(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    const name = "Blocker example";
    try output.appendSlice(allocator, name);
}

pub var blks = [_]Block{
    .init(.{ .cmd = &.{"date"} }),
    .init(.{ .cmd = &.{"uptime"} }),
    .init(.{ .cmd = &.{ "acpi", "-b" } }),
    .init(.{ .cmd = &.{ "acpi", "-t" } }),
    .init(.{ .func = blockerExampleLabel }),
    .init(.{ .func = binaryCounter }),
    .init(.{ .func = spinnerAnimation }),
};
