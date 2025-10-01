#!/usr/bin/env julia

"""
Unified Julia-Bash Language Server
Combines Julia and Bash LSP capabilities with shared symbol resolution
"""

using Pkg
using JSON3
using TOML

# Core LSP types
struct SymbolEntry
    name::String
    type::Symbol  # :julia_function, :bash_command, :system_binary, :builtin
    signature::String
    doc::String
    context::Symbol  # :julia, :bash, :system, :mixed
    parser_spec::Union{Dict, Nothing}
    handler::Union{Function, String, Nothing}
end

struct ExecutionContext
    language::Symbol  # :julia, :bash, :auto
    environment::Dict{String, String}
    working_dir::String
    variables::Dict{String, Any}
end

"""
Unified Language Server with Julia + Bash support
"""
mutable struct UnifiedLanguageServer
    # Symbol management
    symbol_table::Dict{String, SymbolEntry}
    context_stack::Vector{ExecutionContext}
    
    # Language processors
    julia_parser::Union{Nothing, Any}
    bash_parser::Union{Nothing, Any}
    
    # Configuration
    config::Dict{String, Any}
    
    # State
    running::Bool
    capabilities::Dict{String, Any}
    
    function UnifiedLanguageServer(config_file::String="unified_lsp.toml")
        config = load_config(config_file)
        
        server = new(
            Dict{String, SymbolEntry}(),
            [ExecutionContext(:auto, Dict{String, String}(), pwd(), Dict{String, Any}())],
            nothing,
            nothing,
            config,
            false,
            Dict{String, Any}()
        )
        
        initialize_server!(server)
        return server
    end
end

"""
Load server configuration
"""
function load_config(config_file::String)
    if !isfile(config_file)
        create_default_config(config_file)
    end
    
    return TOML.parsefile(config_file)
end

function create_default_config(config_file::String)
    config = """
    [server]
    port = 7000
    stdio = true
    log_level = "info"
    
    [julia]
    enable = true
    depot_path = "./depot"
    project_path = "."
    
    [bash]
    enable = true
    shell_path = "/bin/bash"
    completion_enabled = true
    
    [integration]
    auto_detect_context = true
    mixed_mode = true
    shared_variables = true
    
    [symbol_resolution]
    search_paths = [".", "/usr/bin", "/usr/local/bin"]
    include_system_commands = true
    include_julia_functions = true
    """
    
    open(config_file, "w") do f
        write(f, config)
    end
end

"""
Initialize the unified server
"""
function initialize_server!(server::UnifiedLanguageServer)
    println("🚀 Initializing Unified Julia-Bash Language Server")
    
    # Initialize symbol table
    populate_symbol_table!(server)
    
    # Set up capabilities
    server.capabilities = Dict(
        "textDocumentSync" => 1,
        "completionProvider" => Dict("triggerCharacters" => [".", "@", "$", "-"]),
        "hoverProvider" => true,
        "definitionProvider" => true,
        "executeCommandProvider" => Dict(
            "commands" => [
                "julia/eval",
                "bash/execute",
                "unified/context-switch",
                "unified/symbol-lookup",
                "unified/argument-parse"
            ]
        ),
        "workspaceSymbolProvider" => true
    )
    
    server.running = true
    println("✅ Server initialized with $(length(server.symbol_table)) symbols")
end

"""
Populate symbol table with Julia and Bash symbols
"""
function populate_symbol_table!(server::UnifiedLanguageServer)
    # Add Julia built-ins
    add_julia_symbols!(server)
    
    # Add Bash built-ins
    add_bash_symbols!(server)
    
    # Add system commands
    if server.config["symbol_resolution"]["include_system_commands"]
        add_system_symbols!(server)
    end
end

function add_julia_symbols!(server::UnifiedLanguageServer)
    # Core Julia functions
    julia_builtins = [
        ("println", ":julia_function", "println(args...)", "Print arguments with newline"),
        ("length", ":julia_function", "length(collection)", "Get length of collection"),
        ("push!", ":julia_function", "push!(collection, items...)", "Add items to collection"),
        ("map", ":julia_function", "map(f, collections...)", "Apply function to collections"),
        ("filter", ":julia_function", "filter(predicate, collection)", "Filter collection"),
        ("getopt", ":julia_function", "getopt(;from=ARGS)", "Parse command-line options"),
        ("getargs", ":julia_function", "getargs(stypes; from=ARGS)", "Parse command-line arguments")
    ]
    
    for (name, type, sig, doc) in julia_builtins
        server.symbol_table[name] = SymbolEntry(
            name, Symbol(type[2:end]), sig, doc, :julia, nothing, nothing
        )
    end
end

