#!/usr/bin/env julia
# BuildBridge.jl - Simplified command execution for build systems
# Focus: Tool discovery, simple execution, compiler error handling

module BuildBridge

using Pkg

# ============================================================================
# SIMPLE COMMAND EXECUTION
# ============================================================================

"""
Execute command and capture output (stdout + stderr combined)
"""
function run_command(cmd::Cmd; capture_output::Bool=true)
    try
        if capture_output
            io = IOBuffer()
            pipeline(cmd, stdout=io, stderr=io) |> run
            return (String(take!(io)), 0)
        else
            run(cmd)
            return ("", 0)
        end
    catch e
        if isa(e, ProcessFailedException)
            # Get the error output
            io = IOBuffer()
            try
                pipeline(cmd, stdout=io, stderr=io) |> run
            catch
            end
            return (String(take!(io)), 1)
        else
            return ("Error: $e", 1)
        end
    end
end

"""
Execute command from string and arguments
"""
function execute(command::String, args::Vector{String}=String[]; capture_output::Bool=true)
    cmd = `$command $args`
    return run_command(cmd; capture_output=capture_output)
end

"""
Execute command and return only stdout (ignore errors)
"""
function capture(command::String, args::Vector{String}=String[])
    output, exitcode = execute(command, args)
    return exitcode == 0 ? output : ""
end

# ============================================================================
# TOOL DISCOVERY
# ============================================================================

"""
Find executable in PATH using Sys.which
"""
function find_executable(name::String)
    path = Sys.which(name)
    return path !== nothing ? path : ""
end

"""
Check if command exists in system
"""
function command_exists(name::String)
    return !isempty(find_executable(name))
end

"""
Discover LLVM/Clang toolchain
Returns Dict of tool_name => path
"""
function discover_llvm_tools(required_tools::Vector{String}=["clang", "clang++", "llvm-config"])
    tools = Dict{String,String}()

    for tool in required_tools
        if command_exists(tool)
            path = find_executable(tool)
            if !isempty(path)
                tools[tool] = path
            end
        end
    end

    return tools
end

# ============================================================================
# COMPILER ERROR HANDLING
# ============================================================================

"""
Storage for compiler error patterns and fixes
"""
mutable struct CompilerError
    pattern::Regex
    description::String
    fix_suggestion::String
    auto_fix::Union{Function,Nothing}
end

const ERROR_PATTERNS = CompilerError[
    CompilerError(
        r"error: no such file or directory",
        "Missing file or include path",
        "Check if the file exists or add -I flag for include directories",
        nothing
    ),
    CompilerError(
        r"undefined reference to",
        "Missing library or symbol",
        "Add missing library with -l flag or check linking order",
        nothing
    ),
    CompilerError(
        r"error: use of undeclared identifier",
        "Undeclared identifier",
        "Check if header is included or identifier is spelled correctly",
        nothing
    ),
    CompilerError(
        r"error: expected ';'",
        "Syntax error - missing semicolon",
        "Add missing semicolon in source code",
        nothing
    )
]

"""
Analyze compiler output for known error patterns
"""
function analyze_compiler_error(output::String)
    suggestions = String[]

    for error_pattern in ERROR_PATTERNS
        if occursin(error_pattern.pattern, output)
            push!(suggestions, "$(error_pattern.description): $(error_pattern.fix_suggestion)")
        end
    end

    return suggestions
end

"""
Execute compiler command with error analysis
"""
function compile_with_analysis(command::String, args::Vector{String})
    output, exitcode = execute(command, args)

    if exitcode != 0
        suggestions = analyze_compiler_error(output)
        return (output, exitcode, suggestions)
    end

    return (output, exitcode, String[])
end

# ============================================================================
# RETRY LOGIC
# ============================================================================

"""
Execute command with retry on failure
"""
function execute_with_retry(command::String, args::Vector{String}; max_retries::Int=3, delay::Float64=1.0)
    last_output = ""
    last_exitcode = 1

    for attempt in 1:max_retries
        output, exitcode = execute(command, args)

        if exitcode == 0
            return (output, exitcode, attempt)
        end

        last_output = output
        last_exitcode = exitcode

        if attempt < max_retries
            sleep(delay)
        end
    end

    return (last_output, last_exitcode, max_retries)
end

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

"""
Detect LLVM version from llvm-config
"""
function get_llvm_version()
    if command_exists("llvm-config")
        version_str = capture("llvm-config", ["--version"])
        return strip(version_str)
    end
    return "unknown"
end

"""
Get compiler information
"""
function get_compiler_info(compiler::String="clang++")
    if command_exists(compiler)
        info = capture(compiler, ["--version"])
        return strip(info)
    end
    return "unknown"
end

# ============================================================================
# EXPORTS
# ============================================================================

export
    # Command execution
    run_command,
    execute,
    capture,

    # Tool discovery
    find_executable,
    command_exists,
    discover_llvm_tools,

    # Compiler error handling
    analyze_compiler_error,
    compile_with_analysis,

    # Retry logic
    execute_with_retry,

    # Environment detection
    get_llvm_version,
    get_compiler_info

end # module BuildBridge
