const std = @import("std");
const Allocator = std.mem.Allocator;

const thf = @import("terminal_helper_functions.zig");

const copyDirSettings = struct {
    current_recurse_depth : usize = 0,
    max_recursive_depth : usize,
    is_forcing : bool = false, // This will force-overwrite files when copying.
    dividing_character : u8 = '\\',
};

/// This will copy a directory, it's folders and it's sub-directories recursively until everything has been copied or the max_recursive_depth has been reached.
pub fn copyDirRecursive(alloc : Allocator, stdout : *std.io.Writer, dir_to_copy_from : std.fs.Dir, dest_dir : std.fs.Dir, copy_dir_settings : copyDirSettings) !void {

    const chosen_dir_abs_path = try dir_to_copy_from.realpathAlloc(alloc, ".");
    defer alloc.free(chosen_dir_abs_path);
    const cur_dir_abs_path = try dest_dir.realpathAlloc(alloc, ".");
    defer alloc.free(cur_dir_abs_path);

    const relative_paths = try get_mutual_reference(alloc, cur_dir_abs_path, chosen_dir_abs_path);
    defer {
        alloc.free(relative_paths[0]);
        alloc.free(relative_paths[1]);
    }
    const cur_to_chosen_relative_path = relative_paths[0];

    try stdout.print("Your absolute path is \"{s}\"\n", .{cur_dir_abs_path});
    try stdout.print("The Template Folder's absolute path is \"{s}\"\n", .{cur_dir_abs_path});
    try stdout.print("To go from the current directory to the template directory utilize the `cd {s}` command\n", .{relative_paths[0]});
    try stdout.print("To go back use the `cd {s}` command.\n", .{relative_paths[1]});
    try stdout.flush();

    var iter = dir_to_copy_from.iterate();
    var curEntry = try iter.next();

    while_loop : while (curEntry != null) : (curEntry = try iter.next()) {
        const new_path_to_file = try alloc.alloc(u8, cur_to_chosen_relative_path.len + curEntry.?.name.len + 1);
        defer alloc.free(new_path_to_file);

        @memcpy(new_path_to_file[0..cur_to_chosen_relative_path.len], cur_to_chosen_relative_path);
        new_path_to_file[cur_to_chosen_relative_path.len] = copy_dir_settings.dividing_character;
        @memcpy(new_path_to_file[cur_to_chosen_relative_path.len + 1..], curEntry.?.name);



        if (copy_dir_settings.is_forcing) {
            switch (curEntry.?.kind) {
                .file => {
                    try stdout.print("Copying from : {s} to {s}\n", .{new_path_to_file, cur_dir_abs_path});
                    try stdout.flush();
                    try dir_to_copy_from.copyFile(new_path_to_file, dest_dir, curEntry.?.name, .{});
                },
                .directory => {
                    const new_recurse_level = copy_dir_settings.current_recurse_depth + 1;
                    if (new_recurse_level >= copy_dir_settings.max_recursive_depth) {
                        try stdout.print("The max recursive depth ({}) has been reached. No further recursion will be taking place.\n", .{copy_dir_settings.max_recursive_depth});
                        try stdout.flush();
                        continue :while_loop;
                    }

                    var new_dir_to_copy_from = try dir_to_copy_from.openDir(curEntry.?.name, .{.iterate = true});
                    dest_dir.makeDir(curEntry.?.name) catch |err| switch (err) {
                        error.PathAlreadyExists => {},
                        else => return err,
                    };
                    var new_dest_dir = try dest_dir.openDir(curEntry.?.name, .{.iterate = true});


                    try copyDirRecursive(alloc, stdout, new_dir_to_copy_from, new_dest_dir, .{
                        .current_recurse_depth = new_recurse_level,
                        .max_recursive_depth = copy_dir_settings.max_recursive_depth,
                        .is_forcing = copy_dir_settings.is_forcing,
                    });

                    new_dir_to_copy_from.close();
                    new_dest_dir.close();
                },
                else => |file_type| {
                    try stdout.print("Error, unexpected file |{s}| with type |{s}|, skipping that file\n", .{curEntry.?.name, @tagName(file_type)});
                    try stdout.flush();
                }
            }
        } else {
            switch (curEntry.?.kind) {
                .file => {
                    const entry_names = try getAllEntryNames(alloc, dest_dir);
                    defer {
                        alloc.free(entry_names[0]);
                        alloc.free(entry_names);
                    }

                    if (entry_names.len <= 1) { // the first item is always the "allocated" memory.
                        try dest_dir.copyFile(new_path_to_file, dest_dir, curEntry.?.name, .{});
                        continue :while_loop;
                    } else {
                        if (!thf.is_str_in_list_of_strs(curEntry.?.name, entry_names[1..], true)) {
                            try dest_dir.copyFile(new_path_to_file, dest_dir, curEntry.?.name, .{});
                        } else {
                            try stdout.print("File : <{s}> already exists; skipping duplication\n", .{curEntry.?.name});
                            try stdout.flush();
                            continue :while_loop;
                        }
                    }
                },
                .directory => {
                    const new_recurse_level = copy_dir_settings.current_recurse_depth + 1;
                    if (new_recurse_level >= copy_dir_settings.max_recursive_depth) {
                        try stdout.print("The max recursive depth ({}) has been reached. No further recursion will be taking place.\n", .{copy_dir_settings.max_recursive_depth});
                        try stdout.flush();
                        continue :while_loop;
                    }

                    var new_dir_to_copy_from = try dir_to_copy_from.openDir(curEntry.?.name, .{.iterate = true});
                    dest_dir.makeDir(curEntry.?.name) catch |err| switch (err) {
                        error.PathAlreadyExists => {},
                        else => return err,
                    };
                    var new_dest_dir = try dest_dir.openDir(curEntry.?.name, .{.iterate = true});


                    try copyDirRecursive(alloc, stdout, new_dir_to_copy_from, new_dest_dir, .{
                        .current_recurse_depth = new_recurse_level,
                        .max_recursive_depth = copy_dir_settings.max_recursive_depth,
                        .is_forcing = copy_dir_settings.is_forcing,
                    });

                    new_dir_to_copy_from.close();
                    new_dest_dir.close();
                },
                else => |file_type| {
                    try stdout.print("Error, unexpected file |{s}| with type |{s}|, skipping that file\n", .{curEntry.?.name, @tagName(file_type)});
                    try stdout.flush();
                }
            }
        }
        
    }

        
}

