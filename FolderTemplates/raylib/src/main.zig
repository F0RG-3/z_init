const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");


pub fn main() !void {

    rl.setTraceLogLevel(.none);
    rl.initWindow(700, 400, "Window Ex.");
    defer rl.closeWindow();
    const bkgrndClr = rl.Color.init(10, 10, 10, 255);

    while (!rl.windowShouldClose()) {

        rl.beginDrawing();
        rl.clearBackground(bkgrndClr);
        rl.endDrawing();
    }
}
