const std = @import("std");
const config = @import("config.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const BlockerFuncError = error{OutOfMemory} || std.process.Child.SpawnError;

pub const BlockerFunc = fn (*std.ArrayList(u8), std.mem.Allocator) BlockerFuncError!void;
const Executable = union(enum) {
    cmd: []const []const u8,
    func: *const BlockerFunc,
};

pub const Block = struct {
    exec: Executable,
    output: std.ArrayList(u8),
    allocator: std.mem.Allocator = std.heap.page_allocator,
    interval: usize = 1,
    since_run: usize = 1,

    pub fn execute(
        self: *Block,
        allocator: std.mem.Allocator,
    ) !void {
        if (self.since_run < self.interval) {
            self.since_run = self.since_run + 1;
            return;
        }
        defer self.since_run = 1;

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

    pub fn init(exec: Executable, optional_interval: ?usize) Block {
        const output: std.ArrayList(u8) = .empty;

        if (optional_interval) |interval|
            return Block{ .exec = exec, .output = output, .interval = interval, .since_run = interval };
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

    var iteration: usize = 1;
    while (true) {
        iteration = iteration + 1;
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
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}
