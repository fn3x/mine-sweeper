const std = @import("std");
const State = @import("logic/state.zig").State;
const SDL2 = @cImport({
    @cInclude("SDL.h");
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state = try State.init(allocator, 5, 3);
    defer state.deinit(allocator);

    const window = SDL2.SDL_CreateWindow("Simple", 0, 0, 200, 200, 0);
    defer SDL2.SDL_DestroyWindow(window);

    const clicked = 23;

    const visit = state.visitField(1);
    std.log.info("Visit at {d}: {any}", .{ clicked, visit });
    state.print();

    const renderer = SDL2.SDL_CreateRenderer(window, 0, SDL2.SDL_RENDERER_PRESENTVSYNC);
    defer SDL2.SDL_DestroyRenderer(renderer);

    mainloop: while (true) {
        var sdl_event: SDL2.SDL_Event = undefined;

        while (SDL2.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL2.SDL_QUIT => break :mainloop,
                SDL2.SDL_KEYDOWN => {
                    if (sdl_event.key.keysym.sym == SDL2.SDLK_ESCAPE) {
                        break :mainloop;
                    }
                },
                else => {},
            }
        }

        _ = SDL2.SDL_RenderClear(renderer);

        var rect = SDL2.SDL_Rect{ .x = 0, .y = 0, .w = 60, .h = 60 };

        _ = SDL2.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);

        _ = SDL2.SDL_RenderFillRect(renderer, &rect);

        SDL2.SDL_RenderPresent(renderer);
    }
}