function add_bash_symbols!(server::UnifiedLanguageServer)
    # Core Bash commands and built-ins
    bash_builtins = [
        ("echo", ":bash_command", "echo [options] [string...]", "Display text"),
        ("cd", ":bash_command", "cd [directory]", "Change directory"),
        ("pwd", ":bash_command", "pwd", "Print working directory"),
        ("ls", ":bash_command", "ls [options] [files...]", "List files"),
        ("grep", ":bash_command", "grep [options] pattern [files...]", "Search patterns"),
        ("awk", ":bash_command", "awk 'program' [files...]", "Text processing"),
        ("sed", ":bash_command", "sed 'script' [files...]", "Stream editor"),
        ("find", ":bash_command", "find [path...] [expression]", "Search files"),
        ("export", ":bash_command", "export [name[=value]...]", "Export variables"),
        ("source", ":bash_command", "source filename [arguments]", "Execute commands from file")
    ]
    
    for (name, type, sig, doc) in bash_builtins
        server.symbol_table[name] = SymbolEntry(
            name, Symbol(type[2:end]), sig, doc, :bash, nothing, nothing
        )
    end
end

function add_system_symbols!(server::UnifiedLanguageServer)
    # Discover system commands
    search_paths = server.config["symbol_resolution"]["search_paths"]
    
    for path in search_paths
        if isdir(path)
            try
                for file in readdir(path)
                    full_path = joinpath(path, file)
                    if isfile(full_path) && isexecutable(full_path)
                        if !haskey(server.symbol_table, file)
                            server.symbol_table[file] = SymbolEntry(
                                file, :system_binary, "$file [args...]", 
                                "System command at $full_path", :system, nothing, full_path
                            )
                        end
                    end
                end
            catch
                continue
            end
        end
    end
end

"""
Context detection for mixed Julia/Bash input
"""
function detect_context(server::UnifiedLanguageServer, input::String)::Symbol
    input = strip(input)
    
    # Julia patterns
    julia_patterns = [
        r"^using\s+",
        r"^import\s+",
        r"^function\s+",
        r"^struct\s+",
        r"^module\s+",
        r"^\w+\s*=\s*\[.*\]",  # Array assignment
        r"^\w+\.\w+",          # Method calls
        r"^@\w+",              # Macros
        r"getopt|getargs"      # Argument parsing
    ]
    
    # Bash patterns  
    bash_patterns = [
        r"^#!/bin/bash",
        r"^\$\w+",             # Variables
        r"^export\s+",
        r"^source\s+",
        r"^if\s*\[.*\]\s*then",
        r"^for\s+\w+\s+in",
        r"^while\s*\[.*\]",
        r".*\|\s*\w+",         # Pipes
        r".*&&.*",             # Command chains
        r"^[a-zA-Z_][a-zA-Z0-9_-]*\s+[^=]*$"  # Command with args
    ]
    
    # Check Julia patterns
    for pattern in julia_patterns
        if occursin(pattern, input)
            return :julia
        end
    end
    
    # Check Bash patterns
    for pattern in bash_patterns
        if occursin(pattern, input)
            return :bash
        end
    end
    
    # Check if it's a known symbol
    words = split(input)
    if !isempty(words)
        first_word = words[1]
        if haskey(server.symbol_table, first_word)
            return server.symbol_table[first_word].context
        end
    end
    
    return :auto  # Let executor decide
end

"""
Unified argument parsing for both Julia and Bash
"""
function parse_unified_args(server::UnifiedLanguageServer, input::String, context::Symbol)
    if context == :julia
        return parse_julia_args(server, input)
    elseif context == :bash
        return parse_bash_args(server, input)
    else
        # Try both and return the more confident result
        julia_result = parse_julia_args(server, input)
        bash_result = parse_bash_args(server, input)
        
        # Simple heuristic: prefer the one with more parsed arguments
        if length(get(julia_result, "args", [])) >= length(get(bash_result, "args", []))
            return julia_result
        else
            return bash_result
        end
    end
end

function parse_julia_args(server::UnifiedLanguageServer, input::String)
    # Use the getopt.jl functionality from your groundwork
    # This is a simplified version - integrate with your actual getopt module
    
    parts = split(input)
    command = isempty(parts) ? "" : parts[1]
    args = length(parts) > 1 ? parts[2:end] : String[]
    
    parsed = Dict{String, Any}(
        "command" => command,
        "args" => args,
        "options" => Dict{String, Any}(),
        "positional" => String[],
        "parser" => "julia"
    )
    
    # Basic option parsing
    i = 1
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            # Long option
            if contains(arg, "=")
                key, value = split(arg[3:end], "=", limit=2)
                parsed["options"][key] = value
            else
                key = arg[3:end]
                if i < length(args) && !startswith(args[i+1], "-")
                    parsed["options"][key] = args[i+1]
                    i += 1
                else
                    parsed["options"][key] = true
                end
            end
        elseif startswith(arg, "-") && length(arg) > 1
            # Short option(s)
            for char in arg[2:end]
                parsed["options"][string(char)] = true
            end
        else
            # Positional argument
            push!(parsed["positional"], arg)
        end
        i += 1
    end
    
    return parsed
