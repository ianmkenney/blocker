const std = @import("std");
const config = @import("config.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const Executable = union(enum) {
    cmd: []const []const u8,
    func: *const fn (*std.ArrayList(u8), std.mem.Allocator) error{OutOfMemory}!void,
};

pub const Block = struct {
    exec: Executable,
    output: std.ArrayList(u8),
    allocator: std.mem.Allocator = std.heap.page_allocator,

    pub fn execute(
        self: *Block,
        allocator: std.mem.Allocator,
    ) !void {
        self.output.clearAndFree(self.allocator);

        switch (self.exec) {
            .cmd => |cmd| {
                var stdout_capture: std.ArrayList(u8) = .empty;
                defer stdout_capture.deinit(allocator);
                var stderr_capture: std.ArrayList(u8) = .empty;
                defer stderr_capture.deinit(allocator);

                var child: std.process.Child = .init(cmd, allocator);
                child.stdout_behavior = .Pipe;
                child.stderr_behavior = .Pipe;

                try child.spawn();
                try std.process.Child.collectOutput(child, allocator, &stdout_capture, &stderr_capture, 2048);
                _ = try child.wait();

                try self.output.appendSlice(self.allocator, stdout_capture.items);
                if (self.output.getLast() == '\n') {
                    _ = self.output.pop();
                }
            },
            .func => |func| {
                try func(&self.output, allocator);
            },
        }
    }

    pub fn init(exec: Executable) @This() {
        const output: std.ArrayList(u8) = .empty;
        return Block{ .exec = exec, .output = output };
    }
};

fn setRoot(dpy: *c.Display, msg: [:0]const u8) !void {
    const screen = c.DefaultScreen(dpy);
    const root = c.RootWindow(dpy, screen);

    _ = c.XStoreName(
        dpy,
        root,
        msg,
    );
}

pub fn main() !void {
    const palloc = std.heap.page_allocator;

    var blks = config.blks;

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(palloc);

    while (true) {
        for (&blks, 0..) |*blk, i| {
            try blk.execute(palloc);
            try output.appendSlice(palloc, blk.output.items);
            if (i != blks.len - 1) {
                try output.appendSlice(palloc, " | ");
            } else {
                try output.appendSlice(palloc, " ");
            }
        }

        const dpy = c.XOpenDisplay(null).?;
        try setRoot(dpy, try output.toOwnedSliceSentinel(palloc, 0));
        _ = c.XCloseDisplay(dpy);
        output.clearRetainingCapacity();
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}
