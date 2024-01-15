const std = @import("std");
const testing = std.testing;
const utils = @import("utils.zig");
const lexer = @import("lexer.zig");
const Token = lexer.Token;
const Lexer = lexer.Lexer;

const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
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

    /// Look at the next token (if not at end of stream).
    fn peek(self: Self) ?Token {
        if (self.read_position >= self.tokens.len)
            return null;

        return self.tokens[self.read_position];
    }

    /// Look at the next `n` tokens (if not at end of stream).
    fn peekN(self: Self, n: usize) ?[]const Token {
        if (self.read_position > self.tokens.len or self.read_position + n > self.tokens.len)
            return null;

        return self.tokens[self.read_position .. self.read_position + n];
    }

    fn advance(self: *Self) void {
        if (self.read_position >= self.tokens.len)
            return;

        self.position = self.read_position;
        self.current_token = self.tokens[self.position];
        self.read_position += 1;
    }

    fn buildTypeAnnotation(self: *Self) ParserError!NodeType {
        // Check forward 2 tokens, they should be <type> <.rparen>
        if (self.peekN(2)) |tokens| {
            if (!utils.sliceContainsEnumVariant(Token, tokens, .rparen) or tokens[0] == .rparen) {
                return ParserError.InvalidSyntax;
            }

            // Jump forward
            self.position += 2;
            self.read_position += 2;

            return switch (tokens[0]) {
                .ident => |i| blk: {
                    if (std.meta.stringToEnum(NodeType, i)) |annot|
                        break :blk annot;
                },
                else => ParserError.InvalidSyntax,
            };
        }
        return ParserError.InvalidSyntax;
    }

    /// *Caller owns returned memory!*
    /// Advance forward in token stream until we can no longer build an array of KDL properties
    /// or args to be attached to a node.
    fn buildPropArgList(self: *Self, allocator: std.mem.Allocator) ![]const NodePropArg {
        // Keep track of where we are.
        var prop_args = std.ArrayList(NodePropArg).init(allocator);
        errdefer prop_args.deinit();

        while (true) blk: {
            switch (self.current_token) {
                .ident => |i| {
                    // check to see if this is a prop and not an arg;
                    if (self.peekN(2)) |tks| {
                        if (tks[0] == .equals) {
                            switch (tks[1]) {
                                .ident => |v| {
                                    try prop_args.append(NodePropArg{
                                        .prop = .{ .identifier = i, .value = v },
                                    });
                                },
                                else => return ParserError.InvalidSyntax,
                            }
                        }
                    }
                },
                else => break :blk,
            }
        }

        return try prop_args.toOwnedSlice();
    }

    /// *Caller owns returned memory!*
    /// Parse the incoming token stream and return a slice of KDL nodes.
    pub fn parseAlloc(self: *Self, allocator: std.mem.Allocator) ![]Node {
        var nodes = std.ArrayList(Node).init(allocator);
        errdefer nodes.deinit();

        for (self.tokens) |token| {
            var this_node: node.Node = undefined;

            switch (token) {
                .ident => |i| {
                    self.advance(); // Move forward one.
                    // Hitting an identifier at this point means we are at the beginning of a definition.
                    // Ergo, collect forwards until we hit a node terminal (endline w/o preceding `\` or `;`)
                    this_node.name = i;

                    // try to build PropArg list.
                    const prop_args = try self.buildPropArgList(allocator);

                    if (prop_args.len > 0)
                        this_node.prop_args = prop_args;
                },
                .lparen => {
                    // Attempt to build a type annotation
                    this_node.type = try self.buildTypeAnnotation();
                },
                .lcurly => {
                    // build child node.
                },
                .illegal => return ParserError.InvalidSyntax,
                // r( curly | paren ) get slurped in their respective func calls.
                else => continue,
            }

            try nodes.append(this_node);
        }

        return try nodes.toOwnedSlice();
    }
};

test "buildTypeAnnotation" {
    const tokens = try lexer.lexFromLine("(u8)", testing.allocator);
    defer testing.allocator.free(tokens);

    var parser = Parser.init(tokens);

    const expected = NodeType.u8;
    const actual = try parser.buildTypeAnnotation();

    try testing.expectEqual(expected, actual);
}

// test "Parsing a simple declaration" {
//     const input = "person Zevin tall dark handsome";

//     var lex = Lexer.init(input);
//     const tokens = try lex.collectAllAlloc(testing.allocator);
//     defer testing.allocator.free(tokens);

//     var parser = Parser.init(tokens);

//     const props = [_]NodePropArg{
//         .{ .value = "Zevin" },
//         .{ .value = "tall" },
//         .{ .value = "dark" },
//         .{ .value = "handsome" },
//     };

//     const expected = [_]Node{
//         .{
//             .name = "person",
//             .prop_args = &props,
//         },
//     };

//     const actual = try parser.parseAlloc(testing.allocator);
//     defer testing.allocator.free(actual);

//     for (&expected, actual) |e, a|
//         try testing.expectEqualDeep(e, a);
// }

test "peekN" {
    {
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
    // {
    //     const tokens = try lexer.lexFromLine("(u8)", testing.allocator);
    //     defer testing.allocator.free(tokens);

    //     var p = Parser.init(tokens);

    //     const expected = [_]Token{
    //         .{ .ident = "u8" },
    //         .rparen,
    //     };

    //     const actual = p.peekN(2).?;
    //     std.debug.print("{any}\n", .{actual});

    //     for (&expected, actual) |e, a|
    //         try testing.expectEqualDeep(e, a);
    // }
}
