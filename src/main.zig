const std = @import("std");
const Logic = @import("logic/state.zig").Logic;
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const MouseInput = struct { x: f32, y: f32 };

const AppState = struct {
    logic: *Logic,
    board_size: usize,
    rects: []c.SDL_FRect,
    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    center_x: f32,
    center_y: f32,
    field_shift: f32,
    field_size: f32,
    mouse_input: ?MouseInput,
};

var app: AppState = .{
    .field_size = 20.0,
    .board_size = 3.0,
    .rects = undefined,
    .logic = undefined,
    .window = undefined,
    .renderer = undefined,
    .center_x = 0.0,
    .center_y = 0.0,
    .field_shift = 5.0,
    .mouse_input = null,
};

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const mines = 1;

    var state = try Logic.init(allocator, app.board_size, mines);
    defer state.deinit(allocator);

    app.logic = &state;

    var window_width: usize = 800;
    var window_height: usize = 400;

    const window = c.SDL_CreateWindow("Mine Sweeper", @intCast(window_width), @intCast(window_height), 0);
    if (window == null) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyWindow(window);
    app.window = window.?;

    const renderer = c.SDL_CreateRenderer(window, c.SDL_GPU_PRESENTMODE_VSYNC);
    if (renderer == null) {
        std.debug.panic("SDL error: {s}", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyRenderer(renderer);
    app.renderer = renderer.?;

    var sdl_event: c.SDL_Event = undefined;

    const rects = try allocator.alloc(c.SDL_FRect, app.board_size * app.board_size);
    defer allocator.free(rects);
    app.rects = rects;

    app.field_size = 20.0;
    app.field_shift = 5.0;

    app.center_x = @floatFromInt(window_width / 2);
    app.center_y = @floatFromInt(window_height / 2);

    main_loop: while (true) {
        app.mouse_input = null;

        while (c.SDL_PollEvent(&sdl_event)) {
            switch (sdl_event.type) {
                c.SDL_EVENT_QUIT => break :main_loop,
                c.SDL_EVENT_KEY_DOWN => {
                    if (sdl_event.key.key == c.SDLK_ESCAPE) {
                        break :main_loop;
                    }
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    app.mouse_input = .{
                        .x = sdl_event.button.x,
                        .y = sdl_event.button.y,
                    };
                },
                else => {},
            }
            switch (sdl_event.window.type) {
                c.SDL_EVENT_WINDOW_RESIZED => {
                    _ = c.SDL_GetWindowSize(window, @as([*]c_int, @ptrCast(&window_width)), @as([*]c_int, @ptrCast(&window_height)));
                    app.center_x = @floatFromInt(window_width / 2);
                    app.center_y = @floatFromInt(window_height / 2);
                },
                else => {},
            }
        }

        _ = c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0xff, 0xff, 0xff);
        _ = c.SDL_RenderClear(app.renderer);

        updateRects();

        _ = c.SDL_SetRenderScale(app.renderer, 1.0, 1.0);
        _ = c.SDL_RenderPresent(app.renderer);
    }
}

fn isClickedOnField(idx: usize) bool {
    if (app.mouse_input == null) {
        return false;
    }

    if (app.mouse_input.?.x >= app.rects[idx].x and app.mouse_input.?.x <= app.rects[idx].x + app.rects[idx].w and app.mouse_input.?.y >= app.rects[idx].y and app.mouse_input.?.y <= app.rects[idx].y + app.rects[idx].h) {
        return true;
    }

    return false;
}

fn updateRects() void {
    var r: u8 = undefined;
    var g: u8 = undefined;
    var b: u8 = undefined;
    var a: u8 = undefined;

    // save previous draw color
    _ = c.SDL_GetRenderDrawColor(app.renderer, &r, &g, &b, &a);

    _ = c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0, 0, 0xff);

    for (0..app.rects.len) |i| {
        app.rects[i].h = app.field_size;
        app.rects[i].w = app.field_size;

        if (isClickedOnField(i)) {
            _ = try app.logic.visitField(i);

            if (app.logic.state == .Result) {
                app.logic.reset();
                _ = c.SDL_SetRenderDrawColor(app.renderer, r, g, b, a);
            }
        }

        if (i == 0) {
            app.rects[i].x = app.center_x - app.field_shift - app.field_size - (app.field_size / 2);
            app.rects[i].y = app.center_y - app.field_shift - app.field_size - (app.field_size / 2);
        } else if (i % app.board_size == 0) {
            app.rects[i].x = app.rects[i - app.board_size].x;
            app.rects[i].y = app.rects[i - 1].y + app.field_shift + app.field_size;
        } else {
            app.rects[i].x = app.rects[i - 1].x + app.field_shift + app.field_size;
            app.rects[i].y = app.rects[i - 1].y;
        }

        const is_revealed = for (0..app.logic.revealed_ids.items.len) |id| {
            if (app.logic.revealed_ids.items[id] == i) {
                break true;
            }
        } else false;

        if (is_revealed) {
            _ = c.SDL_SetRenderDrawColor(app.renderer, 0, 0xff, 0, 0xff);
        } else if (app.logic.all_fields[i].is_mine) {
            _ = c.SDL_SetRenderDrawColor(app.renderer, 0, 0, 0xff, 0xff);
        } else {
            _ = c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0, 0, 0xff);
        }

        _ = c.SDL_RenderRect(app.renderer, @ptrCast(&app.rects[i]));
    }

    // set draw color back
    _ = c.SDL_SetRenderDrawColor(app.renderer, r, g, b, a);
}

fn resetRects() void {}
