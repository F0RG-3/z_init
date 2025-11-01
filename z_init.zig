const std = @import("std");
const thf = @import("terminal_helper_functions.zig");
const ff = @import("folder_functions.zig");
const Allocator = std.mem.Allocator;

const cur_os = @import("builtin").os.tag;
const folder_holding_templates = "FolderTemplates";
const dividing_character = if (cur_os == .windows) '\\' else '/';

const flag_prefix = "-"; // The flags here can only be 1 character long.
const exclusive_flag_prefix = "--"; // This means that "--" can only have 1 flag after it.

const version = "0.1.4";
const version_patch = 7;

const help_flags = [_] []const u8 {
    "h",
    "i",
    "help",
    "information",
    "info",
};
const replace_flags = [_] []const  u8 {
    "r",
    "replace",
};
const add_flags = [_] [] const u8 {
    "a",
    "add",
};
const list_option_flags = [_] []const u8 {
    "l",
    "list",
};
const path_flags = [_] []const u8 {
    "p",
    "path",
};
const sanitize_flags = [_] []const u8 {
    "s",
    "sanitize",
};

const sanitize_ignore_filenames = [_] []const u8 {
    ".zig-cache",
    "zig-out",
};
const All_Flag_Sets = [_] []const [] const u8 {
    &help_flags,
    &replace_flags,
    &add_flags,
    &list_option_flags,
    &path_flags,
    &sanitize_flags,
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const stdout__root = std.fs.File.stdout();
    var internal_stdout_buf : [500] u8 = undefined;
    var stdout = stdout__root.writer(&internal_stdout_buf);
    const cwd_path = try std.process.getCwdAlloc(alloc); // std.fs.cwd().realpathAlloc() should never be called; it (on Windows) can return a potentially non-case sensitive path. (It also, apparently, can be case sensitive and so don't use it.)
    defer alloc.free(cwd_path);

    // getting directory_path and app_name
    var app_name : [] u8 = undefined;
    var directory_path : [] u8 = undefined;

    if (cur_os == .windows) {
        const path_blocked = try ff.breakApartPath(alloc, args[0], dividing_character);
        app_name = try alloc.alloc(u8, path_blocked[path_blocked.len - 1].len);
        @memcpy(app_name, path_blocked[path_blocked.len - 1]);
        alloc.free(path_blocked);
    } else {
        app_name = args[0]; // this is to cut off the '.\'
    }
    const app_path = try std.fs.selfExeDirPathAlloc(alloc);
    directory_path = try alloc.alloc(u8, app_path.len + folder_holding_templates.len + 1);
    @memcpy(directory_path[0..app_path.len], app_path);
    directory_path[app_path.len] = dividing_character;
    @memcpy(directory_path[app_path.len + 1..], folder_holding_templates);
    alloc.free(app_path);

    defer alloc.free(app_name);
    defer alloc.free(directory_path);
    // directory_path and app_name have been found
    

    const options = try getTemplateOptions(alloc, cwd_path, directory_path);
    defer {
        for (options) |o| {
            alloc.free(o);
        }
        alloc.free(options);
    }
    if (args.len <= 1) {
        try printHelpScreen(&stdout.interface, app_name);
        return;
    }

    const help_pos = thf.find_flag_in_args(args[1..], &help_flags, flag_prefix, exclusive_flag_prefix, true);
    const replace_pos = thf.find_flag_in_args(args[1..], &replace_flags, flag_prefix, exclusive_flag_prefix, true);
    const add_pos = thf.find_flag_in_args(args[1..], &add_flags, flag_prefix, exclusive_flag_prefix, true);
    const list_option_pos = thf.find_flag_in_args(args[1..], &list_option_flags, flag_prefix, exclusive_flag_prefix, true);
    const path_pos = thf.find_flag_in_args(args[1..], &path_flags, flag_prefix, exclusive_flag_prefix, true);
    const sanitize_pos = thf.find_flag_in_args(args[1..], &sanitize_flags, flag_prefix, exclusive_flag_prefix, true);

    var used_helper_flag : bool = false;
    var helper_screen_displayed : bool = false;
    var replaceForced : bool = false;
    var add_template : bool = false;
    var sanitized_mode : bool = false;
    var processed_args : usize = 1; 

    if (help_pos != null) {
        try printHelpScreen(&stdout.interface, app_name);
        used_helper_flag = true;
        processed_args += 1;
        helper_screen_displayed = true;
    }
    if (replace_pos != null) {
        replaceForced = true;
        processed_args += 1;
    }
    if (add_pos != null) {
        //try stdout.interface.print("Adding to templates...\n", .{});
        if (helper_screen_displayed) {            
            try stdout.interface.writeAll("\n-----------\n\n");
            try stdout.interface.writeAll("The add Command will add your current directory to the Template Folders.\nThere is a Default-Max Recursion for folders it will open (which is 5)\n");
            try stdout.interface.writeAll("For add_pos to be used you will need to add the name that you want the template folder to be known as.\n");
            try stdout.interface.writeAll("If the name chosen already exists as a template, it will not be overwritten unless you specify the 'r' flag\n");
            try stdout.interface.flush();
        } else {
            add_template = true;
        }
        processed_args += 1;
    }
    if (list_option_pos != null) {
        if (helper_screen_displayed) {
            try stdout.interface.writeAll("\n-----------\n");
        }
        try stdout.interface.writeAll("Options : \n-----------\n");
        for (options) |o| {
            try stdout.interface.print("    {s}\n", .{o});
        }

        try stdout.interface.flush();
        used_helper_flag = true;
        processed_args += 1;
        helper_screen_displayed = true;
    }
    if (path_pos != null) {
        if (helper_screen_displayed) {           
            try stdout.interface.writeAll("\n-----------\n");
        }

        try stdout.interface.print("The exe is located at : {s}\n", .{cwd_path});
        try stdout.interface.print("The directory folder is located at : {s}\n", .{directory_path});
        try stdout.interface.flush();
        used_helper_flag = true;
        processed_args += 1;
        helper_screen_displayed = true;
    }

    if (sanitize_pos != null) {
        if (helper_screen_displayed) {
            try stdout.interface.writeAll("\n-----------\n");

            try stdout.interface.print("Sanitize Mode simply ignores certain files and directories when copying/pasting.\n", .{});
            try stdout.interface.print("The files that it ignores are the following :\n", .{});
            for (sanitize_ignore_filenames) |file_name| {
                try stdout.interface.print("    {s}\n", .{file_name});
            }
            try stdout.interface.print("This applies for both copying from a template, and for making a template.\n", .{});
            try stdout.interface.print("Do note that it will only ignore those files on the highest level.\n", .{});
            try stdout.interface.flush();
        }

        sanitized_mode = true;
        processed_args += 1;
    }





    const unrecognized_flag = thf.first_unrecognized_flag(args, &All_Flag_Sets, flag_prefix, exclusive_flag_prefix, true);
    if (unrecognized_flag != null) {
        try stdout.interface.print("Received unrecognized flag : <{s}>\n", .{unrecognized_flag.?});
        try stdout.interface.flush();
        return;
    }
    if (used_helper_flag) return;
    const chosen_template_name = thf.find_arg_at_pos_ignore_potential_flags(args, 1, flag_prefix, exclusive_flag_prefix) catch {
        try stdout.interface.writeAll("Expected, but couldn't find, a directory argument\n");
        try stdout.interface.flush();
        return;
    };
    processed_args += 1;
    if (processed_args < args.len) {
        try stdout.interface.writeAll("Error; encountered unexpected an unexpected argument\n");
        try stdout.interface.flush();
        return;
    }
    if (add_template) {
        var cwd = try std.fs.cwd().openDir(".", .{.iterate = true});
        defer cwd.close();
        var TemplateFolder = try openAbsPath(alloc, cwd_path, directory_path);

        TemplateFolder.makeDir(chosen_template_name) catch |err| switch (err) {
            error.PathAlreadyExists => {
                if (replaceForced) {
                    try TemplateFolder.deleteTree(chosen_template_name);
                    try TemplateFolder.makeDir(chosen_template_name);
                } else {
                    try stdout.interface.print("That template already exists. If you really want to overwrite it specify the '-r' flag\n", .{});
                    try stdout.interface.flush();
                    return;
                }
            },
            else => return err,
        };
        var folderToWriteInto = try TemplateFolder.openDir(chosen_template_name, .{.iterate = true});
        defer folderToWriteInto.close();
        TemplateFolder.close();

        try copyDirRecursive(alloc, &stdout.interface, folderToWriteInto, cwd, .{
            .will_force = false,
            .use_sanitized = sanitized_mode,
        });

        try stdout.interface.print("The template has been populated under the name \"{s}\"\n", .{chosen_template_name});
        return;
    } else if (!thf.is_str_in_list_of_strs(chosen_template_name, options, true)) {
        try stdout.interface.writeAll("The Chosen Template cannot be found inside the template folder\n");
        try stdout.interface.print("You can check the folder here : <{s}>\n", .{directory_path});
        try stdout.interface.print("Alternatively use the flag `-l` to see your options.\n", .{});
        try stdout.interface.flush();
        return;
    }

    var cwd = try std.fs.cwd().openDir(".", .{.iterate = true});
    defer cwd.close();
    const path2 = try std.process.getCwdAlloc(alloc);
    defer alloc.free(path2);
    if (!thf.str_eql(path2, cwd_path, true)) unreachable;
    var TemplateFolder = try openAbsPath(alloc, cwd_path, directory_path);
    var templateDir = try TemplateFolder.openDir(chosen_template_name, .{.iterate = true});
    defer templateDir.close();
    TemplateFolder.close();

    try copyDirRecursive(alloc, &stdout.interface, cwd, templateDir, .{
        .will_force = replaceForced,
        .use_sanitized = sanitized_mode,
    });

    try stdout.interface.writeAll("Copying Completed\n");
    try stdout.interface.flush();
}

