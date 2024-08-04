const std = @import("std");
const State = @import("logic/state.zig").State;
const SDL2 = @cImport({
    @cInclude("SDL.h");
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const size = 3;
    const mines = 1;

    var state = try State.init(allocator, size, mines);
    defer state.deinit(allocator);

    var window_width: usize = 800;
    var window_height: usize = 400;

    const window = SDL2.SDL_CreateWindow("Simple", 0, 0, @intCast(window_width), @intCast(window_height), 0);
    defer SDL2.SDL_DestroyWindow(window);

    const clicked = 4;

    _ = state.visitField(clicked);

    const renderer = SDL2.SDL_CreateRenderer(window, 0, SDL2.SDL_RENDERER_PRESENTVSYNC);
    defer SDL2.SDL_DestroyRenderer(renderer);

    var sdl_event: SDL2.SDL_Event = undefined;

    var rects = try allocator.alloc(SDL2.SDL_Rect, size * size);
    defer allocator.free(rects);

    const shift_y = 25;
    const shift_x = 25;
    const field_size = 20;

    var center_x: usize = window_width / 2;
    var center_y: usize = window_height / 2;

    for (0..rects.len) |i| {
        rects[i].h = field_size;
        rects[i].w = field_size;

        if (i == 0) {
            rects[i].x = @intCast(center_x);
            rects[i].y = @intCast(center_y);
        } else if (i % size == 0) {
            rects[i].x = shift_x;
            rects[i].y = rects[i - 1].y + @as(c_int, shift_y);
        } else {
            rects[i].x = rects[i - 1].x + @as(c_int, shift_x);
            rects[i].y = rects[i - 1].y;
        }
    }

    for (rects) |*rect| {
        rect.*.x += @intCast(window_width / 2 - shift_x);
        rect.*.y += @intCast(window_height / 2 - shift_y);
    }

    main_loop: while (true) {
        while (SDL2.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL2.SDL_QUIT => break :main_loop,
                SDL2.SDL_KEYDOWN => {
                    if (sdl_event.key.keysym.sym == SDL2.SDLK_ESCAPE) {
                        break :main_loop;
                    }
                },
                else => {},
            }
            switch (sdl_event.window.event) {
                SDL2.SDL_WINDOWEVENT_RESIZED => {
                    SDL2.SDL_GetWindowSize(window, @as([*]c_int, @ptrCast(&window_width)), @as([*]c_int, @ptrCast(&window_height)));
                    center_x = window_width / 2;
                    center_y = window_height / 2;
                },
                else => {},
            }
        }

        _ = SDL2.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        _ = SDL2.SDL_RenderClear(renderer);

        _ = SDL2.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);

        for (rects) |*rect| {
            rect.*.x += @intCast(window_width / 2 - shift_x);
            rect.*.y += @intCast(window_height / 2 - shift_y);
            _ = SDL2.SDL_RenderFillRect(renderer, rect);
        }

        SDL2.SDL_RenderPresent(renderer);
    }
}
