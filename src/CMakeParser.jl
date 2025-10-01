#!/usr/bin/env julia
# CMakeParser.jl - Parse CMakeLists.txt without running CMake
# Extract build configuration data and normalize it for JMake

module CMakeParser

using TOML

# ============================================================================
# DATA STRUCTURES
# ============================================================================

"""
Represents a CMake target (library or executable)
"""
mutable struct CMakeTarget
    name::String
    type::Symbol  # :executable, :static_library, :shared_library, :interface_library
    sources::Vector{String}
    include_dirs::Vector{String}
    compile_options::Vector{String}
    compile_definitions::Dict{String,String}
    link_libraries::Vector{String}
    properties::Dict{String,Any}
end

"""
Represents a parsed CMake project
"""
mutable struct CMakeProject
    project_name::String
    cmake_minimum_required::String
    root_dir::String
    targets::Dict{String,CMakeTarget}
    variables::Dict{String,String}
    subdirectories::Vector{String}
    find_packages::Vector{String}
end

# ============================================================================
# LEXER - Tokenize CMake commands
# ============================================================================

"""
Tokenize a CMake command line
Example: add_library(mylib SHARED foo.cpp bar.cpp)
  → ["add_library", "(", "mylib", "SHARED", "foo.cpp", "bar.cpp", ")"]
"""
function tokenize_line(line::AbstractString)
    tokens = String[]
    current = ""
    in_quotes = false
    in_parens = false

    for char in line
        if char == '"'
            in_quotes = !in_quotes
            if !in_quotes && !isempty(current)
                push!(tokens, current)
                current = ""
            end
        elseif char == '(' && !in_quotes
            if !isempty(current)
                push!(tokens, current)
                current = ""
            end
            push!(tokens, "(")
            in_parens = true
        elseif char == ')' && !in_quotes
            if !isempty(current)
                push!(tokens, current)
                current = ""
            end
            push!(tokens, ")")
            in_parens = false
        elseif isspace(char) && !in_quotes
            if !isempty(current)
                push!(tokens, current)
                current = ""
            end
        else
            current *= char
        end
    end

    if !isempty(current)
        push!(tokens, current)
    end

    return tokens
end

"""
Parse CMake command from tokens
Returns (command_name, args)
"""
function parse_command(tokens::Vector{String})
    if isempty(tokens)
        return ("", String[])
    end

    command = lowercase(tokens[1])
    args = String[]

    # Find opening paren
    paren_idx = findfirst(==("("), tokens)
    if paren_idx === nothing
        return (command, args)
    end

    # Extract arguments between parens
    close_paren = findlast(==(")"), tokens)
    if close_paren === nothing
        close_paren = length(tokens)
    end

    args = tokens[paren_idx+1:close_paren-1]

    return (command, args)
end

# ============================================================================
# PARSER - Extract CMake configuration
# ============================================================================

"""
Parse a CMakeLists.txt file
"""
function parse_cmake_file(filepath::String)
    if !isfile(filepath)
        error("CMakeLists.txt not found: $filepath")
    end

    # Get absolute path of the CMakeLists.txt directory
    root_dir = dirname(abspath(filepath))
    project = CMakeProject(
        "",  # project_name
        "",  # cmake_minimum_required
        root_dir,
        Dict{String,CMakeTarget}(),
        Dict{String,String}(),
        String[],
        String[]
    )

    lines = readlines(filepath)

    # Process each line
    for (line_num, line) in enumerate(lines)
        # Remove comments
        comment_idx = findfirst('#', line)
        if comment_idx !== nothing
            line = line[1:comment_idx-1]
        end

        line = strip(String(line))  # Convert SubString to String

        # Skip empty lines
        if isempty(line)
            continue
        end

        # Tokenize and parse
        tokens = tokenize_line(line)
        if isempty(tokens)
            continue
        end

        (command, args) = parse_command(tokens)

        # Process command
        process_cmake_command!(project, command, args, root_dir)
    end

    return project
end

