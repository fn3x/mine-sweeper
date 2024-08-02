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

    const window = SDL2.SDL_CreateWindow("Simple", 0, 0, 400, 400, 0);
    defer SDL2.SDL_DestroyWindow(window);

    const clicked = 4;

    _ = state.visitField(clicked);

    const renderer = SDL2.SDL_CreateRenderer(window, 0, SDL2.SDL_RENDERER_PRESENTVSYNC);
    defer SDL2.SDL_DestroyRenderer(renderer);

    // const surface = SDL2.SDL_GetWindowSurface(window);

    var sdl_event: SDL2.SDL_Event = undefined;
    var rects = try allocator.alloc(SDL2.SDL_Rect, size * size);
    defer allocator.free(rects);

    const shift_y = 25;
    const shift_x = 25;
    const field_size = 20;

    inline for (0..size * size) |i| {
        rects[i].h = field_size;
        rects[i].w = field_size;

        if (i == 0) {
            rects[i].x = shift_x;
            rects[i].y = shift_y;
        } else if (i % size == 0) {
            rects[i].x = shift_x;
            rects[i].y = rects[i - 1].y + shift_y;
        } else {
            rects[i].x = rects[i - 1].x + shift_x;
            rects[i].y = rects[i - 1].y;
        }
    }

    for (0..size * size) |i| {
        std.log.info("{any}\n", .{rects[i]});
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
        }

        _ = SDL2.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        _ = SDL2.SDL_RenderClear(renderer);

        _ = SDL2.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);

        for (rects) |rect| {
            _ = SDL2.SDL_RenderFillRect(renderer, &rect);
        }

        SDL2.SDL_RenderPresent(renderer);
    }
}
