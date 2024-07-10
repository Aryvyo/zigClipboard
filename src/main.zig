const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/X.h");
    @cInclude("X11/Xutil.h");
});
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
pub fn main() !void {
    // open a display to the X server and whatnot
    // defer closing it
    const display = c.XOpenDisplay(null) orelse {
        std.debug.print("Failed to open display\n", .{});
        return error.FailedToOpenDisplay;
    };
    defer _ = c.XCloseDisplay(display);

    // initialising renderer and zgui and stuff
    try glfw.init();
    defer glfw.terminate();

    //resizable is kinda weird but it opens it as a floating window so we like that
    glfw.windowHintTyped(.resizable, false);
    glfw.windowHintTyped(.doublebuffer, true);

    var glfw_window: *glfw.Window = try glfw.Window.create(400, 500, "Clipboard", null);
    defer glfw_window.destroy();

    glfw.makeContextCurrent(glfw_window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, 4, 0);

    const gl = zopengl.bindings;

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    zgui.init(gpa);
    defer zgui.deinit();

    const scale_factor = scale_factor: {
        const scale = glfw_window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    _ = zgui.io.addFontFromFile(
        "src/Roboto-Medium.ttf",
        std.math.floor(11.0 * scale_factor),
    );

    zgui.getStyle().scaleAllSizes(scale_factor);

    zgui.backend.init(glfw_window);
    defer zgui.backend.deinit();

    //the atoms we'll need to retrieve the clipboard data
    const clipboardAtom = c.XInternAtom(display, "CLIPBOARD", 1);
    const target_atom = c.XInternAtom(display, "UTF8_STRING", 0);
    const property_atom = c.XInternAtom(display, "SELECTION_DATA", 0);

    // create a window in X to do stuff? ig idk
    const screen = c.DefaultScreen(display);
    const window = c.XCreateSimpleWindow(display, c.RootWindow(display, screen), -10, -10, 1, 1, 0, 0, 0);

    // init our clipboard history, and current (last item copied) item
    // defer closing n whatnot snooooooreeee
    var clipboardHistory: std.ArrayList([]u8) = std.ArrayList([]u8).init(std.heap.page_allocator);
    defer {
        for (clipboardHistory.items) |item| {
            std.heap.page_allocator.free(item);
        }
    }

    var current: []u8 = &.{};
    defer std.heap.page_allocator.free(current);

    // let the X server know what events we wanna be notified about, selection change key press etc
    _ = c.XSelectInput(display, window, c.PropertyChangeMask | c.StructureNotifyMask | c.KeyPressMask);

    // to get global key input we're gonna use GrabKey to indicate which *specific* key event we want to be notified about
    // we want to be notified of this everywhere on the system, so we use the root window here
    //const root = c.DefaultRootWindow(display);

    //_ = c.XGrabKey(
    //    display,
    //    c.XKeysymToKeycode(display, c.XStringToKeysym("p")),
    //    c.ControlMask,
    //    root,
    //    0,
    //    c.GrabModeAsync,
    //    c.GrabModeAsync,
    //);
    //
    //this consumes the key press from any other app so im gonna comment out till im actually using it

    // var winShown: bool = false;

    var event: c.XEvent = undefined;
    std.debug.print("Inshallah we find this event...\n", .{});
    while (true) {
        glfw.pollEvents();

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0, 0, 0, 1.0 });

        const fb_size = glfw_window.getFramebufferSize();

        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        // map out the window
        if (zgui.begin("clipboard", .{ .flags = .{
            .always_auto_resize = true,
            .no_move = true,
            .no_resize = true,
            .no_title_bar = true,
        } })) {
            for (clipboardHistory.items, 0..) |item, i| {
                // map out each item :3
                const s = try std.heap.page_allocator.dupeZ(u8, item[0..item.len]);
                if (zgui.button(s, .{ .w = 380 })) {
                    glfw_window.setClipboardString(s);
                    if (!std.mem.eql(u8, item, current)) {
                        _ = clipboardHistory.orderedRemove(i);
                        break;
                    }
                }
                zgui.spacing();
            }
        }

        zgui.end();
        zgui.backend.draw();
        glfw_window.swapBuffers();

        _ = c.XConvertSelection(display, clipboardAtom, target_atom, property_atom, window, c.CurrentTime);
        _ = c.XNextEvent(display, &event);
        switch (event.type) {
            c.KeyPress => {
                //add hiding functionality here :3
            },
            c.SelectionNotify => {
                const sel = @field(event, "xselection");

                if (sel.property == property_atom) {
                    var actual_type: c.Atom = undefined;
                    var actual_format: c_int = undefined;
                    var nitems: c.ulong = 0;
                    var bytes_after: c.ulong = 0;
                    var prop: [*c]u8 = undefined;

                    //ask X server for the selection
                    _ = c.XGetWindowProperty(display, window, property_atom, 0, 1024, 0, c.AnyPropertyType, &actual_type, &actual_format, &nitems, &bytes_after, &prop);

                    //convert convert
                    const propC = std.mem.span(prop);
                    // check if we're looking at dupes, since we're asking for the content so much, then add to history etc
                    if (!std.mem.eql(u8, propC, current)) {
                        _ = std.heap.page_allocator.free(current);
                        try clipboardHistory.append(try std.heap.page_allocator.dupe(u8, propC));
                        current = try std.heap.page_allocator.dupe(u8, propC);
                    }

                    defer std.c.free(prop);
                }
            },

            else => {},
        }
        // 1000 nanoseconds seems to work fine for me but change this to whatever u want if its bugging out
        std.time.sleep(1000);
    }
}
