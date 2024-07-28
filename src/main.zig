const std = @import("std");
const State = @import("logic/logic.zig").State;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state = try State.init(allocator, @as(u8, 10));
    defer state.deinit(allocator);
    try state.placeMines(@as(u8, 5));
    state.print();
}
