const std = @import("std");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

fn setRoot(dpy: *c.Display, msg: []const u8) !void {
    const screen = c.DefaultScreen(dpy);
    const root = c.RootWindow(dpy, screen);

    var buff: [256]u8 = undefined;
    @memcpy(buff[0..msg.len], msg);

    buff[msg.len] = 0;

    _ = c.XStoreName(dpy, root, &buff);
}

pub fn main() !void {
    const dpy = c.XOpenDisplay(null).?;
    defer _ = c.XCloseDisplay(dpy);

    std.debug.print("{s}\n", .{std.os.argv[1]});

    const msg = "Something";

    try setRoot(dpy, msg);
}