pub fn getAllEntryNames(alloc : Allocator, dir_to_read : std.fs.Dir) ![] [] u8 {
    var number_of_chars : usize = 0;
    var number_of_entries : usize = 0;
    var iter = dir_to_read.iterate();
    var next = try iter.next();
    
    

    while (next != null) : (next = try iter.next()) {
        number_of_entries += 1;
        number_of_chars += next.?.name.len;
    }

    var names = try alloc.alloc(u8, number_of_chars);
    var name_pointers = try alloc.alloc([]u8, number_of_entries + 1);
    name_pointers[0] = names;
    var cur_name_pos : usize = 0;
    var cur_index : usize = 1;
    
    iter.reset();
    next = try iter.next();

    while (next != null) : (next = try iter.next()) {
        const cur_name_len = next.?.name.len;
        @memcpy(names[cur_name_pos..cur_name_pos + cur_name_len], next.?.name);
        name_pointers[cur_index] = names[cur_name_pos..cur_name_pos + cur_name_len];
        cur_name_pos += cur_name_len;
        cur_index += 1;
    }

    return name_pointers;
}

pub fn displaySubdirectories(dir : std.fs.Dir, stdout : *std.io.Writer) !void {
    var iter_folders = dir.iterate();
    var next = try iter_folders.next();

    
    while (next != null) : (next = try iter_folders.next()) {
        if (next.?.kind == .directory) try stdout.print("    {s}\n", .{next.?.name});
    }

    try stdout.flush();
}

