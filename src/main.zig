const std = @import("std");
const c = @cImport({
    @cInclude("webview/webview.h");
});
pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    const w = c.webview_create(0, null);
    c.webview_set_title(w, "MarkdownRendererZig");
    c.webview_set_size(w, 480, 320, c.WEBVIEW_HINT_NONE);
    c.webview_set_html(w, "<h1>Hello?</h1><b>bro</b><marquee>kek</marquee>");
    c.webview_run(w);
    c.webview_destroy(w);
    std.debug.print("All your planetz are belong to us.\n", .{});
}
