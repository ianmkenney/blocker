const std = @import("std");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const Executable = union(enum) {
    cmd: []const []const u8,
    func: *const fn ([]u8) usize,
};

fn blocker_example(buffer: []u8) usize {
    const name = "Blocker example";
    @memcpy(buffer[0..name.len], name);
    buffer[name.len] = 0;
    return name.len;
}

const Block = struct {
    exec: Executable,
    interval: u8,
    allocator: std.mem.Allocator,
    pub fn execute(self: *Block) void {
        _ = self;
    }
    pub fn init(exec: Executable, allocator: std.mem.Allocator) Block {
        return .{ .exec = exec, .interval = 5, .allocator = allocator };
    }
};

fn setRoot(dpy: *c.Display, msg: []const u8) !void {
    const screen = c.DefaultScreen(dpy);
    const root = c.RootWindow(dpy, screen);

    const allocator = std.heap.page_allocator;
    var buff = try allocator.alloc(u8, msg.len + 1);
    defer allocator.free(buff);

    @memcpy(buff[0..msg.len], msg[0..msg.len]);
    buff[msg.len] = 0;

    _ = c.XStoreName(dpy, root, buff[0..msg.len :0]);
}

fn execute_block(blk: Block, buffer: []u8) !usize {
    const allocator = std.heap.page_allocator;

    switch (blk.exec) {
        .cmd => |cmd| {
            var child: std.process.Child = .init(cmd, allocator);
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
        },
        .func => |func| {
            const length = func(buffer);
            return length;
        },
    }
}

pub fn main() !void {
    const palloc = std.heap.page_allocator;

    const blks = [_]Block{
        .init(.{ .cmd = &[_][]const u8{"date"} }, palloc),
        .init(.{ .cmd = &[_][]const u8{ "acpi", "-b" } }, palloc),
        .init(.{ .cmd = &[_][]const u8{ "acpi", "-t" } }, palloc),
        .init(.{ .func = blocker_example }, palloc),
    };

    while (true) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(palloc);

        var buffer: [256]u8 = .{0} ** 256;
        for (blks, 0..) |blk, i| {
            const length = try execute_block(blk, &buffer);
            try output.appendSlice(palloc, buffer[0..length :0]);
            if (i != blks.len - 1) {
                try output.appendSlice(palloc, " | ");
            } else {
                try output.appendSlice(palloc, " ");
            }
        }

        const dpy = c.XOpenDisplay(null).?;
        try setRoot(dpy, output.items);
        _ = c.XCloseDisplay(dpy);
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}