pub const copyDirRecursiveSettings = struct{
    cur_recursion : usize = 0,
    max_recursion : usize = 5,
    will_force : bool = false,
    use_sanitized : bool = false, // this will decay to false on every increment recursion

    pub fn increment_recursion(self : copyDirRecursiveSettings) copyDirRecursiveSettings {
        return .{
            .cur_recursion = self.cur_recursion + 1,
            .max_recursion = self.max_recursion,
            .will_force = self.will_force,
            .use_sanitized = false,
        };
    }
};

pub fn copyDirRecursive(alloc : Allocator, writer : *std.Io.Writer, dest : std.fs.Dir, template : std.fs.Dir, settings : copyDirRecursiveSettings) !void {
    if (settings.will_force) {
        var iter = template.iterate();
        var next = try iter.next();

        while (next != null) : (next = try iter.next()) {
            const name = next.?.name;
            const kind = next.?.kind;

            if (settings.use_sanitized) {
                if (thf.is_str_in_list_of_strs(name, &sanitize_ignore_filenames, true)) {
                    continue;
                }
            }

            switch (kind) {
                .file => {
                    try std.fs.Dir.copyFile(template, name, dest, name, .{});
                },
                .directory => {
                    if (settings.cur_recursion >= settings.max_recursion) {
                        try writer.print("You have exceeded your max recursive-depth of {}. No further recursion will happen.\n", .{settings.max_recursion});
                    } else {
                        var newDest = dest.openDir(name, .{.iterate = true}) catch |err| switch (err) {
                            error.FileNotFound => blk : {
                                try dest.makeDir(name);
                                break :blk try dest.openDir(name, .{.iterate = true});
                            },
                            else => return err,
                        };
                        var innerTemplate = template.openDir(name, .{.iterate = true}) catch |err| switch (err) {
                            error.FileNotFound => {
                                unreachable; // the file name was found from looking at this file.
                            },
                            else => return err,
                        };

                        try copyDirRecursive(alloc, writer, newDest, innerTemplate, settings.increment_recursion());
                        newDest.close();
                        innerTemplate.close();
                    }
                },
                else => {
                    try writer.print("Unrecognized file type : <{s}> for file <{s}> inside the template folder.\nSkipping file\n", .{@tagName(kind), name});
                    try writer.flush();
                }
            }
        }

    } else {
        const options_in_dir = try getDirOptions(alloc, dest);
        var iter = template.iterate();
        var next = try iter.next();

        while (next != null) : (next = try iter.next()) {
            const name = next.?.name;
            const kind = next.?.kind;

            if (settings.use_sanitized) {
                if (thf.is_str_in_list_of_strs(name, &sanitize_ignore_filenames, true)) {
                    continue;
                }
            }

            switch (kind) {
                .file => {
                    if (thf.is_str_in_list_of_strs(name, options_in_dir, true)) {
                        try writer.print("The file <{s}> is already inside your directory. Skipping\n", .{name});
                        try writer.flush();
                    } else {
                        try std.fs.Dir.copyFile(template, name, dest, name, .{});
                    }
                },
                .directory => {
                    if (settings.cur_recursion >= settings.max_recursion) {
                        try writer.print("You have exceeded your max recursive-depth of {}. No further recursion will happen.\n", .{settings.max_recursion});
                    } else {
                        var newDest = dest.openDir(name, .{.iterate = true}) catch |err| switch (err) {
                            error.FileNotFound => blk : {
                                try dest.makeDir(name);
                                break :blk try dest.openDir(name, .{.iterate = true});
                            },
                            else => return err,
                        };
                        var innerTemplate = template.openDir(name, .{.iterate = true}) catch |err| switch (err) {
                            error.FileNotFound => {
                                unreachable; // the file name was found from looking at this file.
                            },
                            else => return err,
                        };

                        try copyDirRecursive(alloc, writer, newDest, innerTemplate, settings.increment_recursion());
                        newDest.close();
                        innerTemplate.close();
                    }
                },
                else => {
                    try writer.print("Unrecognized file type : <{s}> for file <{s}> inside the template folder.\nSkipping file\n", .{@tagName(kind), name});
                    try writer.flush();
                }
            }
        }
    }
}



