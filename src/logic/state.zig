const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const InitErrors = error{ OutOfMemory, TooSmallBoard, TooBigBoard, TooManyMines, TooSmallMaxMines };
const GameErrors = error{ MaxMinesReached, NoMines };

pub const Visit = enum { Revealed, Exploded };

const State = enum { Init, Playing, Result };
const Result = enum { Won, Lost, NoResult };

const rand = std.crypto.random;

const Field = struct {
    surrounded_with: usize = 0,
    is_revealed: bool = false,
    is_mine: bool = false,
    has_flag: bool = false,
};

pub const Logic = struct {
    all_fields: []Field,
    state: State,
    result: Result,
    revealed_ids: std.ArrayList(usize),
    max_mines: usize = 0,
    placed_mines: usize = 0,
    turn: usize = 0,

    pub fn init(allocator: std.mem.Allocator, board_size: usize, max_mines: usize) InitErrors!Logic {
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
        const revealed_ids = std.ArrayList(usize).init(allocator);

        for (0..fields.len) |i| {
            fields[i].is_revealed = false;
            fields[i].is_mine = false;
            fields[i].has_flag = false;
            fields[i].surrounded_with = 0;
        }

        return .{ .state = .Init, .result = .NoResult, .all_fields = fields, .max_mines = max_mines, .placed_mines = 0, .turn = 0, .revealed_ids = revealed_ids };
    }

    pub fn deinit(self: *Logic, allocator: std.mem.Allocator) void {
        allocator.free(self.all_fields);
        self.revealed_ids.deinit();
    }

    pub fn reset(self: *Logic) void {
        for (0..self.all_fields.len) |i| {
            self.all_fields[i].is_revealed = false;
            self.all_fields[i].is_mine = false;
            self.all_fields[i].surrounded_with = 0;
        }

        self.placed_mines = 0;
        self.state = .Init;
        self.result = .NoResult;
        self.revealed_ids.clearRetainingCapacity();
    }

    pub fn print(self: *Logic) void {
        std.log.info("Game state={any}\n", .{self.state});
        std.log.info("Game result={any}\n", .{self.result});
        std.log.info("Revealed ids={any}\n", .{self.revealed_ids.items});

        for (0..self.all_fields.len) |i| {
            std.log.info("Field={d} is_bomb={} revealed={} surrounded_with={}\n", .{ i, self.all_fields[i].is_mine, self.all_fields[i].is_revealed, self.all_fields[i].surrounded_with });
        }
    }

    // pub for tests
    pub fn placeMine(self: *Logic, x: usize) GameErrors!void {
        assert(x < self.all_fields.len);

        if (self.placed_mines >= self.max_mines) {
            return GameErrors.MaxMinesReached;
        }

        if (self.all_fields[x].is_mine) {
            return;
        }

        const n: usize = std.math.sqrt(self.all_fields.len);
        self.all_fields[x].surrounded_with = 0;
        self.all_fields[x].is_mine = true;
        self.placed_mines += 1;

        // check for upper left corner
        if (x >= n + 1 and !isLeft(x, n) and !isUp(x, n) and !self.all_fields[x - n - 1].is_mine) {
            self.all_fields[x - n - 1].surrounded_with += 1;
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.all_fields[x - n].is_mine) {
            self.all_fields[x - n].surrounded_with += 1;
        }

        // check for upper right corner
        if (x >= n - 1 and (x + 1 - n) < self.all_fields.len and !isRight(x, n) and !isUp(x, n) and !self.all_fields[x - n + 1].is_mine) {
            self.all_fields[x + 1 - n].surrounded_with += 1;
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.all_fields[x - 1].is_mine) {
            self.all_fields[x - 1].surrounded_with += 1;
        }

        // check for right
        if (x + 1 < self.all_fields.len and !isRight(x, n) and !self.all_fields[x + 1].is_mine) {
            self.all_fields[x + 1].surrounded_with += 1;
        }

        // check for lower left corner
        if (x + n - 1 < self.all_fields.len and !isDown(x, n) and !isLeft(x, n) and !self.all_fields[x + n - 1].is_mine) {
            self.all_fields[x + n - 1].surrounded_with += 1;
        }

        // check for lower
        if (x + n < self.all_fields.len and !isDown(x, n) and !self.all_fields[x + n].is_mine) {
            self.all_fields[x + n].surrounded_with += 1;
        }

        // check for lower right corner
        if (x + n + 1 < self.all_fields.len and !isDown(x, n) and !isRight(x, n) and !self.all_fields[x + n + 1].is_mine) {
            self.all_fields[x + n + 1].surrounded_with += 1;
        }
    }

    fn placeMines(self: *Logic, first: usize) GameErrors!void {
        var mine_pos: usize = rand.uintLessThan(usize, self.all_fields.len);
        while (self.placed_mines < self.max_mines) : (mine_pos = rand.uintLessThan(usize, self.all_fields.len)) {
            if (mine_pos == first) {
                continue;
            }

            try self.placeMine(mine_pos);
        }
    }

    pub fn visitField(self: *Logic, x: usize) !?Visit {
        assert(x >= 0 and x < self.all_fields.len);

        if (self.state == .Result) {
            return Visit.Revealed;
        }

        defer self.turn += 1;

        if (self.turn == 0 and self.placed_mines == 0) {
            self.placeMines(x) catch |err| {
                std.log.err("Could not place mines on first turn {any}", .{err});
                return null;
            };
        }

        if (self.all_fields[x].is_mine and self.turn > 0) {
            self.state = .Result;
            self.result = .Lost;
            return Visit.Exploded;
        }

        if (self.all_fields[x].is_revealed) {
            return Visit.Revealed;
        }

        self.revealAdjacent(x) catch @panic("error on revealing adjacent");

        return Visit.Revealed;
    }

    fn revealAdjacent(self: *Logic, x: usize) !void {
        assert(x >= 0 and x < self.all_fields.len);

        if (self.all_fields[x].is_mine) {
            return;
        }

        if (self.all_fields[x].is_revealed) {
            return;
        }

        self.all_fields[x].is_revealed = true;

        try self.revealed_ids.append(x);

        if (self.all_fields[x].surrounded_with > 0) {
            return;
        }

        const n: usize = std.math.sqrt(self.all_fields.len);

        // check for upper left corner
        if (x >= n + 1 and !isUp(x, n) and !isLeft(x, n) and !self.all_fields[x - n - 1].is_mine) {
            try self.revealAdjacent(x - n - 1);
        }

        // check for upper
        if (x >= n and !isUp(x, n) and !self.all_fields[x - n].is_mine) {
            try self.revealAdjacent(x - n);
        }

        // check for upper right corner
        if (x >= n - 1 and (x + 1 - n) < self.all_fields.len and !isUp(x, n) and !isRight(x, n) and !self.all_fields[x + 1 - n].is_mine) {
            try self.revealAdjacent(x + 1 - n);
        }

        // check for left
        if (x >= 1 and !isLeft(x, n) and !self.all_fields[x - 1].is_mine) {
            try self.revealAdjacent(x - 1);
        }

        // check for right
        if (x + 1 < self.all_fields.len and !isRight(x, n) and !self.all_fields[x + 1].is_mine) {
            try self.revealAdjacent(x + 1);
        }

        // check for lower left corner
        if (x + n - 1 < self.all_fields.len and !isDown(x, n) and !isLeft(x, n) and !self.all_fields[x + n - 1].is_mine) {
            try self.revealAdjacent(x + n - 1);
        }

        // check for lower
        if (x + n < self.all_fields.len and !isDown(x, n) and !self.all_fields[x + n].is_mine) {
            try self.revealAdjacent(x + n);
        }

        // check for lower right corner
        if (x + n + 1 < self.all_fields.len and !isDown(x, n) and !isRight(x, n) and !self.all_fields[x + n + 1].is_mine) {
            try self.revealAdjacent(x + n + 1);
        }
    }

    pub fn setFlag(self: *Logic, x: usize) void {
        assert(x >= 0 and x < self.all_fields.len);
        self.all_fields[x].has_flag = !self.all_fields[x].has_flag;
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
