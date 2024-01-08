//! This module provides implementation for KDL nodes.

/// In the event that a type is annotated.
/// Used as in:
/// `node (u8)123`
/// `node prop=(regex)".*"`
/// `(published)date "1970-01-01"`
/// `(contributor)person name="Foo McBar"`
const NodeType = enum {
    Isize,
    Usize,
    I8,
    I32,
    I64,
    U8,
    U32,
    U64,
    F32,
    F64,
    Decimal32,
    Decimal64,

    // Special string types
    DateTime,
    Time,
    Date,
    Duration,
    Decimal,
    Currency,
    Country2,
    Country3,
    CountrySubdivision,
    Email,
    IdnEmail,
    Hostname,
    IdnHostname,
    Ipv4,
    Ipv6,
    Url,
    UrlReference,
    Irl,
    IrlReference,
    UrlTemplate,
    Uuid,
    Regex,
    Base64,
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