/// Returns 2 paths (strings);
/// the first string is the relative path from path1 to path2
/// the second string is the relative path from path2 to path1
///   
/// Ex.
/// const cwd_path = try std.process.getCwdAlloc(alloc);
/// defer alloc.free(cwd_path);
/// 
/// const refs = try get_mutual_reference(alloc, cwd_path, absolute_path_to_dir);
/// defer {
///     alloc.free(refs[0]);
///     alloc.free(refs[1]);
/// }
/// 
/// const dir1 = try cwd.openDir(refs[0], .{}); // we are now at the location of path2;
/// const back_to_cwd = try dir1.openDir(refs[1], .{}) // we are now back at the original directory.
pub fn get_mutual_reference(alloc : Allocator, path1 : []const u8, path2 : []const u8, dividing_character : u8) ![2] []const u8 {
    
    const probable_max_end_path_chars = @max(path1.len, path2.len);
    
    
    const set_one = try breakApartPath(alloc, path1, dividing_character);
    defer alloc.free(set_one);
    const set_two = try breakApartPath(alloc, path2, dividing_character);
    defer alloc.free(set_two);


    // __iterateThroughTwoSets(set_one, set_two);

    const min_size = @min(set_one.len, set_two.len);
    var number_of_times_path_one_has_to_go_up : usize = 0;
    var number_of_times_path_two_has_to_go_up : usize = 0;
    var paths_diverged : bool = false;

    for (set_one[0..min_size], set_two[0..min_size]) |e1, e2| {
        if ( (!paths_diverged) and (!thf.str_eql(e1, e2, true)) ) {
            paths_diverged = true;
        }

        if (paths_diverged) {
            number_of_times_path_one_has_to_go_up += 1;
            number_of_times_path_two_has_to_go_up += 1;
        }
    }

    if (set_one.len != min_size) {
        number_of_times_path_one_has_to_go_up += set_one.len - min_size;
    } else if (set_two.len != min_size) {
        number_of_times_path_two_has_to_go_up += set_two.len - min_size;
    }

    var new_path_one = try std.ArrayList(u8).initCapacity(alloc, probable_max_end_path_chars); // this should be a bit much
    for (0..number_of_times_path_one_has_to_go_up) |i| {
        if (i != number_of_times_path_one_has_to_go_up - 1){
            try new_path_one.appendSlice(alloc, &[3]u8 {'.', '.', dividing_character});
        } else {
            try new_path_one.appendSlice(alloc, "..");
        }
    }
    for (0..number_of_times_path_two_has_to_go_up) |i| {
        const adjusted_i = (set_two.len - number_of_times_path_two_has_to_go_up) + i;
        if (number_of_times_path_one_has_to_go_up == 0 and i == 0) {
            try new_path_one.appendSlice(alloc, set_two[adjusted_i][1..]);
        } else try new_path_one.appendSlice(alloc, set_two[adjusted_i]);
    }

    var new_path_two = try std.ArrayList(u8).initCapacity(alloc, probable_max_end_path_chars); // this should be a bit much
    for (0..number_of_times_path_two_has_to_go_up) |i| {
        if (i != number_of_times_path_two_has_to_go_up - 1){
            try new_path_two.appendSlice(alloc, &[3]u8 {'.', '.', dividing_character});
        } else {
            try new_path_two.appendSlice(alloc, "..");
        }
    }
    for (0..number_of_times_path_one_has_to_go_up) |i| {
        const adjusted_i = (set_one.len - number_of_times_path_one_has_to_go_up) + i;
        if (number_of_times_path_two_has_to_go_up == 0 and i == 0) {
            try new_path_two.appendSlice(alloc, set_one[adjusted_i][1..]); // This gets rid of the leading '\'
        } else try new_path_two.appendSlice(alloc, set_one[adjusted_i]);
    }


    new_path_one.shrinkAndFree(alloc, new_path_one.items.len);
    new_path_two.shrinkAndFree(alloc, new_path_two.items.len);

    return [2] []const u8 {new_path_one.items, new_path_two.items};

}