"""
Process a single CMake command
"""
function process_cmake_command!(project::CMakeProject, command::String, args::Vector{String}, root_dir::String)
    if command == "project"
        # project(MyProject)
        if !isempty(args)
            project.project_name = args[1]
        end

    elseif command == "cmake_minimum_required"
        # cmake_minimum_required(VERSION 3.10)
        version_idx = findfirst(==("VERSION"), args)
        if version_idx !== nothing && version_idx < length(args)
            project.cmake_minimum_required = args[version_idx + 1]
        end

    elseif command == "set"
        # set(VAR_NAME value)
        if length(args) >= 2
            var_name = args[1]
            var_value = join(args[2:end], " ")
            project.variables[var_name] = var_value
        end

    elseif command == "add_library"
        # add_library(mylib SHARED foo.cpp bar.cpp)
        parse_add_library!(project, args, root_dir)

    elseif command == "add_executable"
        # add_executable(myapp main.cpp)
        parse_add_executable!(project, args, root_dir)

    elseif command == "target_sources"
        # target_sources(mylib PRIVATE foo.cpp bar.cpp)
        parse_target_sources!(project, args, root_dir)

    elseif command == "target_include_directories"
        # target_include_directories(mylib PUBLIC include)
        parse_target_include_directories!(project, args, root_dir)

    elseif command == "target_compile_options"
        # target_compile_options(mylib PRIVATE -O2 -Wall)
        parse_target_compile_options!(project, args)

    elseif command == "target_compile_definitions"
        # target_compile_definitions(mylib PRIVATE DEBUG=1)
        parse_target_compile_definitions!(project, args)

    elseif command == "target_link_libraries"
        # target_link_libraries(mylib pthread m)
        parse_target_link_libraries!(project, args)

    elseif command == "add_subdirectory"
        # add_subdirectory(subdir)
        if !isempty(args)
            push!(project.subdirectories, args[1])
        end

    elseif command == "find_package"
        # find_package(OpenCV REQUIRED)
        if !isempty(args)
            push!(project.find_packages, args[1])
        end
    end
end

"""
Parse add_library command
"""
function parse_add_library!(project::CMakeProject, args::Vector{String}, root_dir::String)
    if isempty(args)
        return
    end

    target_name = args[1]
    type = :static_library  # default
    sources = String[]

    i = 2
    while i <= length(args)
        arg = args[i]

        if arg == "SHARED"
            type = :shared_library
        elseif arg == "STATIC"
            type = :static_library
        elseif arg == "INTERFACE"
            type = :interface_library
        elseif arg in ["PUBLIC", "PRIVATE", "INTERFACE"]
            # Skip visibility keywords
        else
            # It's a source file
            source_path = resolve_path(arg, root_dir)
            push!(sources, source_path)
        end

        i += 1
    end

    target = CMakeTarget(
        target_name,
        type,
        sources,
        String[],
        String[],
        Dict{String,String}(),
        String[],
        Dict{String,Any}()
    )

    project.targets[target_name] = target
end

"""
Parse add_executable command
"""
function parse_add_executable!(project::CMakeProject, args::Vector{String}, root_dir::String)
    if isempty(args)
        return
    end

    target_name = args[1]
    sources = String[]

    for i in 2:length(args)
        if !(args[i] in ["PUBLIC", "PRIVATE", "INTERFACE"])
            source_path = resolve_path(args[i], root_dir)
            push!(sources, source_path)
        end
    end

    target = CMakeTarget(
        target_name,
        :executable,
        sources,
        String[],
        String[],
        Dict{String,String}(),
        String[],
        Dict{String,Any}()
    )

    project.targets[target_name] = target
end

"""
Parse target_sources command
"""
function parse_target_sources!(project::CMakeProject, args::Vector{String}, root_dir::String)
    if length(args) < 2
        return
    end

    target_name = args[1]
    if !haskey(project.targets, target_name)
        return
    end

    target = project.targets[target_name]

    for i in 2:length(args)
        if !(args[i] in ["PUBLIC", "PRIVATE", "INTERFACE"])
            source_path = resolve_path(args[i], root_dir)
            push!(target.sources, source_path)
        end
    end
end

"""
Parse target_include_directories command
"""
function parse_target_include_directories!(project::CMakeProject, args::Vector{String}, root_dir::String)
    if length(args) < 2
        return
    end

    target_name = args[1]
    if !haskey(project.targets, target_name)
        return
    end

    target = project.targets[target_name]

    for i in 2:length(args)
        if !(args[i] in ["PUBLIC", "PRIVATE", "INTERFACE"])
            include_path = resolve_path(args[i], root_dir)
            push!(target.include_dirs, include_path)
        end
    end
end

"""
Parse target_compile_options command
"""
function parse_target_compile_options!(project::CMakeProject, args::Vector{String})
    if length(args) < 2
        return
    end

    target_name = args[1]
    if !haskey(project.targets, target_name)
        return
    end

    target = project.targets[target_name]

    for i in 2:length(args)
        if !(args[i] in ["PUBLIC", "PRIVATE", "INTERFACE"])
            push!(target.compile_options, args[i])
        end
    end
end

"""
Parse target_compile_definitions command
"""
function parse_target_compile_definitions!(project::CMakeProject, args::Vector{String})
    if length(args) < 2
        return
    end

    target_name = args[1]
    if !haskey(project.targets, target_name)
        return
    end

    target = project.targets[target_name]

    for i in 2:length(args)
        arg = args[i]
        if !(arg in ["PUBLIC", "PRIVATE", "INTERFACE"])
            # Parse definition (e.g., "DEBUG=1" or "FEATURE")
            parts = split(arg, '=')
            if length(parts) == 2
                target.compile_definitions[parts[1]] = parts[2]
            else
                target.compile_definitions[arg] = "1"
            end
        end
    end
end

