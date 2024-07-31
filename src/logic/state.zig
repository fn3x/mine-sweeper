const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const InitErrors = error{ OutOfMemory, TooSmallBoard, TooBigBoard, TooManyMines, TooSmallMaxMines };
const GameErrors = error{ MaxMinesReached, NoMines };

pub const Visit = enum { Revealed, Exploded };

const rand = std.crypto.random;

const Field = struct {
    surrounded_with: usize = 0,
    is_revealed: bool = false,
    is_mine: bool = false,
    has_flag: bool = false,
};

pub const State = struct {
    fields: []Field,
    max_mines: usize = 0,
    placed_mines: usize = 0,
    turn: usize = 0,

    pub fn init(allocator: std.mem.Allocator, board_size: usize, max_mines: usize) InitErrors!State {
        if (board_size < 3) {
            return InitErrors.TooSmallBoard;
        }

        if (board_size > 256) {
            return InitErrors.TooBigBoard;
        }

        if (max_mines < 0) {
            return InitErrors.TooSmallMaxMines;
        }

        const fields_size: f64 = @floatFromInt(board_size * board_size);
        const max_mines_cast: f64 = @floatFromInt(max_mines);

        if (max_mines_cast / fields_size > 0.25) {
            return InitErrors.TooManyMines;
        }

        const fields = try allocator.alloc(Field, board_size * board_size);
        for (0..fields.len) |i| {
            fields[i].is_revealed = false;
            fields[i].is_mine = false;
            fields[i].has_flag = false;
            fields[i].surrounded_with = 0;
        }

        return .{
            .fields = fields,
            .max_mines = max_mines,
            .placed_mines = 0,
            .turn = 0,
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
    }

    pub fn reset(self: *State) void {
        for (0..self.fields.len) |i| {
            self.fields[i].is_revealed = false;
            self.fields[i].is_mine = false;
            self.fields[i].surrounded_with = 0;
        }

        self.placed_mines = 0;
    }

    pub fn print(self: *State) void {
        for (0..self.fields.len) |i| {
            std.log.info("Field={d} is_bomb={} revealed={} surrounded_with={}", .{ i, self.fields[i].is_mine, self.fields[i].is_revealed, self.fields[i].surrounded_with });
        }
    }

    pub fn placeMine(self: *State, x: usize) GameErrors!void {
        assert(x < self.fields.len);

        if (self.placed_mines >= self.max_mines) {
            return GameErrors.MaxMinesReached;
        }

        if (self.fields[x].is_mine) {
            return;
        }

        const n: usize = std.math.sqrt(self.fields.len);
        self.fields[x].surrounded_with = 0;
        self.fields[x].is_mine = true;
        self.placed_mines += 1;

        // check for upper left corner
        if (x >= n + 1 and !isLeft(x, n) and !isUp(x, n) and !self.fields[x - n - 1].is_mine) {
            self.fields[x - n - 1].surrounded_with += 1;
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.fields[x - n].is_mine) {
            self.fields[x - n].surrounded_with += 1;
        }

        // check for upper right corner
        if (x >= n - 1 and (x + 1 - n) < self.fields.len and !isRight(x, n) and !isUp(x, n) and !self.fields[x - n + 1].is_mine) {
            self.fields[x + 1 - n].surrounded_with += 1;
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

    fn placeMines(self: *State, first: usize) GameErrors!void {
        var mine_pos: usize = rand.uintLessThan(usize, self.fields.len);
        while (self.placed_mines < self.max_mines) : (mine_pos = rand.uintLessThan(usize, self.fields.len)) {
            if (mine_pos == first) {
                continue;
            }

            try self.placeMine(mine_pos);
        }
    }

    pub fn visitField(self: *State, x: usize) ?Visit {
        assert(x >= 0 and x < self.fields.len);

        defer self.turn += 1;

        if (self.turn == 0 and self.placed_mines == 0) {
            self.placeMines(x) catch |err| {
                std.log.err("Could not place mines on first turn {any}", .{err});
                return null;
            };
        }

        if (self.fields[x].is_mine and self.turn > 0) {
            return Visit.Exploded;
        }

        if (self.fields[x].is_revealed) {
            return Visit.Revealed;
        }

        self.revealAdjacent(x);

        return Visit.Revealed;
    }

    pub fn revealAdjacent(self: *State, x: usize) void {
        assert(x >= 0 and x < self.fields.len);

        std.log.debug("visiting field={d}", .{x});

        if (self.fields[x].is_mine) {
            return;
        }

        if (self.fields[x].is_revealed) {
            return;
        }

        self.fields[x].is_revealed = true;

        if (self.fields[x].surrounded_with > 0) {
            return;
        }

        const n: usize = std.math.sqrt(self.fields.len);

        // check for upper left corner
        if (x >= n + 1 and !isUp(x, n) and !isLeft(x, n) and !self.fields[x - n - 1].is_mine) {
            self.revealAdjacent(x - n - 1);
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.fields[x - n].is_mine) {
            self.revealAdjacent(x - n);
        }

        // check for upper right corner
        if (x >= n - 1 and (x + 1 - n) < self.fields.len and !isUp(x, n) and !isRight(x, n) and !self.fields[x + 1 - n].is_mine) {
            self.revealAdjacent(x + 1 - n);
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.fields[x - 1].is_mine) {
            self.revealAdjacent(x - 1);
        }

        // check for right
        if (x + 1 < self.fields.len and !isRight(x, n) and !self.fields[x + 1].is_mine) {
            self.revealAdjacent(x + 1);
        }

        // check for lower left corner
        if (x + n - 1 < self.fields.len and !isDown(x, n) and !isLeft(x, n) and !self.fields[x + n - 1].is_mine) {
            self.revealAdjacent(x + n - 1);
        }

        // check for lower
        if (x + n < self.fields.len and !isDown(x, n) and !self.fields[x + n].is_mine) {
            self.revealAdjacent(x + n);
        }

        // check for lower right corner
        if (x + n + 1 < self.fields.len and !isDown(x, n) and !isRight(x, n) and !self.fields[x + n + 1].is_mine) {
            self.revealAdjacent(x + n + 1);
        }
    }

    pub fn setFlag(self: *State, x: usize) void {
        assert(x >= 0 and x < self.fields.len);
        self.fields[x].has_flag = !self.fields[x].has_flag;
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