end

function parse_bash_args(server::UnifiedLanguageServer, input::String)
    # Bash-style argument parsing
    parts = split(input)
    command = isempty(parts) ? "" : parts[1]
    args = length(parts) > 1 ? parts[2:end] : String[]
    
    parsed = Dict{String, Any}(
        "command" => command,
        "args" => args,
        "variables" => Dict{String, String}(),
        "redirections" => String[],
        "pipes" => String[],
        "parser" => "bash"
    )
    
    # Parse bash-specific features
    for arg in args
        if startswith(arg, "\$")
            # Variable reference
            var_name = arg[2:end]
            parsed["variables"][var_name] = get(ENV, var_name, "")
        elseif contains(arg, ">") || contains(arg, "<")
            # Redirection
            push!(parsed["redirections"], arg)
        elseif arg == "|"
            # Pipe separator
            push!(parsed["pipes"], "|")
        end
    end
    
    return parsed
end

"""
Execute commands in the appropriate context
"""
function execute_unified(server::UnifiedLanguageServer, input::String)
    context = detect_context(server, input)
    parsed = parse_unified_args(server, input, context)
    
    try
        if context == :julia || parsed["parser"] == "julia"
            return execute_julia(server, parsed)
        elseif context == :bash || parsed["parser"] == "bash"
            return execute_bash(server, parsed)
        else
            # Mixed mode - try Julia first, fallback to bash
            try
                return execute_julia(server, parsed)
            catch
                return execute_bash(server, parsed)
            end
        end
    catch e
        return Dict("error" => string(e), "context" => context)
    end
end

function execute_julia(server::UnifiedLanguageServer, parsed::Dict)
    command = parsed["command"]
    
    if command == "getopt" || command == "getargs"
        # Handle argument parsing commands specially
        return handle_julia_argparse(server, parsed)
    else
        # Regular Julia evaluation
        julia_code = reconstruct_julia_code(parsed)
        result = eval(Meta.parse(julia_code))
        
        return Dict(
            "result" => string(result),
            "type" => string(typeof(result)),
            "context" => "julia",
            "success" => true
        )
    end
end

function execute_bash(server::UnifiedLanguageServer, parsed::Dict)
    command = parsed["command"]
    args = get(parsed, "args", String[])
    
    # Build bash command
    cmd_parts = [command]
    append!(cmd_parts, args)
    
    try
        # Execute bash command
        result = read(Cmd(cmd_parts), String)
        
        return Dict(
            "result" => result,
            "context" => "bash", 
            "success" => true,
            "exit_code" => 0
        )
    catch e
        return Dict(
            "error" => string(e),
            "context" => "bash",
            "success" => false
        )
    end
end

function handle_julia_argparse(server::UnifiedLanguageServer, parsed::Dict)
    # Integrate with your getopt.jl implementation
    # This would call into your existing argument parsing system
    
    return Dict(
        "message" => "Julia argument parsing integrated",
        "parsed" => parsed,
        "context" => "julia"
    )
end

function reconstruct_julia_code(parsed::Dict)
    # Reconstruct Julia code from parsed arguments
    command = parsed["command"]
    
    if haskey(parsed, "positional") && !isempty(parsed["positional"])
        args = join(parsed["positional"], ", ")
        return "$command($args)"
    else
        return command
    end
end

"""
LSP message handlers
"""
function handle_lsp_request(server::UnifiedLanguageServer, request::Dict)
    method = get(request, "method", "")
    params = get(request, "params", Dict())
    
    if method == "initialize"
        return handle_initialize(server, params)
    elseif method == "textDocument/completion"
        return handle_completion(server, params)
    elseif method == "textDocument/hover"
        return handle_hover(server, params)
    elseif method == "workspace/executeCommand"
        return handle_execute_command(server, params)
    elseif method == "workspace/symbol"
        return handle_workspace_symbol(server, params)
    else
        return Dict("error" => "Method not found: $method")
    end
end

function handle_initialize(server::UnifiedLanguageServer, params::Dict)
    return Dict(
        "capabilities" => server.capabilities,
        "serverInfo" => Dict(
            "name" => "Unified Julia-Bash Language Server",
            "version" => "1.0.0"
        )
    )
end