pub fn getTemplateOptions(alloc : Allocator, cwd_path_assert : []const u8, template_folder_path : []const u8) ![][] u8 {
    
    const cwd_path = try std.process.getCwdAlloc(alloc);
    defer alloc.free(cwd_path);
    if (!thf.str_eql(cwd_path, cwd_path_assert, true)) unreachable;

    const mutual_refs = try ff.get_mutual_reference(alloc, cwd_path, template_folder_path, dividing_character);
    defer {
        alloc.free(mutual_refs[0]);
        alloc.free(mutual_refs[1]);
    }



    const cwd = std.fs.cwd();
    var chosen_dir = try cwd.openDir(mutual_refs[0], .{.iterate = true});
    defer chosen_dir.close();


    var iter = chosen_dir.iterate();
    var next_pos = try iter.next();
    var arr_list = try std.ArrayList([]u8).initCapacity(alloc, 4);
    while ( next_pos != null ) : (next_pos = try iter.next()) {

        const new_option = try alloc.alloc(u8, next_pos.?.name.len);
        @memcpy(new_option, next_pos.?.name);
        try arr_list.append(alloc, new_option);
    }

    arr_list.shrinkAndFree(alloc, arr_list.items.len);
    return arr_list.items;
}

pub fn getDirOptions(alloc : Allocator, dir : std.fs.Dir) ![][] u8 {
    var iter = dir.iterate();
    var next_pos = try iter.next();
    var arr_list = try std.ArrayList([]u8).initCapacity(alloc, 4);
    while ( next_pos != null ) : (next_pos = try iter.next()) {

        const new_option = try alloc.alloc(u8, next_pos.?.name.len);
        @memcpy(new_option, next_pos.?.name);
        try arr_list.append(alloc, new_option);
    }

    arr_list.shrinkAndFree(alloc, arr_list.items.len);
    return arr_list.items;
}

