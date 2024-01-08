//! KDL grammar lexer
const std = @import("std");

pub const Token = union(enum) {
    ident: []const u8,
    // num: []const u8,

    // Special tokens
    equals,
    semicolon,
    lcurly,
    rcurly,
    lparen,
    rparen,
    backslash,

    // Bad things
    illegal, // In case something is invalid or a keyword.
};

pub const Lexer = struct {
    read_position: usize = 0,
    position: usize = 0,
    current_char: u8,
    input: []const u8,

    const Self = @This();

    pub fn init(input: []const u8) Self {
        return .{
            .input = input,
            .current_char = input[0],
        };
    }

    fn skipWhitespace(self: *Self) void {
        while (std.ascii.isWhitespace(self.current_char)) {
            self.advanceChar();
        }
    }

    fn peek(self: Self) u8 {
        if (self.read_position >= self.query.len)
            return 0;

        return self.query[self.read_position];
    }

    fn advanceChar(self: *Self) void {
        if (self.read_position >= self.input.len) {
            self.current_char = 0;
        } else {
            self.current_char = self.input[self.read_position];
        }

        self.position = self.read_position;
        self.read_position += 1;
    }

    /// Scan forward until we can no longer build a word out of alphanumeric characters.
    fn buildWord(self: *Self) []const u8 {
        const start_position = self.position;
        while (std.ascii.isAlphanumeric(self.current_char)) {
            self.advanceChar();
        }

        return self.input[start_position..self.position];
    }

    fn buildNumber(self: *Self) []const u8 {
        const start_position = self.position;

        while (std.ascii.isDigit(self.current_char)) {
            self.advanceChar();
        }

        return self.input[start_position..self.position];
    }

    pub fn nextToken(self: *Self) ?Token {
        self.skipWhitespace();

        const token: ?Token = switch (self.current_char) {
            'a'...'z', 'A'...'Z', '0'...'9' => return .{ .ident = self.buildWord() },
            '=' => .equals,
            ';' => .semicolon,
            '{' => .lcurly,
            '}' => .rcurly,
            '(' => .lparen,
            ')' => .rparen,
            '\\' => .backslash,
            else => null,
        };
        self.advanceChar();

        return token;
    }

    pub fn collectAllAlloc(self: *Self, allocator: std.mem.Allocator) ![]Token {
        var tokens = std.ArrayList(Token).init(allocator);

        while (self.nextToken()) |token| {
            try tokens.append(token);
        }

        return tokens.toOwnedSlice();
    }
};

test "Parsing a simple input" {
    const input = "node abc123";

    var l = Lexer.init(input);
    const expected = [_]Token{
        .{ .ident = "node" },
        .{ .ident = "abc123" },
    };

    const actual = try l.collectAllAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);

    for (expected, actual) |e, a|
        try std.testing.expectEqualDeep(e, a);
}

test "Parsing with a type" {
    const input = "person (u8)age=5";

    const expected = [_]Token{
        .{ .ident = "person" },
        .lparen,
        .{ .ident = "u8" },
        .rparen,
        .{ .ident = "age" },
        .equals,
        .{ .ident = "5" },
    };

    var lexer = Lexer.init(input);
    const actual = try lexer.collectAllAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);

    for (expected, actual) |e, a|
        try std.testing.expectEqualDeep(e, a);
}

test "Multiline node" {
    const input =
        \\ numbers 5 6 \
        \\         7 8
    ;
    var lexer = Lexer.init(input);
    const actual = try lexer.collectAllAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);

    const expected = [_]Token{
        .{ .ident = "numbers" },
        .{ .ident = "5" },
        .{ .ident = "6" },
        .backslash,
        .{ .ident = "7" },
        .{ .ident = "8" },
    };

    for (expected, actual) |e, a|
        try std.testing.expectEqualDeep(e, a);
}
test "Multiple multiline nodes" {
    const input =
        \\ numbers 5 6 \
        \\         7 8
        \\ letters a b \
        \\         c d ;
    ;
    const expected = [_]Token{
        .{ .ident = "numbers" },
        .{ .ident = "5" },
        .{ .ident = "6" },
        .backslash,
        .{ .ident = "7" },
        .{ .ident = "8" },
        .{ .ident = "letters" },
        .{ .ident = "a" },
        .{ .ident = "b" },
        .backslash,
        .{ .ident = "c" },
        .{ .ident = "d" },
        .semicolon, // Just to check it.
    };

    var lexer = Lexer.init(input);
    const actual = try lexer.collectAllAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);

    for (expected, actual) |e, a|
        try std.testing.expectEqualDeep(e, a);
}
