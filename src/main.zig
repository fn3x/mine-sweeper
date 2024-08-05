const std = @import("std");
const State = @import("logic/state.zig").State;
const c = @cImport({
    @cInclude("SDL.h");
});

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const size = 3;
    const mines = 1;

    var state = try State.init(allocator, size, mines);
    defer state.deinit(allocator);

    var window_width: usize = 800;
    var window_height: usize = 400;

    const window = c.SDL_CreateWindow("Simple", 0, 0, @intCast(window_width), @intCast(window_height), 0);
    if (window == null) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyWindow(window);

    const clicked = 4;

    _ = state.visitField(clicked);

    const renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    if (renderer == null) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyRenderer(renderer);

    var sdl_event: c.SDL_Event = undefined;

    var rects = try allocator.alloc(c.SDL_Rect, size * size);
    defer allocator.free(rects);

    const shift_y = 5;
    const shift_x = 5;
    const field_size = 20;

    var center_x: usize = window_width / 2;
    var center_y: usize = window_height / 2;

    for (0..rects.len) |i| {
        rects[i].h = field_size;
        rects[i].w = field_size;

        if (i == 0) {
            rects[i].x = @intCast(center_x - shift_x - field_size - @divFloor(field_size, 2));
            rects[i].y = @intCast(center_y - shift_y - field_size - @divFloor(field_size, 2));
        } else if (i % size == 0) {
            rects[i].x = rects[i - size].x;
            rects[i].y = rects[i - 1].y + @as(c_int, shift_y + field_size);
        } else {
            rects[i].x = rects[i - 1].x + @as(c_int, shift_x + field_size);
            rects[i].y = rects[i - 1].y;
        }
    }

    main_loop: while (true) {
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :main_loop,
                c.SDL_KEYDOWN => {
                    if (sdl_event.key.keysym.sym == c.SDLK_ESCAPE) {
                        break :main_loop;
                    }
                },
                else => {},
            }
            switch (sdl_event.window.event) {
                c.SDL_WINDOWEVENT_RESIZED => {
                    c.SDL_GetWindowSize(window, @as([*]c_int, @ptrCast(&window_width)), @as([*]c_int, @ptrCast(&window_height)));
                    center_x = window_width / 2;
                    center_y = window_height / 2;
                },
                else => {},
            }
        }

        // _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        // _ = c.SDL_RenderClear(renderer);

        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);

        for (rects) |*rect| {
            _ = c.SDL_RenderFillRect(renderer, rect);
        }

        c.SDL_RenderPresent(renderer);
    }
}
