const std = @import("std");
const di = @import("deadcli");

fn ioError(reason: anyerror) noreturn {
    std.debug.panic("Failed to print: {any}.", .{reason});
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
}
