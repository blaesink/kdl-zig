//! KDL grammar lexer
const std = @import("std");

pub const Token = union(enum) {
    ident: []const u8,

    // Special tokens
    equals,
    lcurly,
    rcurly,
    lparen,
    rparen,
    backslash,

    // "Node terminators"
    semicolon,
    endl, // Note that CRLF is treated as a single newline.
    // eof, // Handled via `null` by the end of the lexing instead.

    // Bad things
    illegal, // In case something is invalid or a keyword.
};

/// A modification of `std.ascii.isWhiteSpace`, just to omit `\r` and `\n`, so that they can be
/// handled separately.
fn isWhitespace(c: u8) bool {
    const whitespace = [_]u8{ ' ', '\t', std.ascii.control_code.vt, std.ascii.control_code.ff };

    return for (whitespace) |other| {
        if (c == other)
            break true;
    } else false;
}

fn isEndLine(c: u8) bool {
    const endline = [_]u8{ std.ascii.control_code.cr, std.ascii.control_code.lf };

    return for (endline) |e| {
        if (c == e)
            break true;
    } else false;
}

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
        while (isWhitespace(self.current_char))
            self.advanceChar();
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

    /// Move forward in the charstream until we're not an endline char.
    fn advanceToNextLine(self: *Self) void {
        while (isEndLine(self.current_char))
            self.advanceChar();
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
            '\r', '\n' => blk: {
                self.advanceToNextLine();
                break :blk .endl;
            },
            else => null,
        };
        self.advanceChar();

        return token;
    }

    pub fn collectAllAlloc(self: *Self, allocator: std.mem.Allocator) ![]Token {
        var tokens = std.ArrayList(Token).init(allocator);
        errdefer tokens.deinit();

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
        .endl,
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
        .endl,
        .{ .ident = "7" },
        .{ .ident = "8" },
        .endl,
        .{ .ident = "letters" },
        .{ .ident = "a" },
        .{ .ident = "b" },
        .backslash,
        .endl,
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
