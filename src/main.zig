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

pub fn main() void {
    const stdoutFile = std.io.getStdOut().writer();

    const Args = di.ArgStruct(
        "deadtimer",
        "Dead simple cli blocking timer for linux",
        &.{ .{
            .name = "help",
            .desc = "Displays this help message.",
        }, .{
            .name = "rev",
            .desc = "Rather than counting up, count down.",
        } },
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

    const deltaTime = blk: {
        inline for (
            .{ args.ms, args.s, args.min, args.h },
            .{ std.time.ms_per_week, std.time.s_per_week, 60 * 24 * 7, 24 * 7 },
            .{ "ms", "s", "min", "h" },
            .{ 1, std.time.ms_per_s, std.time.ms_per_min, std.time.ms_per_hour },
        ) |optTimeStr, limitNum, prefixStr, inMsMultiplierNum| {
            if (optTimeStr) |timeStr| {
                const timeNum = std.fmt.parseInt(u64, timeStr, 10) catch numberU64Error(timeStr);
                if (timeNum > limitNum) timeOverflowError(timeStr, prefixStr);
                break :blk timeNum * inMsMultiplierNum;
            }
        }

        @panic("At least one number must be specified.");
    };

    //
    // Create time state
    //
    const startAt: u64 = @bitCast(std.time.milliTimestamp()); // Will never be negative
    const stopAt = startAt +% deltaTime;

    //
    // Wait out time
    //

    while (true) {
        const currTime: u64 = @bitCast(std.time.milliTimestamp()); // Will never by negative
        if (currTime > stopAt) {
            break;
        }

        var remaining = if (args.rev) stopAt -% currTime else currTime -% startAt;

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
