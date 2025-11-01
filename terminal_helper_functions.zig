const testing = @import("std").testing;


/// exclusive_flag_prefix will be checked before the flag_prefix.
/// Flags that operate with the exlusive-flag prefix are multiple characters.
/// Flags that operate with the default flag-prefix are multiple characters.
/// caseLock doesn't apply to the flag_prefix/exclusive_flag_prefix only the flags
///     provided from the flag_set.
pub fn find_flag_in_args(args : []const []const u8, flag_set : []const []const u8, flag_prefix : []const u8, exclusive_flag_prefix : []const u8, caseLock : bool) ?usize {
    var cur_index : usize = 0;

    for (args) |a| {
        if (str_prefixed_with(a, exclusive_flag_prefix)) {

            const potential_flag = a[exclusive_flag_prefix.len..];

            for (flag_set) |flag| {
                if (str_eql(flag, potential_flag, caseLock)) {
                    return cur_index;
                }
            }
        } else if (str_prefixed_with(a, flag_prefix)) {
            const flag_block = a[flag_prefix.len..];

            for (flag_set) |flag| {
                if (flag.len > 1) continue;
                if (item_in_list(u8, flag[0], flag_block)) {
                    return cur_index;
                }
            }
        }


        cur_index += 1;
    }

    return null;
}

pub fn find_arg_at_pos_ignore_potential_flags(args : []const []const u8, target_index : usize, flag_prefix : []const u8, exclusive_flag_prefix : []const u8) ![]const u8 {
    var cur_index : usize = 0;
    if (target_index >= args.len) return error.IndexOutsideOfBounds;

    for (args) |arg| {
        if (str_prefixed_with(arg, exclusive_flag_prefix)) continue;
        if (str_prefixed_with(arg, flag_prefix)) continue;

        if (cur_index == target_index) return arg;

        cur_index += 1;
    }

    // If this code is reached then there the index was never reached.
    return error.IndexNeverReached;
}

pub fn first_unrecognized_flag(args : []const []const u8, flag_sets : []const []const []const u8, flag_prefix : []const u8, exclusive_flag_prefix : []const u8, caseLock : bool) ?[]const u8 {
    arg_loop : for (args) |arg| {
        if (str_prefixed_with(arg, exclusive_flag_prefix)) {
            for (flag_sets) |set| {
                for (set) |flag| {
                    if (str_eql(arg[exclusive_flag_prefix.len..], flag, caseLock)) {
                        continue :arg_loop;
                    } else return arg;
                }
            }
        } else if (str_prefixed_with(arg, flag_prefix)) {
            // determine that every char inside the generic flag is a valid flag
            for (arg[flag_prefix.len..]) |char| {
                var char_is_flag : bool = false;

                flag_set_loop : for (flag_sets) |set| {
                    set_loop : for (set) |flag| {
                        if (flag.len != 1) continue :set_loop;
                        if (char == flag[0]) {
                            char_is_flag = true;
                            break :flag_set_loop;
                        }
                    }
                }

                if (char_is_flag == false) return arg;
            }

        }
    }

    return null;
}

pub fn get_item_in_list_ignore_indexes(targetIndex : usize, indexesToIgnore : [] usize, list : []const []const u8) ?[]const u8 {
    var cur_ind : usize = 0;

    for (list, 0..) |item, ind| {
        if (item_in_list(usize, ind, indexesToIgnore)) continue;
        if (cur_ind == targetIndex) return item;
        cur_ind += 1;
    }

    return null;
}

pub fn str_index_in_list_of_strs(flag : []const u8, list : []const []const u8, caseLock : bool) ?usize {
    for (list, 0..) |item, index| {
        if (str_eql(flag, item, caseLock)) return index;
    }
    return null;
}

pub fn find_first_index_of_list_one_in_strs(lst1 : []const []const u8, lst2 : []const []const u8, caseLock : bool) ?usize {
    for (lst2, 0..) |item, index| {
        for (lst1) |key| {
            if (str_eql(key, item, caseLock)) return index;
        }
    }

    return null;
}

