const std = @import("std");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const Executable = union(enum) {
    cmd: []const []const u8,
    func: *const fn ([]u8, std.mem.Allocator) usize,
};

fn blocker_example(buffer: []u8, allocator: std.mem.Allocator) usize {
    _ = allocator;
    const name = "Blocker example";
    @memcpy(buffer[0..name.len], name);
    buffer[name.len] = 0;
    return name.len;
}

const Block = struct {
    exec: Executable,

    pub fn execute(
        self: Block,
        buffer: []u8,
        allocator: std.mem.Allocator,
    ) !usize {
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

                @memcpy(buffer[0..stdout_capture.items.len], stdout_capture.items);
                if (buffer[stdout_capture.items.len - 1] == '\n') {
                    buffer[stdout_capture.items.len - 1] = 0;
                }

                return stdout_capture.items.len - 1;
            },
            .func => |func| {
                const length = func(buffer, allocator);
                return length;
            },
        }
    }

    pub fn init(exec: Executable) Block {
        return Block{ .exec = exec };
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

pub fn main() !void {
    const palloc = std.heap.page_allocator;

    const blks = [_]Block{
        .init(.{ .cmd = &.{"date"} }),
        .init(.{ .cmd = &.{ "acpi", "-b" } }),
        .init(.{ .cmd = &.{ "acpi", "-t" } }),
        .init(.{ .func = blocker_example }),
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(palloc);

    var buffer: [256]u8 = .{0} ** 256;
    while (true) {
        for (blks, 0..) |blk, i| {
            const length = try blk.execute(&buffer, palloc);
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
        output.clearRetainingCapacity();
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}