function handle_completion(server::UnifiedLanguageServer, params::Dict)
    # Extract text and position
    text = get(get(params, "textDocument", Dict()), "text", "")
    position = get(params, "position", Dict())
    
    # Get current line context
    lines = split(text, '\n')
    current_line = get(lines, get(position, "line", 0) + 1, "")
    
    # Detect context and provide appropriate completions
    context = detect_context(server, current_line)
    
    completions = []
    
    # Add symbol completions based on context
    for (name, symbol) in server.symbol_table
        if symbol.context == context || context == :auto
            push!(completions, Dict(
                "label" => name,
                "kind" => symbol.type == :julia_function ? 3 : 1,  # Function vs Text
                "detail" => symbol.signature,
                "documentation" => symbol.doc
            ))
        end
    end
    
    return Dict("items" => completions)
end

function handle_hover(server::UnifiedLanguageServer, params::Dict)
    # Extract word at position and provide hover info
    # This would integrate with your symbol table
    
    return Dict(
        "contents" => Dict(
            "kind" => "markdown",
            "value" => "Unified Julia-Bash Language Server hover support"
        )
    )
end

function handle_execute_command(server::UnifiedLanguageServer, params::Dict)
    command = get(params, "command", "")
    arguments = get(params, "arguments", [])
    
    if command == "julia/eval"
        code = isempty(arguments) ? "" : arguments[1]
        return execute_unified(server, code)
    elseif command == "bash/execute" 
        cmd = isempty(arguments) ? "" : arguments[1]
        return execute_unified(server, cmd)
    elseif command == "unified/context-switch"
        new_context = isempty(arguments) ? :auto : Symbol(arguments[1])
        server.context_stack[end] = ExecutionContext(
            new_context,
            server.context_stack[end].environment,
            server.context_stack[end].working_dir,
            server.context_stack[end].variables
        )
        return Dict("context" => new_context)
    elseif command == "unified/symbol-lookup"
        symbol_name = isempty(arguments) ? "" : arguments[1]
        if haskey(server.symbol_table, symbol_name)
            return Dict("symbol" => server.symbol_table[symbol_name])
        else
            return Dict("error" => "Symbol not found: $symbol_name")
        end
    elseif command == "unified/argument-parse"
        input = isempty(arguments) ? "" : arguments[1]
        context = length(arguments) > 1 ? Symbol(arguments[2]) : :auto
        return parse_unified_args(server, input, context)
    else
        return Dict("error" => "Unknown command: $command")
    end
end

function handle_workspace_symbol(server::UnifiedLanguageServer, params::Dict)
    query = get(params, "query", "")
    
    symbols = []
    for (name, symbol) in server.symbol_table
        if isempty(query) || contains(lowercase(name), lowercase(query))
            push!(symbols, Dict(
                "name" => name,
                "kind" => symbol.type == :julia_function ? 12 : 13,  # Function vs Variable
                "location" => Dict(
                    "uri" => "unified://symbols",
                    "range" => Dict(
                        "start" => Dict("line" => 0, "character" => 0),
                        "end" => Dict("line" => 0, "character" => length(name))
                    )
                )
            ))
        end
    end
    
    return symbols
end

"""
Main server loop
"""
function run_server(server::UnifiedLanguageServer)
    println("🌟 Unified Julia-Bash Language Server running")
    println("Symbol table: $(length(server.symbol_table)) entries")
    println("Capabilities: $(join(keys(server.capabilities), ", "))")
    
    while server.running
        try
            # Read LSP message (simplified - real implementation would handle JSON-RPC properly)
            input = readline()
            
            if isempty(input)
                continue
            end
            
            # Handle as direct command for testing
            result = execute_unified(server, input)
            println(JSON3.write(result))
            
        catch InterruptException
            println("\n👋 Shutting down server")
            server.running = false
        catch e
            println("❌ Error: $e")
        end
    end
end

"""
Entry point
"""
function main()
    if length(ARGS) > 0 && ARGS[1] == "--help"
        println("""
        Unified Julia-Bash Language Server
        
        Usage:
            julia unified_lsp.jl [config_file]
            
        The server provides:
        - Unified symbol resolution for Julia and Bash
        - Context-aware argument parsing
        - Cross-language completion and hover
        - Mixed-mode execution
        """)
        return
    end
    
    config_file = length(ARGS) > 0 ? ARGS[1] : "unified_lsp.toml"
    server = UnifiedLanguageServer(config_file)
    
    run_server(server)
end

# Utility function
function isexecutable(path::String)
    try
        if Sys.isunix()
            run(`test -x $path`)
            return true
        else
            return endswith(lowercase(path), ".exe")
        end
    catch
        return false
    end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end