pub fn is_str_in_list_of_strs(flag : []const u8, list : []const [] const u8, strict_casing : bool) bool {
    for (list) |item| {
        if (str_eql(flag, item, strict_casing)) return true;
    }
    return false;
}

pub fn find_item_in_list(T : type, item : T, list : []const T) ?usize {
    for (list, 0..) |l, i| {
        if (l == item) return i;
    } return null;
}

pub fn item_in_list(T : type, item : T, list : []const T) bool {
    for (list) |l| {
        if (l == item) return true;
    } return false;
}





pub fn str_prefixed_with(str : []const u8, prefix : []const u8) bool {
    if (str.len < prefix.len) return false;

    for (prefix, str[0..prefix.len]) |c1, c2| {
        if (c1 != c2) return false;
    }

    return true;
}

pub fn str_eql(str1 : []const u8, str2 : []const u8, strict_casing : bool) bool {
    if (str1.len != str2.len) return false;

    if (strict_casing) {
        for (str1, str2) |c1, c2| {
            if (c1 != c2) return false;
        }
    } else {
        for (str1, str2) |c1, c2| {

            if (c1 == c2) continue;

            const c1_is_lower : bool = c1 >= 'a' and c1 <= 'z';
            const c1_is_upper : bool = c1 >= 'A' and c1 <= 'Z';

            if (c1_is_lower) {
                if (c1 - 'a' + 'A' == c2) continue; 
            } else if (c1_is_upper) {
                if (c1 - 'A' + 'a' == c2) continue;
            }


            return false;
        }
    }

    return true;
}

pub fn find_fist_char_not_equivalent(str1 : []const u8, str2 : []const u8) !?usize {
    
    const min_size = @min(str1.len, str2.len);
    
    for (str1[0..min_size], str2[0..min_size], 0..) |c1, c2, i| {
        if (c1 != c2) return i;
    }

    if (str1.len < str2.len) {
        return error.str1_is_contained_inside_str2;
    } else if (str2.len < str1.len) {
        return error.str2_is_contained_inside_str1;
    }

    return null;
}



test "Test fn str_eql" {

    const test_case = struct{
        s1 : []const u8,
        s2 : []const u8,
        is_eql_without_caselock : bool,
        is_eql_strict : bool,

        pub fn init(s1 : []const u8, s2 : []const u8, is_eql_without_caselock : bool, is_eql_strict : bool) @This() {
            return .{
                .s1 = s1,
                .s2 = s2,
                .is_eql_without_caselock = is_eql_without_caselock,
                .is_eql_strict = is_eql_strict,
            };
        }

        pub fn assert(s : *const @This()) bool {
            const with_strict_casing = str_eql(s.s1, s.s2, true);
            const without_strict_casing = str_eql(s.s1, s.s2, false);

            if (with_strict_casing != s.is_eql_strict) return false;
            if (without_strict_casing != s.is_eql_without_caselock) return false;

            const reversed_with = str_eql(s.s2, s.s1, true);
            const reversed_without = str_eql(s.s2, s.s1, false);

            if (reversed_with != with_strict_casing) return false;
            if (reversed_without != without_strict_casing) return false;

            return true;
        }
    };

    const testCases = [_] test_case {
        .{
            .s1 = "Hello",
            .s2 = "hello",
            .is_eql_without_caselock = true,
            .is_eql_strict = false,
        },
        test_case.init("subnet", "sub", false, false),
        test_case.init("mike8116", "mike8116", true, true),
        test_case.init("abc", "123", false, false),
        test_case.init("wOrKiNg", "working", true, false),
        test_case.init("Magical, Banana", "Magical, Bananz", false, false),
    };

    var cases_passed : usize = 0;

    for (testCases) |tc| {
        if (tc.assert()) {
            cases_passed += 1;
        }
    }

    try testing.expect(cases_passed == testCases.len);
}
