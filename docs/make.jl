using Documenter

# Push JMake modules to LOAD_PATH
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

# Import modules for API documentation
using JMake

# Get all submodules that are actually exported
# Since JMake re-exports the modules, we can access them directly
modules_list = Module[JMake]

# Add submodules if they're available
for mod_name in [:LLVMEnvironment, :ConfigurationManager, :ASTWalker,
                  :Discovery, :ErrorLearning, :BuildBridge,
                  :CMakeParser, :LLVMake, :JuliaWrapItUp,
                  :ClangJLBridge, :DaemonManager]
    if isdefined(JMake, mod_name)
        push!(modules_list, getfield(JMake, mod_name))
    end
end

makedocs(
    sitename = "JMake.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://github.com/yourusername/JMake.jl",
        collapselevel = 1,
    ),
    modules = modules_list,
    pages = [
        "Home" => "index.md",
        "Getting Started" => [
            "guides/installation.md",
            "guides/quickstart.md",
            "guides/project_structure.md",
        ],
        "User Guide" => [
            "guides/cpp_compilation.md",
            "guides/binary_wrapping.md",
            "guides/cmake_import.md",
            "guides/daemon_system.md",
            "guides/testing_validation.md",
        ],
        "API Reference" => [
            "api/jmake.md",
            "api/llvm_environment.md",
            "api/configuration_manager.md",
            "api/discovery.md",
            "api/astwalker.md",
            "api/cmake_parser.md",
            "api/llvmake.md",
            "api/juliawrapitup.md",
            "api/build_bridge.md",
            "api/error_learning.md",
        ],
        "Examples" => [
            "examples/basic_cpp.md",
            "examples/cmake_project.md",
            "examples/wrapper_generation.md",
            "examples/error_learning.md",
        ],
        "Architecture" => [
            "architecture/overview.md",
            "architecture/daemon_architecture.md",
            "architecture/job_queue.md",
        ],
    ],
    checkdocs = :none,
    warnonly = [:missing_docs, :cross_references, :docs_block],
)

# Deploy documentation to gh-pages branch
deploydocs(
    repo = "github.com/yourusername/JMake.jl.git",
    devbranch = "main",
)
