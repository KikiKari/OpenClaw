const std = @import("std");

// OpenClaw Node Health Check (Zig) — raw TCP connect probe via std.net
fn probe(addr: []const u8) void {
    const colon = std.mem.lastIndexOfScalar(u8, addr, ':') orelse {
        std.debug.print("FAIL {s}: no port\n", .{addr});
        return;
    };
    const host = addr[0..colon];
    const port = std.fmt.parseInt(u16, addr[colon + 1 ..], 10) catch {
        std.debug.print("FAIL {s}: bad port\n", .{addr});
        return;
    };
    const stream = std.net.tcpConnectToHost(std.heap.page_allocator, host, port) catch |err| {
        std.debug.print("FAIL {s}: {s}\n", .{ addr, @errorName(err) });
        return;
    };
    defer stream.close();
    std.debug.print("OK   {s}: connected\n", .{addr});
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const default_nodes = [_][]const u8{ "127.0.0.1:8080", "127.0.0.1:8081" };
    if (args.len > 1) {
        for (args[1..]) |node| probe(node);
    } else {
        for (default_nodes) |node| probe(node);
    }
}
