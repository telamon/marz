const std = @import("std");
const c = @cImport({
    @cInclude("webview/webview.h");
});
const koino = @import("koino");
const Parser = koino.parser.Parser;

const md_options = koino.Options{
    .extensions = .{
        .table = true,
        .autolink = true,
        .strikethrough = true,
    },
};
const Context = struct {
    w: c.webview_t,
    ally: *const std.mem.Allocator,
    fname: []const u8,
};

const runtime_html = @embedFile("./runtime.html");
fn on_keyup(seq: [*c]const u8, payload: [*c]const u8, arg: ?*anyopaque) callconv(.C) void {
    // std.debug.print("on_keyup: raw_payload: {s}\n", .{payload});
    var n: usize = 0; // am aware of std.json.TokenStream;
    while (payload[n] != 0) n += 1;
    const code = payload[2 .. n - 2];

    const ctx = @ptrCast(*Context, @alignCast(8, arg)); // https://ziglang.org/documentation/master/#Alignment
    std.debug.print("on_keyup<{s}>\n", .{code});
    if (code.len == 1) {
        switch (code[0]) {
            'r' => {
                renderFile(ctx.fname, ctx.w, ctx.ally.*) catch |err| {
                    std.debug.print("Reload failed: {}", .{err});
                };
            },
            'q' => c.webview_terminate(ctx.w),
            else => {},
        }
    }
    c.webview_return(ctx.w, seq, 0, "");
}

pub fn main() !void {
    // const ally = std.heap.c_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) @panic("Leaky Leek!");
    const ally = gpa.allocator();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    const w = c.webview_create(0, null);
    defer c.webview_destroy(w);
    c.webview_set_size(w, 480, 320, c.WEBVIEW_HINT_NONE);

    // Read atttempt to read filename
    const fname = try parseArgs(ally);
    defer ally.free(fname);

    // Set title
    var title = std.ArrayList(u8).init(ally);
    defer title.deinit();
    try std.fmt.format(title.writer(), "MARZ!{s}{c}", .{ fname, 0 });
    c.webview_set_title(w, title.items.ptr);

    // Setup context and create interop binding
    var ctx = Context{
        .w = w,
        .ally = &ally,
        .fname = fname,
    };
    c.webview_bind(w, "z_keyup", on_keyup, &ctx);

    try renderFile(fname, w, ally);

    // start the render loop
    c.webview_run(w);
    std.debug.print("Ok, bye bye now\n", .{});
}

const MarkdownError = error{NoInput};

fn renderFile(fname: []const u8, w: c.webview_t, ally: std.mem.Allocator) !void {
    // Markdown
    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    var parser = try Parser.init(arena.allocator(), md_options);
    defer parser.deinit();

    try parseFile(fname, &parser);
    const doc = try parser.finish();

    var buffer = std.ArrayList(u8).init(ally);
    defer buffer.deinit();

    try buffer.appendSlice(runtime_html); // embed keybinds/jsbootloader

    try koino.html.print(buffer.writer(), ally, md_options, doc);
    try buffer.append(0); // null terminate / use Sentinel?

    c.webview_set_html(w, buffer.items.ptr);
}

// Caller owns returned slice
fn parseArgs(ally: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(ally);
    defer args.deinit();

    if (!args.skip()) return MarkdownError.NoInput;
    const filename = args.next() orelse return MarkdownError.NoInput;
    var fname = try ally.alloc(u8, filename.len);
    std.mem.copy(u8, fname, filename);
    return fname;
}

fn parseFile(fname: []const u8, parser: *Parser) !void {
    var in_file = try std.fs.cwd().openFile(fname, .{});
    defer in_file.close();
    var buf: [1024]u8 = undefined;
    while (true) {
        const n = try in_file.read(&buf);
        try parser.feed(buf[0..n]);
        if (n < 1024) break;
    }
}

test "Watch file" {
    const fname = "test_watch";
    const ally = std.testing.allocator;

    try std.fs.cwd().writeFile(fname, "Hello\n");

    const watcher = try std.fs.Watch(void).init(ally, 0);
    defer watcher.deinit();
    const f = try std.fs.cwd().openFile();
    defer f.close();
    watcher.addFile(f);
    const ev = async watcher.channel.get();
    defer {
        const e = await ev;
        std.log.debug("Channel triggered {}", .{e});
    }
}

test "Parse stream" {
    const ally = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    var parser = try Parser.init(arena.allocator(), md_options);
    defer parser.deinit();

    const fname = "../REFs.md";
    try parseFile(fname, &parser);
    const doc = try parser.finish();

    var buffer = std.ArrayList(u8).init(ally);
    defer buffer.deinit();

    try koino.html.print(buffer.writer(), ally, md_options, doc);
    try buffer.append(0); // null terminate / use Sentinel?
    std.log.debug("Test complete {s}", .{buffer.items});
}
