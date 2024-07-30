const std = @import("std");
const expect = @import("std").testing.expect;

const State = @import("state.zig").State;
const Visit = @import("state.zig").Visit;

test "should create state for size=10" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 5;
    const max_mines: usize = 1;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try expect(state.fields.len == field_size * field_size);
}

test "should place 5 mines" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 5;
    const max_mines: usize = 5;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try expect(state.max_mines == max_mines);
    try expect(state.fields.len == field_size * field_size);

    try state.placeMine(0);
    try state.placeMine(5);
    try state.placeMine(10);
    try state.placeMine(15);
    try state.placeMine(20);

    try expect(state.placed_mines == max_mines);
}

test "should correctly tag fields surrounded with 1 mine at center" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const max_mines: usize = 1;
    const mine_pos: usize = 4;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try state.placeMine(mine_pos);

    for (state.fields, 0..) |field, i| {
        if (i == mine_pos) {
            try expect(field.is_mine);
            continue;
        }

        try expect(!field.is_mine);
        try expect(field.surrounded_with == 1);
    }
}

test "should correctly tag fields surrounded with 1 mine at center and 1 mine in corner" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const max_mines: usize = 2;
    const mine1_pos: usize = 4;
    const mine2_pos: usize = 8;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try state.placeMine(mine1_pos);
    try state.placeMine(mine2_pos);

    for (state.fields, 0..) |field, i| {
        switch (i) {
            mine1_pos => try expect(field.is_mine),
            mine2_pos => try expect(field.is_mine),
            5 => try expect(field.surrounded_with == 2),
            7 => try expect(field.surrounded_with == 2),
            else => try expect(field.surrounded_with == 1),
        }
    }
}

// test "should not increase surrounded for fields if mine is placed in the same field" {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//
//     const allocator = arena.allocator();
//     const field_size: usize = 3;
//     const max_mines: usize = 1;
//     const mine_pos: usize = 4;
//
//     var state = try State.init(allocator, field_size, max_mines);
//     defer state.deinit(allocator);
//
//     // placing bombs in the same field
//     try state.placeMine(mine_pos);
//     try state.placeMine(mine_pos);
//     try state.placeMine(mine_pos);
//     try state.placeMine(mine_pos);
//     try state.placeMine(mine_pos);
//
//     for (state.fields, 0..) |field, i| {
//         if (i == mine_pos) {
//             try expect(field.is_mine);
//             continue;
//         }
//
//         try expect(!field.is_mine);
//         try expect(field.surrounded_with == 1);
//     }
// }

test "should reset the board" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const mine_pos: usize = 4;
    const max_mines: usize = 1;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try state.placeMine(mine_pos);
    state.reset();

    for (state.fields) |field| {
        try expect(!field.is_mine);
        try expect(field.surrounded_with == 0);
    }

    try expect(state.placed_mines == 0);
}

test "should visit field and reveal adjacent fields" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const field_size: usize = 3;
    const mine_pos: usize = 1;
    const max_mines: usize = 1;

    var state = try State.init(allocator, field_size, max_mines);
    defer state.deinit(allocator);

    try state.placeMine(mine_pos);
    const visit = state.visitField(8);

    try expect(visit == Visit.Revealed);

    for (state.fields, 0..) |field, i| {
        switch (i) {
            1 => try expect(field.is_mine),
            0, 2 => {
                try expect(!field.is_revealed);
                try expect(field.surrounded_with == 1);
            },
            3, 4, 5 => {
                try expect(field.is_revealed);
                try expect(field.surrounded_with == 1);
            },
            else => {
                try expect(field.is_revealed);
                try expect(field.surrounded_with == 0);
            },
        }
    }
}
