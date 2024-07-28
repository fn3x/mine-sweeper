const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const InitErrors = error{ OutOfMemory, TooSmallBoard };
const GameErrors = error{TooManyBombs};

const Field = struct {
    surrounded_with: u16,
    is_revealed: bool,
    is_mine: bool,
    has_flag: bool,
};

pub const State = struct {
    fields: []Field,

    pub fn init(allocator: std.mem.Allocator, board_size: u8) InitErrors!State {
        if (board_size < 3) {
            return InitErrors.TooSmallBoard;
        }

        const fields = try allocator.alloc(Field, board_size * board_size);
        for (0..fields.len) |i| {
            fields[i].is_revealed = false;
            fields[i].is_mine = false;
            fields[i].has_flag = false;
            fields[i].surrounded_with = 0;
        }

        return .{ .fields = fields };
    }

    pub fn resetBoard(self: *State) void {
        for (0..self.fields.len) |i| {
            self.fields[i].is_revealed = false;
            self.fields[i].is_mine = false;
            self.fields[i].surrounded_with = 0;
        }
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
    }

    pub fn print(self: *State) void {
        for (0..self.fields.len) |i| {
            std.log.info("Field={d} is_bomb={} revealed={} surrounded_with={}; ", .{ i, self.fields[i].is_mine, self.fields[i].is_revealed, self.fields[i].surrounded_with });
        }
    }

    pub fn placeMines(self: *State, mines: u8) GameErrors!void {
        if ((mines / self.fields.len) > 25) {
            return GameErrors.TooManyBombs;
        }

        var i: usize = 0;
        var placedMines: u8 = 0;
        while (i < self.fields.len and placedMines < mines) : (i += 5) {
            placedMines += 1;
            try self.placeMine(i);
        }
    }

    pub fn placeMine(self: *State, x: usize) GameErrors!void {
        assert(x <= self.fields.len);
        if (self.fields[x].is_mine) {
            return;
        }

        const n: usize = std.math.sqrt(self.fields.len);
        self.fields[x].surrounded_with = 0;
        self.fields[x].is_mine = true;

        // check for upper left corner
        if (x >= n + 1 and !isLeft(x, n) and !isUp(x, n) and !self.fields[x - n - 1].is_mine) {
            self.fields[x - n - 1].surrounded_with += 1;
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.fields[x - n].is_mine) {
            self.fields[x - n].surrounded_with += 1;
        }

        // check for upper right corner
        if (x >= n - 1 and (x - n + 1) < self.fields.len and !isRight(x, n) and !isUp(x, n) and !self.fields[x - n + 1].is_mine) {
            self.fields[x - n + 1].surrounded_with += 1;
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.fields[x - 1].is_mine) {
            self.fields[x - 1].surrounded_with += 1;
        }

        // check for right
        if (x + 1 < self.fields.len and !isRight(x, n) and !self.fields[x + 1].is_mine) {
            self.fields[x + 1].surrounded_with += 1;
        }

        // check for lower left corner
        if (x + n - 1 < self.fields.len and !isDown(x, n) and !isLeft(x, n) and !self.fields[x + n - 1].is_mine) {
            self.fields[x + n - 1].surrounded_with += 1;
        }

        // check for lower
        if (x + n < self.fields.len and !isDown(x, n) and !self.fields[x + n].is_mine) {
            self.fields[x + n].surrounded_with += 1;
        }

        // check for lower right corner
        if (x + n + 1 < self.fields.len and !isDown(x, n) and !isRight(x, n) and !self.fields[x + n + 1].is_mine) {
            self.fields[x + n + 1].surrounded_with += 1;
        }
    }

    pub fn visitField(self: *State, x: u16) Field {
        assert(x >= 0 and x < self.fields.len);

        if (self.fields[x].is_mine) {
            return self.fields[x];
        }

        const n: usize = std.math.sqrt(self.fields.len);

        // check for upper left corner
        if (x >= n + 1 and !isLeft(x, n) and !isUp(x, n) and !self.fields[x - n - 1].is_mine) {
            self.fields[x - n - 1].surrounded_with += 1;
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.fields[x - n].is_mine) {
            self.fields[x - n].surrounded_with += 1;
        }

        // check for upper right corner
        if (x >= n - 1 and (x - n + 1) < self.fields.len and !isRight(x, n) and !isUp(x, n) and !self.fields[x - n + 1].is_mine) {
            self.fields[x - n + 1].surrounded_with += 1;
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.fields[x - 1].is_mine) {
            self.fields[x - 1].surrounded_with += 1;
        }

        // check for right
        if (x + 1 < self.fields.len and !isRight(x, n) and !self.fields[x + 1].is_mine) {
            self.fields[x + 1].surrounded_with += 1;
        }

        // check for lower left corner
        if (x + n - 1 < self.fields.len and !isDown(x, n) and !isLeft(x, n) and !self.fields[x + n - 1].is_mine) {
            self.fields[x + n - 1].surrounded_with += 1;
        }

        // check for lower
        if (x + n < self.fields.len and !isDown(x, n) and !self.fields[x + n].is_mine) {
            self.fields[x + n].surrounded_with += 1;
        }

        // check for lower right corner
        if (x + n + 1 < self.fields.len and !isDown(x, n) and !isRight(x, n) and !self.fields[x + n + 1].is_mine) {
            self.fields[x + n + 1].surrounded_with += 1;
        }
        return self.fields[x];
    }

    pub fn revealAdjacent(self: *State, x: u16) []Field {
        assert(x >= 0 and x < self.fields.len);

        const field = self.fields[x];

        if (field.is_mine) {
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
