#!/usr/bin/env julia
# BuildBridge.jl - Simplified command execution for build systems
# Focus: Tool discovery, simple execution, compiler error handling

module BuildBridge

using Pkg

# Load ErrorLearning module
include("ErrorLearning.jl")
using .ErrorLearning

# Global ErrorDB instance (lazy initialization)
const GLOBAL_ERROR_DB = Ref{Union{ErrorDB,Nothing}}(nothing)

"""
Get or initialize the global error database
"""
function get_error_db(db_path::String="jmake_errors.db")
    if GLOBAL_ERROR_DB[] === nothing
        GLOBAL_ERROR_DB[] = ErrorDB(db_path)
    end
    return GLOBAL_ERROR_DB[]
end

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

"""
Execute compiler command with intelligent error correction (uses ErrorLearning)
"""
function compile_with_learning(command::String, args::Vector{String};
                               max_retries::Int=3,
                               confidence_threshold::Float64=0.75,
                               db_path::String="jmake_errors.db",
                               project_path::String="",
                               config_modifier::Union{Function,Nothing}=nothing)
    db = get_error_db(db_path)

    for attempt in 1:max_retries
        output, exitcode = execute(command, args)

        if exitcode == 0
            @info "Compilation successful" attempt=attempt
            return (output, exitcode, attempt, String[])
        end

        # Compilation failed - try to find a fix
        @warn "Compilation failed (attempt $attempt/$max_retries)"
        println("Error output:\n$output")

        # Find similar errors and suggest fixes
        suggested_fixes = suggest_fix(db, output, confidence_threshold=confidence_threshold)

        if isempty(suggested_fixes)
            @warn "No known fixes found for this error"

            # Analyze with basic pattern matching as fallback
            basic_suggestions = analyze_compiler_error(output)

            return (output, exitcode, attempt, basic_suggestions)
        end

        # Try to apply the highest confidence fix
        best_fix = suggested_fixes[1]
        @info "Found potential fix" confidence=best_fix.confidence fix=best_fix.fix_description

        if best_fix.confidence >= confidence_threshold && config_modifier !== nothing
            @info "Applying automatic fix: $(best_fix.fix_action)"

            # Apply the fix (config_modifier is responsible for modifying the config)
            try
                success = config_modifier(best_fix.fix_action)

                if success
                    @info "Fix applied, retrying compilation..."
                    continue
                else
                    @warn "Failed to apply fix automatically"
                end
            catch e
                @warn "Error applying fix" exception=e
            end
        else
            # Just suggest the fix to the user
            suggestions = [
                "Suggested fix (confidence: $(round(best_fix.confidence, digits=2))): $(best_fix.fix_description)",
                "Action: $(best_fix.fix_action)"
            ]

            for (i, fix) in enumerate(suggested_fixes[2:min(3, length(suggested_fixes))])
                push!(suggestions, "Alternative $i (confidence: $(round(fix.confidence, digits=2))): $(fix.fix_description)")
            end

            return (output, exitcode, attempt, suggestions)
        end
    end

    # Max retries exceeded
    output, exitcode = execute(command, args)
    return (output, exitcode, max_retries, ["Max retry attempts exceeded"])
end

"""
Record the outcome of a fix attempt
"""
function record_compilation_fix(error_output::String, fix_action::String, success::Bool;
                                db_path::String="jmake_errors.db",
                                fix_type::String="config_change",
                                fix_description::String="",
                                project_path::String="")
    db = get_error_db(db_path)
    record_fix(db, error_output, fix_action, success,
              fix_type=fix_type,
              fix_description=fix_description,
              project_path=project_path)
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
    compile_with_learning,
    record_compilation_fix,

    # Error learning
    get_error_db,
    ErrorDB,
    find_similar_error,
    suggest_fix,
    record_fix,
    bootstrap_common_errors,

    # Retry logic
    execute_with_retry,

    # Environment detection
    get_llvm_version,
    get_compiler_info

end # module BuildBridge
