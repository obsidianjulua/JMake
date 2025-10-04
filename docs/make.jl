using Documenter
using JMake # Assuming your main module is JMake

makedocs(
    sitename = "JMake Documentation",
    format = Documenter.HTML(),
    modules = [JMake],
    pages = [
        "Home" => "index.md",
        "Modules" => [
            "LLVMEnvironment" => "LLVMEnvironment.md",
            "ConfigurationManager" => "ConfigurationManager.md",
            "ASTWalker" => "ASTWalker.md",
            "Discovery" => "Discovery.md",
            "ErrorLearning" => "ErrorLearning.md",
            "BuildBridge" => "BuildBridge.md",
            "CMakeParser" => "CMakeParser.md",
            "LLVMake" => "LLVMake.md",
            "JuliaWrapItUp" => "JuliaWrapItUp.md",
            "ClangJLBridge" => "ClangJLBridge.md",
            "DaemonManager" => "DaemonManager.md",
        ]
    ],
    checkdocs = :none
)

deploydocs(
    repo = "github.com/obsidianjulua/JMake.jl.git", # Replace with your repository URL
    devbranch = "main", # Or "master"
)