const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const InitErrors = error{ OutOfMemory, TooSmallBoard };
const GameErrors = error{TooManyBombs};

const Field = struct {
    surrounded_with: u16,
    revealed: bool,
    is_bomb: bool,
};

pub const State = struct {
    fields: []Field,
    placedBombs: bool,

    pub fn init(allocator: std.mem.Allocator, board_size: u8) InitErrors!State {
        if (board_size < 3) {
            return InitErrors.TooSmallBoard;
        }

        const fields = try allocator.alloc(Field, board_size * board_size);
        for (0..fields.len) |i| {
            fields[i].revealed = false;
            fields[i].is_bomb = false;
            fields[i].surrounded_with = 0;
        }

        return .{ .fields = fields, .placedBombs = false };
    }

    pub fn resetBoard(self: *State) void {
        for (0..self.fields.len) |i| {
            self.fields[i].revealed = false;
            self.fields[i].is_bomb = false;
            self.fields[i].surrounded_with = 0;
        }

        self.placedBombs = false;
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
    }

    pub fn print(self: *State) void {
        for (0..self.fields.len) |i| {
            std.log.info("Field={d} is_bomb={} revealed={} surrounded_with={}; ", .{ i, self.fields[i].is_bomb, self.fields[i].revealed, self.fields[i].surrounded_with });
        }
    }

    pub fn placeBombs(self: *State, bombs: u8) GameErrors!void {
        if ((bombs / self.fields.len) > 25) {
            return GameErrors.TooManyBombs;
        }

        self.placedBombs = true;

        var i: usize = 0;
        var placedBombs: u8 = 0;
        while (i < self.fields.len and placedBombs < bombs) : (i += 5) {
            placedBombs += 1;
            try self.placeBomb(i);
        }
    }

    pub fn placeBomb(self: *State, x: usize) GameErrors!void {
        assert(x <= self.fields.len);
        if (self.fields[x].is_bomb) {
            return;
        }

        const n: usize = std.math.sqrt(self.fields.len);
        self.fields[x].surrounded_with = 0;
        self.fields[x].is_bomb = true;

        // check for upper left corner
        if (x >= n + 1 and !isLeft(x, n) and !isUp(x, n) and !self.fields[x - n - 1].is_bomb) {
            self.fields[x - n - 1].surrounded_with += 1;
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.fields[x - n].is_bomb) {
            self.fields[x - n].surrounded_with += 1;
        }

        // check for upper right corner
        if (x >= n - 1 and (x - n + 1) < self.fields.len and !isRight(x, n) and !isUp(x, n) and !self.fields[x - n + 1].is_bomb) {
            self.fields[x - n + 1].surrounded_with += 1;
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.fields[x - 1].is_bomb) {
            self.fields[x - 1].surrounded_with += 1;
        }

        // check for right
        if (x + 1 < self.fields.len and !isRight(x, n) and !self.fields[x + 1].is_bomb) {
            self.fields[x + 1].surrounded_with += 1;
        }

        // check for lower left corner
        if (x + n - 1 < self.fields.len and !isDown(x, n) and !isLeft(x, n) and !self.fields[x + n - 1].is_bomb) {
            self.fields[x + n - 1].surrounded_with += 1;
        }

        // check for lower
        if (x + n < self.fields.len and !isDown(x, n) and !self.fields[x + n].is_bomb) {
            self.fields[x + n].surrounded_with += 1;
        }

        // check for lower right corner
        if (x + n + 1 < self.fields.len and !isDown(x, n) and !isRight(x, n) and !self.fields[x + n + 1].is_bomb) {
            self.fields[x + n + 1].surrounded_with += 1;
        }
    }

    pub fn visitField(self: *State, x: u16) Field {
        assert(x >= 0 and x < self.fields.len);
        return self.fields[x];
    }

    pub fn revealAdjacent(self: *State, x: u16) []Field {
        assert(x >= 0 and x < self.fields.len);

        const field = self.fields[x];

        if (field.is_bomb) {
            return .{field};
        }
    }
};

fn isLeft(x: usize, n: usize) bool {
    return x % n == 0;
}

fn isRight(x: usize, n: usize) bool {
    return (x + 1) % n == 0;
}

fn isUp(x: usize, n: usize) bool {
    return x < n;
}

fn isDown(x: usize, n: usize) bool {
    return std.math.pow(usize, n, 2) - x <= n;
}
