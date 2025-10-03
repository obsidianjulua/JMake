# JMake Documentation Setup with Documenter.jl

Complete setup for JMake documentation site with Documenter.jl.

---

## Installation

```bash
cd /path/to/JMake
julia --project=docs
```

```julia
# In Julia REPL
using Pkg
Pkg.add("Documenter")
Pkg.add("DocumenterTools")
exit()
```

---

## Directory Structure

```
JMake/
├── docs/
│   ├── make.jl                 # Build script
│   ├── Project.toml            # Docs dependencies
│   └── src/
│       ├── index.md            # Landing page
│       ├── quickstart.md       # 5-minute setup
│       ├── capabilities.md     # "I want to..." guide
│       ├── workflows.md        # Real coding patterns
│       ├── llvm_tools.md       # 137 LLVM tools reference
│       ├── daemon_architecture.md
│       ├── api/
│       │   ├── discovery.md
│       │   ├── setup.md
│       │   ├── compilation.md
│       │   ├── astwalker.md
│       │   ├── cmakeparser.md
│       │   ├── errorlearning.md
│       │   ├── llvmake.md
│       │   └── juliawrapitup.md
│       ├── examples/
│       │   ├── cmake_project.md
│       │   ├── incremental_workflow.md
│       │   ├── ir_inspection.md
│       │   ├── custom_optimization.md
│       │   └── wrapper_generation.md
│       └── advanced.md
```

---

## File: docs/Project.toml

```toml
[deps]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"

[compat]
Documenter = "1"
```

---

## File: docs/make.jl

```julia
using Documenter

# Push JMake modules to LOAD_PATH
push!(LOAD_PATH, "../src/")

# Import modules for API documentation
# Note: Comment out modules that don't exist yet
try
    using JMake
    using JMake.Discovery
    using JMake.ASTWalker
    using JMake.CMakeParser
    using JMake.ErrorLearning
    using JMake.LLVMake
    using JMake.JuliaWrapItUp
    using JMake.ConfigurationManager
catch e
    @warn "Some modules couldn't be loaded, continuing anyway" exception=e
end

makedocs(
    sitename = "JMake.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://yourusername.github.io/JMake.jl",
        assets = ["assets/custom.css"],
        collapselevel = 1,
    ),
    modules = [JMake],  # Add other modules here
    pages = [
        "Home" => "index.md",
        "Quick Start" => "quickstart.md",
        "Capabilities" => "capabilities.md",
        "Workflows" => "workflows.md",
        "LLVM Tools Reference" => "llvm_tools.md",
        "Architecture" => "daemon_architecture.md",
        "API Reference" =>