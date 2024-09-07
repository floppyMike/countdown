const std = @import("std");
const di = @import("deadcli");

fn numberU64Error(numStr: []const u8) noreturn {
    std.debug.panic("Couldn't convert \"{s}\" to a 64bit unsigned number.", .{numStr});
}

fn ioError(reason: anyerror) noreturn {
    std.debug.panic("Failed to print: {any}.", .{reason});
}

fn timeOverflowError(timeStr: []const u8, prefix: []const u8) noreturn {
    std.debug.panic("Given time \"{s}{s}\" shouldn't exeed a week.", .{ timeStr, prefix });
}

fn numberError(numStr: []const u8) noreturn {
    std.debug.panic("Couldn't convert \"{s}\" to a positive number.", .{numStr});
}

pub fn main() void {
    const stdoutFile = std.io.getStdOut().writer();

    const Args = di.ArgStruct(
        "deadtimer",
        "Dead simple cli blocking timer for linux",
        &.{.{
            .name = "help",
            .desc = "Displays this help message.",
        }},
        &.{ .{
            .name = "ms",
            .desc = "Count down milliseconds.",
        }, .{
            .name = "s",
            .desc = "Count down seconds.",
        }, .{
            .name = "min",
            .desc = "Count down minutes.",
        }, .{
            .name = "h",
            .desc = "Count down hours.",
        } },
        &.{},
        null,
    );

    const parsedArgs = Args.parseArgs(std.os.argv[1..]) catch {
        Args.displayHelp(stdoutFile) catch |e| ioError(e);
        return;
    };

    const args = parsedArgs.args;

    if (args.help) {
        Args.displayHelp(stdoutFile) catch |e| ioError(e);
        return;
    }

    //
    // Convert time
    //

    const time = blk: {
        if (args.ms) |ms| {
            break :blk std.fmt.parseInt(u64, ms, 10) catch numberError(ms);
        }
        if (args.s) |s| {
            break :blk (std.fmt.parseInt(u64, s, 10) catch numberError(s)) * std.time.ms_per_s;
        }
        if (args.min) |min| {
            break :blk (std.fmt.parseInt(u64, min, 10) catch numberError(min)) * std.time.ms_per_min;
        }
        if (args.h) |h| {
            break :blk (std.fmt.parseInt(u64, h, 10) catch numberError(h)) * std.time.ms_per_hour;
        }

        @panic("At least one number must be specified.");
    };

    //
    // Create time state
    //

    const stopAt = @as(u64, @intCast(std.time.milliTimestamp())) + time;

    //
    // Wait out time
    //

    while (true) {
        const currTime: u64 = @intCast(std.time.milliTimestamp());
        if (currTime > stopAt) {
            break;
        }

        var remaining = stopAt - currTime;

        const hours = std.math.divFloor(u64, remaining, std.time.ms_per_hour) catch unreachable;
        remaining -= hours * std.time.ms_per_hour;

        const minutes = std.math.divFloor(u64, remaining, std.time.ms_per_min) catch unreachable;
        remaining -= minutes * std.time.ms_per_min;

        const seconds = std.math.divFloor(u64, remaining, std.time.ms_per_s) catch unreachable;
        remaining -= seconds * std.time.ms_per_s;

        const milliseconds = remaining;

        stdoutFile.print("\x1B[2K\r{:0>3}:{:0>2}:{:0>2}:{:0>3}", .{ hours, minutes, seconds, milliseconds }) catch |e| ioError(e);

        std.time.sleep(std.time.ns_per_ms); // Wait one ms
    }
}