"""
Parse target_link_libraries command
"""
function parse_target_link_libraries!(project::CMakeProject, args::Vector{String})
    if length(args) < 2
        return
    end

    target_name = args[1]
    if !haskey(project.targets, target_name)
        return
    end

    target = project.targets[target_name]

    for i in 2:length(args)
        if !(args[i] in ["PUBLIC", "PRIVATE", "INTERFACE"])
            push!(target.link_libraries, args[i])
        end
    end
end

# ============================================================================
# UTILITIES
# ============================================================================

"""
Resolve relative paths relative to CMakeLists.txt directory
"""
function resolve_path(path::String, root_dir::String)
    # Handle CMake variables (basic support)
    path = replace(path, "\${CMAKE_CURRENT_SOURCE_DIR}" => root_dir)
    path = replace(path, "\${PROJECT_SOURCE_DIR}" => root_dir)
    path = replace(path, "\$ENV{HOME}" => get(ENV, "HOME", ""))

    # If path is already absolute, return as-is
    if isabspath(path)
        return path
    end

    # If root_dir is empty or path starts with /, join carefully
    if isempty(root_dir)
        # Try to get absolute path from current directory
        if startswith(path, "/")
            return path
        else
            return abspath(path)
        end
    end

    # Make relative path absolute by joining with root_dir
    path = joinpath(root_dir, path)

    # Normalize the path (remove . and ..)
    return abspath(path)
end

"""
Substitute CMake variables in a string
"""
function substitute_variables(str::String, variables::Dict{String,String})
    result = str
    for (var, value) in variables
        result = replace(result, "\${$var}" => value)
        result = replace(result, "\$($var)" => value)
    end
    return result
end

# ============================================================================
# CONVERSION TO JMAKE
# ============================================================================

"""
Convert CMakeProject to JMake jmake.toml configuration
"""
function to_jmake_config(cmake_project::CMakeProject, target_name::String="")
    if isempty(target_name)
        # Use first target if not specified
        if isempty(cmake_project.targets)
            error("No targets found in CMake project")
        end
        target_name = first(keys(cmake_project.targets))
    end

    if !haskey(cmake_project.targets, target_name)
        error("Target '$target_name' not found in CMake project")
    end

    target = cmake_project.targets[target_name]

    # Build jmake.toml structure
    config = Dict{String,Any}()

    # [project]
    config["project"] = Dict{String,Any}(
        "name" => target_name,
        "root" => cmake_project.root_dir
    )

    # [paths]
    # Determine source directory from source files
    source_dirs = unique([dirname(src) for src in target.sources])
    source_dir = isempty(source_dirs) ? "src" : source_dirs[1]

    config["paths"] = Dict{String,Any}(
        "source" => source_dir,
        "output" => "julia",
        "build" => "build"
    )

    # [compile]
    compile_config = Dict{String,Any}()

    if !isempty(target.include_dirs)
        compile_config["include_dirs"] = target.include_dirs
    end

    if !isempty(target.compile_options)
        # Filter out CMake-specific flags
        flags = filter(opt -> !startswith(opt, "-W"), target.compile_options)
        if !isempty(flags)
            compile_config["flags"] = flags
        end
    end

    if !isempty(target.compile_definitions)
        compile_config["defines"] = target.compile_definitions
    end

    # Add link libraries if present (important for executables)
    if !isempty(target.link_libraries)
        compile_config["link_libraries"] = target.link_libraries
    end

    config["compile"] = compile_config

    # [target]
    config["target"] = Dict{String,Any}(
        "triple" => "",
        "cpu" => "generic",
        "opt_level" => "O2",
        "lto" => false
    )

    # [bridge]
    config["bridge"] = Dict{String,Any}(
        "auto_discover" => true,
        "enable_learning" => true,
        "cache_tools" => true
    )

    # [workflow]
    # Choose workflow stages based on target type
    if target.type == :executable
        stages = [
            "discover_tools",
            "compile_to_ir",
            "link_ir",
            "optimize_ir",
            "create_executable"
        ]
    else
        stages = [
            "discover_tools",
            "compile_to_ir",
            "link_ir",
            "optimize_ir",
            "create_library",
            "extract_symbols"
        ]
    end

    config["workflow"] = Dict{String,Any}(
        "stages" => stages,
        "parallel" => true
    )

    # [cache]
    config["cache"] = Dict{String,Any}(
        "enabled" => true,
        "directory" => ".bridge_cache"
    )

    return config
end

"""
Write jmake.toml from CMakeProject
"""
function write_jmake_config(cmake_project::CMakeProject, target_name::String, output_path::String="jmake.toml")
    config = to_jmake_config(cmake_project, target_name)

    open(output_path, "w") do io
        TOML.print(io, config)
    end

    println("✅ Generated jmake.toml for target: $target_name")
    return output_path
end

# ============================================================================
# EXPORTS
# ============================================================================

export
    # Data structures
    CMakeProject,
    CMakeTarget,

    # Parsing
    parse_cmake_file,

    # Conversion
    to_jmake_config,
    write_jmake_config

end # module CMakeParser