pub fn openAbsPath(alloc : Allocator, cwd_path_assert : []const u8, folderPath : []const u8) !std.fs.Dir {
    
    const cwd_path = try std.process.getCwdAlloc(alloc);
    defer alloc.free(cwd_path);
    if (!thf.str_eql(cwd_path, cwd_path_assert, true)) unreachable;
    const cwd = std.fs.cwd();


    const mutual_refs = try ff.get_mutual_reference(alloc, cwd_path, folderPath, dividing_character);
    defer {
        alloc.free(mutual_refs[0]);
        alloc.free(mutual_refs[1]);
    }
    const chosen_dir = try cwd.openDir(mutual_refs[0], .{.iterate = true});
    return chosen_dir;
}


// Print Screen : 

pub fn printHelpScreen(writer : *std.Io.Writer, app_name_raw : []const u8) !void {
    const app_name = if (cur_os == .windows) app_name_raw[1..app_name_raw.len-4] else app_name_raw;
    try writer.print("\n{s}; an alias for Z-init\nApp-Version : {s}:{}\n\n", .{app_name, version, version_patch});
    try writer.print(
        \\This is an application that allows for easy copy-pasting for folder templates.
        \\Ex. run `{s} -l` to see what options for templates you have.
        \\Then run `{s} template_name` to copy the files from inside the template to your current directory.
        \\
        ,
        .{app_name, app_name}
    );
    try writer.writeAll("\n\n");

    //help
    //replace
    //list
    //path
    //echo

    try printArgs(writer, &help_flags, "Prints out the help screen.\n");
    try printArgs(writer, &replace_flags, "Will overwrite existing files that have the same name as those inside the template.\n");
    try printArgsPro(writer, &add_flags, 
        \\ This will populate a new template. You will need to specify the desired name of the template. 
        \\          To remove an existing template and overwrite it you will need to specify the '-r' flag.
        \\          ex. `{s} -a new_template` will create a new template with the name of `new_template`.
        \\
        , .{app_name}
    );
    try printArgs(writer, &list_option_flags, "Will list the options that you have inside of your template folder\n");
    try printArgsPro(writer, &path_flags, " : Will list the path of {s} and the directory called {s} which holds, well, the templates\n", .{app_name, folder_holding_templates});
    try printArgs(writer, &sanitize_flags, "Will ignore certain files (zig-out, .zig-cache) when specified.\n");

    try writer.print("\nThere are 2 types of flags for this program single character flags ex. 'a' and multiple character flags ex. 'add'.\n", .{});
    try writer.print("To use a single-character flag you prefix it with `{s}`, to use a multiple character flag prefix it with `{s}`\n", .{flag_prefix, exclusive_flag_prefix});
    try writer.print("ex. `{s} {s}{s}` is the same as `{s} {s}{s}`\n", .{app_name, flag_prefix, list_option_flags[0], app_name, exclusive_flag_prefix, list_option_flags[1]});
    try writer.print("You can also combine single-character flags into one argument\n", .{});
    try writer.print("ex. `{s} {s}{s}{s}` is the same as `{0s} {s}{s} {4s}{s}`\n\n", .{
        app_name, flag_prefix, help_flags[0], list_option_flags[0], exclusive_flag_prefix, help_flags[2], list_option_flags[1]
    });

    try writer.flush();
}

pub fn printArgs(writer : *std.Io.Writer, args : []const []const u8, description : []const u8) !void {
    for (args, 0..) |arg, i| {
        if (i != args.len - 1) {
            try writer.print("{s}, ", .{arg});
        } else try writer.print("{s}", .{arg});
    }

    try writer.print(" : {s}", .{description});
}

pub fn printArgsPro(writer : *std.Io.Writer, args : []const []const u8, comptime str : []const u8, print_args : anytype) !void {
    for (args, 0..) |arg, i| {
        if (i != args.len - 1) {
            try writer.print("{s}, ", .{arg});
        } else try writer.print("{s}", .{arg});
    }

    try writer.print(" : ", .{});
    try writer.print(str, print_args);
}
