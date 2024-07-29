const std = @import("std");
const State = @import("logic/state.zig").State;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state = try State.init(allocator, @as(u8, 5));
    defer state.deinit(allocator);
    try state.placeMine(@as(u8, 1));
    state.print();
    const clicked = 8;
    const visit = state.visitField(clicked);
    std.log.info("Visit at {d}: {}", .{ clicked, visit });
    state.print();
}
