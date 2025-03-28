const std = @import("std");
const cli = @import("deadsimple").cli;

const stdoutWriter = std.io.getStdOut().writer();
const stderrWriter = std.io.getStdErr().writer();

fn ioError(reason: anyerror) noreturn {
    std.debug.panic("Failed to access stdout: {any}.", .{reason});
}

fn printError(comptime format: []const u8, args: anytype) u8 {
    stderrWriter.print("Error: " ++ format ++ "\n", args) catch |e| ioError(e);
    return 1;
}

fn numberU64Error(numStr: []const u8) u8 {
    return printError("Couldn't convert \"{s}\" to a 64bit unsigned number.", .{numStr});
}

fn timeOverflowError(timeStr: []const u8, prefix: []const u8) u8 {
    return printError("Given time \"{s}{s}\" shouldn't exeed a week.", .{ timeStr, prefix });
}

fn unknownCliError(reason: anyerror) u8 {
    return printError("Failed to interpret CLI: {any}.", .{reason});
}

fn noNumberError() u8 {
    return printError("At least one number must be specified.", .{});
}

pub fn main() u8 {
    const Args = cli.ArgStruct(
        "Dead simple cli blocking countdown for linux",
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

    const parsedArgs = Args.parseArgs(std.os.argv[1..]) catch |e| return unknownCliError(e);
    const args = parsedArgs.args;

    if (args.help) {
        Args.displayHelp(stdoutWriter, std.os.argv[0]) catch |e| ioError(e);
        return 0;
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
                const timeNum = std.fmt.parseInt(u64, timeStr, 10) catch return numberU64Error(timeStr);
                if (timeNum > limitNum) return timeOverflowError(timeStr, prefixStr);
                break :blk timeNum * inMsMultiplierNum;
            }
        }

        return noNumberError();
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

        stdoutWriter.print("\x1B[2K\r{:0>3}:{:0>2}:{:0>2}:{:0>3}", .{ hours, minutes, seconds, milliseconds }) catch |e| ioError(e);

        std.time.sleep(std.time.ns_per_ms); // Wait one ms
    }

    return 0;
}
