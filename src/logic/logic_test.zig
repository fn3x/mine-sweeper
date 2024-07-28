const std = @import("std");
const expect = @import("std").testing.expect;

const State = @import("logic.zig").State;

test "should create state for size=10" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 5;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    try expect(state.fields.len == field_size * field_size);
}

test "should place 5 bombs" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 5;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    try expect(state.fields.len == field_size * field_size);

    try state.placeBombs(5);
    var bombs: usize = 0;
    for (state.fields) |field| {
        if (field.is_bomb) {
            bombs += 1;
        }
    }

    try expect(state.placedBombs == true);
    try expect(bombs == 5);
}

test "should correctly tag fields surrounded with 1 bomb at center" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const bomb_pos: usize = 4;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    try state.placeBomb(bomb_pos);

    for (state.fields, 0..) |field, i| {
        if (i == bomb_pos) {
            try expect(field.is_bomb);
            continue;
        }

        try expect(!field.is_bomb);
        try expect(field.surrounded_with == 1);
    }
}

test "should correctly tag fields surrounded with 1 bomb at center and 1 bomb in corner" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const bomb1_pos: usize = 4;
    const bomb2_pos: usize = 8;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    try state.placeBomb(bomb1_pos);
    try state.placeBomb(bomb2_pos);

    for (state.fields, 0..) |field, i| {
        switch (i) {
            bomb1_pos => try expect(field.is_bomb),
            bomb2_pos => try expect(field.is_bomb),
            5 => try expect(field.surrounded_with == 2),
            7 => try expect(field.surrounded_with == 2),
            else => try expect(field.surrounded_with == 1),
        }
    }
}

test "should not increase surrounded for fields if bomb is placed in the same field" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const bomb_pos: usize = 4;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    // placing bombs in the same field
    try state.placeBomb(bomb_pos);
    try state.placeBomb(bomb_pos);
    try state.placeBomb(bomb_pos);
    try state.placeBomb(bomb_pos);
    try state.placeBomb(bomb_pos);

    for (state.fields, 0..) |field, i| {
        if (i == bomb_pos) {
            try expect(field.is_bomb);
            continue;
        }

        try expect(!field.is_bomb);
        try expect(field.surrounded_with == 1);
    }
}

test "should reset the board" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const bomb_pos: usize = 4;

    var state = try State.init(allocator, field_size);
    defer state.deinit(allocator);

    try state.placeBomb(bomb_pos);
    state.resetBoard();

    for (state.fields) |field| {
        try expect(!field.is_bomb);
        try expect(field.surrounded_with == 0);
    }

    try expect(!state.placedBombs);
}
