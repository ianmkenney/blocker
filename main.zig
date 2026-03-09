const std = @import("std");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const Block = struct { cmd: []const []const u8 };

fn setRoot(dpy: *c.Display, msg: []const u8) !void {
    const screen = c.DefaultScreen(dpy);
    const root = c.RootWindow(dpy, screen);

    const allocator = std.heap.page_allocator;
    var buff = try allocator.alloc(u8, msg.len + 1);

    @memcpy(buff[0..msg.len], msg[0..msg.len]);
    buff[msg.len] = 0;

    _ = c.XStoreName(dpy, root, buff[0..msg.len :0]);
}

fn execute_block(blk: Block, buffer: []u8) !usize {
    const allocator = std.heap.page_allocator;

    var child: std.process.Child = .init(blk.cmd, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    var stdout: std.ArrayList(u8) = .empty;
    defer stdout.deinit(allocator);
    var stderr: std.ArrayList(u8) = .empty;
    defer stderr.deinit(allocator);

    try std.process.Child.collectOutput(child, allocator, &stdout, &stderr, 2048);
    _ = try child.wait();
    @memcpy(buffer[0..stdout.items.len], stdout.items);
    buffer[stdout.items.len - 1] = 0;
    return stdout.items.len - 1;
}

pub fn main() !void {
    const blk: Block = .{ .cmd = &[_][]const u8{"date"} };

    var buffer: [256]u8 = .{0} ** 256;
    const length = try execute_block(blk, &buffer);

    const dpy = c.XOpenDisplay(null).?;
    defer _ = c.XCloseDisplay(dpy);

    try setRoot(dpy, buffer[0..length]);
}
