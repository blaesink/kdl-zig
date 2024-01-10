//! This module provides implementation for KDL nodes.

/// In the event that a type is annotated.
/// Used as in:
/// `node (u8)123`
/// `node prop=(regex)".*"`
/// `(published)date "1970-01-01"`
/// `(contributor)person name="Foo McBar"`
pub const NodeType = enum {
    isize,
    usize,
    i8,
    i32,
    i64,
    u8,
    u32,
    u64,
    f32,
    f64,
    decimal32,
    decimal64,

    // Special string types
    dateTime,
    time,
    date,
    duration,
    decimal,
    currency,
    country2,
    country3,
    countrySubdivision,
    email,
    idnEmail,
    hostname,
    idnHostname,
    ipv4,
    ipv6,
    url,
    urlReference,
    irl,
    irlReference,
    urlTemplate,
    uuid,
    regex,
    base64,
};

/// `node-prop-or-arg := ('/-' node-space*)? (prop | value)`
pub const NodePropArg = union(enum) {
    // Raw values, for things like arrays.
    value: []const u8,

    // a=1 b=2 ...
    prop: struct {
        identifier: []const u8,
        value: []const u8,
    },
};

/// A Node holds an `identifier` and `children`.
///
/// `node := ('/-' node-space*)? type? identifier (node-space+ node-prop-or-arg)*
///          (node-space* node-children ws*)? node-space* node-terminator`
pub const Node = struct {
    name: []const u8, // The "identifier" or "name".
    type: ?NodeType = null, // If null, then this is either the "parent" or bare.
    prop_args: ?[]const NodePropArg = null, // Any subsquent items.
    children: ?[]const Node = null, // Any child items in brackets.
};
