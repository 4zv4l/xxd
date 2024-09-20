//! Simple xxd program in zig
const std = @import("std");
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const allocator = std.heap.page_allocator;
const eprint = std.debug.print;

pub fn main() void {
    const args = std.process.argsAlloc(allocator) catch |err| {
        return eprint("xxd: argsAlloc(): {s}\n", .{@errorName(err)});
    };
    defer std.process.argsFree(allocator, args);

    // parse arguments
    const reverse: bool = args.len > 1 and mem.eql(u8, args[1], "-r");
    const file = blk: {
        if (!io.getStdIn().isTty()) break :blk io.getStdIn();

        const filename = if (args.len == 2) args[1] else if (args.len == 3) args[2] else {
            return eprint("usage: xxd [-r] [file]\n", .{});
        };

        break :blk std.fs.cwd().openFile(filename, .{}) catch |err| {
            return eprint("xxd: {s}: {s}\n", .{ filename, @errorName(err) });
        };
    };
    defer file.close();

    // setup buffered IO
    var bout = io.bufferedWriter(io.getStdOut().writer());
    var bin = io.bufferedReader(file.reader());

    if (reverse) {
        load(bin.reader(), bout.writer()) catch |err| {
            return eprint("xxd: load(): {s}\n", .{@errorName(err)});
        };
    } else {
        dump(bin.reader(), bout.writer()) catch |err| {
            return eprint("xxd: dump(): {s}\n", .{@errorName(err)});
        };
    }

    // flush buffered writer (stdout)
    bout.flush() catch return;
}

/// load reader (hex dump) to writer (as bytes)
/// reverse of dump()
///
/// ex: 00000000: 6162 6364 6566 6768 696a 6b6c 6d6e 6f0a  abcdefghijklmno. => abcdefghijklmno\n
pub fn load(reader: anytype, writer: anytype) !void {
    var buff: [68]u8 = undefined; // counting newline
    while (try reader.readUntilDelimiterOrEof(&buff, '\n')) |line| {
        const start_idx = (mem.indexOf(u8, line, ": ") orelse return error.WrongFormat) + 2;
        const end_idx = mem.indexOf(u8, line, "  ") orelse return error.WrongFormat;
        var hexit = mem.splitScalar(u8, line[start_idx..end_idx], ' ');
        while (hexit.next()) |h| {
            var byteit = mem.window(u8, h, 2, 2);
            while (byteit.next()) |b| try writer.writeByte(try fmt.parseUnsigned(u8, b, 16));
        }
    }
}

/// dump reader to writer as hex and ascii with an offset
///
/// ex: abcdefghijklmno\n => 00000000: 6162 6364 6566 6768 696a 6b6c 6d6e 6f0a  abcdefghijklmno.
pub fn dump(reader: anytype, writer: anytype) !void {
    var buff: struct { chunk: [16]u8, hex: [40]u8, ascii: [16]u8 } = undefined;
    var offset: usize = 0;

    while (true) : (offset += 0x10) {
        const chunk = buff.chunk[0..try reader.read(&buff.chunk)];
        if (chunk.len == 0) break;
        try writer.print("{x:0>8}: {s: <40} {s}\n", .{ offset, asHex(chunk, &buff.hex), asAscii(chunk, &buff.ascii) });
    }
}

/// write chunk to hex per pair of two bytes as hex, separated with a space
///
/// ex: \n\naa => 0a0a 6161
pub fn asHex(chunk: []const u8, hex: []u8) []const u8 {
    var idx: usize = 0;
    for (chunk, 0..) |c, i| idx += (fmt.bufPrint(hex[idx..], "{x:0>2}{s}", .{ c, if (i % 2 == 1) " " else "" }) catch unreachable).len;
    return hex[0..idx];
}

/// write chunk to ascii replacing non printable char by a dot
///
/// ex: a[\n => a[.
pub fn asAscii(chunk: []const u8, ascii: []u8) []const u8 {
    for (0.., chunk) |i, c| ascii[i] = if (std.ascii.isPrint(c)) c else '.';
    return ascii[0..chunk.len];
}