/// This is for debug purposes
pub fn __iterateThroughTwoSets(setOne : []const []const u8, setTwo : []const []const u8) void {
    const print = std.debug.print;

    const min_size = @min(setOne.len, setTwo.len);
    
    for (setOne[0..min_size], setTwo[0..min_size]) |e1, e2| {
        print("{s:-<25}{s:->25}\n", .{e1, e2});
    }
    if (setOne.len > min_size) {
        for (setOne[min_size..]) |e1| {
            print("{s:-<50}\n", .{e1});
        }
    } else if (setTwo.len > min_size) {
        for (setTwo[min_size..]) |e2| {
            print("{s:->50}\n", .{e2});
        }
    }
}


/// This takes in an absolute_path to a directory, and the name of a folder inside it and then returns the inner folder.
/// Returns error.FolderNotFound if the subfolder doesn't exist.
/// I am fairly confident that I have more efficient ways to do this, but this works and it is good enough.
pub fn getFolderFromTemplateFolder(alloc : Allocator, path_to_directory : []const u8, folderName : []const u8) !std.fs.Dir {
    var next_folder = try openDirAbsPath(alloc, path_to_directory);
    defer next_folder.close();

    var iterator = next_folder.iterate();
    var cur_pos = try iterator.next();

    while (cur_pos != null) : (cur_pos = try iterator.next()) {
        if (thf.str_eql(cur_pos.?.name, folderName, true)) {
            return next_folder.openDir(folderName, .{.iterate = true}) catch |err| switch (err) {
                error.FileNotFound => error.FolderNotFound,
                else => err,
            };
        }
    }

    return error.FolderNotFound;
}

/// This a directory via an absolute path.
pub fn openDirAbsPath(alloc : Allocator, path_to_directory : []const u8) !std.fs.Dir {
    var cwd = std.fs.cwd();
    defer cwd.close();
    const cur_path = try cwd.realpathAlloc(alloc, ".");
    const both_references = try get_mutual_reference(alloc, cur_path, path_to_directory);
    defer {
        alloc.free(both_references[0]);
        alloc.free(both_references[1]);
    }

    // if the following line fails then the path_to_directory must be wrong.
    const next_folder = cwd.openDir(both_references[0], .{.iterate = true}) catch |err| {
        std.debug.print("Error |{any}| was received when trying to open the following path : |{s}|\n", .{err, both_references[0]});
        return err;
    };
    return next_folder;
}

/// This is dependent on the original string remaining constant.
/// The only thing allocated here is the array of pointers to each sub-string.
pub fn breakApartPath(alloc : Allocator, path : []const u8, dividing_character : u8) ![][]const u8 {
    
    var start_ind : usize = 0;
    var cur_split = thf.find_item_in_list(u8, dividing_character, path);

    var arr_list = try std.ArrayList([]const u8).initCapacity(alloc, 4);


    while (cur_split != null) {
        const entry = path[start_ind..cur_split.?];
        try arr_list.append(alloc, entry);

        start_ind = cur_split.?;
        
        const next_index = cur_split.? + 1;
        if (next_index >= path.len) break;
        cur_split = thf.find_item_in_list(u8, dividing_character, path[next_index..]);
        if (cur_split == null) {
            try arr_list.append(alloc, path[start_ind..]);
            break;
        }
        cur_split = cur_split.? + next_index;
    }
    arr_list.shrinkAndFree(alloc, arr_list.items.len);
    return arr_list.items;

}

/// This undoes breakApartPath();
/// The returned item is allocated and not dependent on anything.
pub fn remakePathFromPieces(alloc : Allocator, pieces : [][]const u8) ![]u8 {
    
    var total_len : usize = 0;
    for (pieces) |piece| {
        total_len += piece.len;
    }
    const new_str = try alloc.alloc(u8, total_len);
    var cur_index : usize = 0;
    for (pieces) |piece| {
        @memcpy(new_str[cur_index..cur_index + piece.len], piece);
        cur_index += piece.len;
    }

    return new_str;
}
