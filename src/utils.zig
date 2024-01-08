const std = @import("std");

pub fn sliceContainsEnumVariant(comptime EnumT: type, haystack: []const EnumT, needle: EnumT) bool {
    for (haystack) |item| {
        if (@intFromEnum(needle) == @intFromEnum(item))
            return true;
    }
    return false;
}

test "sliceContainsEnumVariant" {
    const MyEnum = enum {
        A,
        B,
        C,
    };

    const mySlice = [_]MyEnum{ .B, .C };

    try std.testing.expect(sliceContainsEnumVariant(MyEnum, &mySlice, .B));
    try std.testing.expect(!sliceContainsEnumVariant(MyEnum, &mySlice, .A));
}
