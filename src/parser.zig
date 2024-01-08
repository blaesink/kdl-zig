const std = @import("std");
const testing = std.testing;
const utils = @import("utils.zig");
const lexer = @import("lexer.zig");
const Token = lexer.Token;
const Lexer = lexer.Lexer;

const node = @import("node.zig");
const Node = node.Node;
const NodePropArg = node.NodePropArg;

const ParserError = error{
    InvalidSyntax,
    Unknown,
};

/// Words that are not allowed for identifiers (mostly string type annotations).
const Keywords = enum {
    @"date-time",
    time,
    date,
    duration,
    decimal,
    currency,
    @"country-2",
    @"country-3",
    @"country-subdivision",
    email,
    @"idn-email",
    hostname,
    @"idn-hostname",
    ipv4,
    ipv6,
    url,
    @"url-reference",
    irl,
    @"irl-reference",
    @"url-template",
    uuid,
    regex,
    base64,
};

pub const Parser = struct {
    tokens: []const Token,
    current_token: Token,
    position: usize = 0,
    read_position: usize = 1,

    const Self = @This();

    pub fn init(tokens: []Token) Self {
        return .{
            .tokens = tokens,
            .current_token = tokens[0],
        };
    }

    fn peek(self: Self) ?Token {
        if (self.read_position >= self.tokens.len)
            return null;

        return self.tokens[self.read_position];
    }

    fn peekN(self: Self, n: u8) ?[]const Token {
        if (self.read_position + n >= self.tokens.len)
            return null;

        return self.tokens[self.read_position .. self.read_position + n];
    }

    fn advance(self: *Self) void {
        if (self.read_position >= self.tokens.len)
            return;

        self.previous_token = self.current_token;
        self.position = self.read_position;
        self.current_token = self.tokens[self.position];
        self.read_position += 1;
    }

    fn buildTypeAnnotation(self: *Self) ParserError!Token {
        // Check forward 2 tokens, they should be <type> <.lparen>
        if (self.peekN(2)) |tokens| {
            if (!utils.sliceContainsEnumVariant(Token, tokens, .lparen) or tokens[0] == .lparen)
                return error.InvalidSyntax;

            // Jump forward
            self.position += 2;
            self.read_position += 2;

            return tokens[0];
        }
        return error.InvalidSyntax;
    }

    pub fn parseAlloc(self: *Self, allocator: std.mem.Allocator) ![]Node {
        var nodes = std.ArrayList(Node).init(allocator);
        errdefer nodes.deinit();

        for (self.tokens) |token| {
            switch (token) {
                .illegal => return error.InvalidSyntax,
                .lparen => self.buildTypeAnnotation(),
                else => return error.Unknown,
            }
        }

        return nodes.toOwnedSlice();
    }
};

// test "Parsing a simple declaration" {
//     const input = "person Zevin";

//     var lex = Lexer.init(input);
//     const tokens = try lex.collectAllAlloc(testing.allocator);
//     defer testing.allocator.free(tokens);

//     var parser = Parser.init(tokens);

//     const props = [_]NodePropArg{
//         .{ .value = "Zevin" },
//     };

//     const expected = [_]Node{
//         .{
//             .name = "person",
//             .prop_args = &props,
//         },
//     };

//     const actual = parser.parseAlloc(testing.allocator);

//     for (expected, actual) |e, a|
//         try testing.expectEqualDeep(e, a);
// }

test "peekN" {
    const input = "person Zevin 33 tall dark handsome";

    var lex = Lexer.init(input);
    const tokens = try lex.collectAllAlloc(testing.allocator);
    defer testing.allocator.free(tokens);

    var parser = Parser.init(tokens);

    const expected = [_]Token{
        .{ .ident = "Zevin" },
        .{ .ident = "33" },
    };

    const actual = parser.peekN(2).?;

    for (&expected, actual) |e, a|
        try testing.expectEqualDeep(e, a);

    try testing.expectError(error.InvalidSyntax, parser.buildTypeAnnotation());
}
