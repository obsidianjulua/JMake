# Contributing to JMake

Thank you for your interest in contributing to JMake! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues

- **Bug Reports**: Open an issue with a clear description, steps to reproduce, and expected vs actual behavior
- **Feature Requests**: Describe the feature, use case, and why it would be valuable
- **Questions**: Feel free to ask questions in issues - we're happy to help!

### Development Setup

1. **Clone the repository:**
```bash
git clone <repo-url>
cd JMake
```

2. **Activate the project:**
```bash
julia --project=.
```

3. **Install dependencies:**
```julia
using Pkg
Pkg.instantiate()
```

4. **Test it works:**
```julia
using JMake
JMake.info()
```

### Project Structure

```
JMake/
├── src/
│   ├── JMake.jl              # Main module (entry point)
│   ├── BuildBridge.jl        # Command execution + error learning
│   ├── ErrorLearning.jl      # SQLite-based error tracking
│   ├── CMakeParser.jl        # CMake project import
│   ├── LLVMake.jl            # C++ → Julia compiler
│   ├── JuliaWrapItUp.jl      # Binary → Julia wrappers
│   └── Bridge_LLVM.jl        # Orchestrator
├── examples/                  # Example projects
│   ├── simple_math/          # Minimal C++ example
│   └── cmake_import/         # CMake import example
├── docs/                      # Documentation
│   ├── ERROR_LEARNING.md     # Error learning system
│   ├── FEATURES_ROADMAP.md   # Feature roadmap
│   └── BRIDGE_INTEGRATION.md # Integration guide
├── Project.toml               # Package metadata
└── jmake.toml                 # Default configuration
```

### Making Changes

1. **Create a branch:**
```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes:**
   - Follow Julia style conventions
   - Add docstrings to new functions
   - Keep code modular and testable

3. **Test your changes:**
```bash
# Test on the simple_math example
cd examples/simple_math
julia --project=../.. -e 'using JMake; JMake.compile()'
```

4. **Commit your changes:**
```bash
git add .
git commit -m "feat: add your feature description"
```

5. **Push and create a PR:**
```bash
git push origin feature/your-feature-name
```

### Code Style

- **Naming**:
  - Functions: `snake_case`
  - Types: `PascalCase`
  - Constants: `UPPER_CASE`
  - Modules: `PascalCase`

- **Documentation**:
  - Add docstrings for all exported functions
  - Include examples in docstrings
  - Keep comments concise and meaningful

- **Formatting**:
  - 4 spaces for indentation (no tabs)
  - Max line length: 92 characters (flexible for clarity)
  - Use `end` keywords aligned with their opening statement

### Example Contribution

**Adding a new feature:**

```julia
"""
    my_new_feature(config::CompilerConfig; option=default)

Brief description of what this does.

# Arguments
- `config::CompilerConfig`: The compiler configuration
- `option`: Optional parameter description

# Examples
```julia
config = load_config("jmake.toml")
result = my_new_feature(config)
```
"""
function my_new_feature(config::CompilerConfig; option=default)
    # Implementation
    return result
end
```

### Areas We Need Help

1. **Binding Generator Improvements**
   - Better C++ type inference
   - Template support
   - Class/struct handling

2. **Platform Support**
   - Windows support (currently Linux/macOS)
   - Cross-compilation improvements
   - Target platform detection

3. **Examples**
   - Real-world library examples
   - Complex C++ features (templates, namespaces, etc.)
   - Binary wrapping examples

4. **Documentation**
   - Tutorial content
   - Video walkthroughs
   - Best practices guide

5. **Testing**
   - Unit tests for each module
   - Integration tests
   - CI/CD pipeline

6. **Performance**
   - Parallel compilation
   - Caching improvements
   - Incremental builds

### Testing Guidelines

When adding new features:

1. **Create a test example** in `examples/`
2. **Verify it compiles** with `JMake.compile()`
3. **Test the generated bindings** with actual Julia code
4. **Document the example** in `examples/README.md`

### Pull Request Process

1. Update README.md if you change functionality
2. Add/update examples if relevant
3. Ensure all examples still compile
4. Write a clear PR description explaining:
   - What problem it solves
   - How it works
   - Any breaking changes

### Code Review

- Maintainers will review PRs and may request changes
- Please be patient - this is a volunteer project
- Address review comments promptly
- Once approved, we'll merge your contribution!

## Community Guidelines

- **Be respectful** and constructive
- **Help others** when you can
- **Share knowledge** - document your learnings
- **Ask questions** - no question is too basic

## Recognition

Contributors will be:
- Listed in the README
- Credited in release notes
- Thanked profusely! 🙏

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

## Questions?

- Open an issue for questions
- Tag it with `question` label
- We'll help you get started!

---

**Thank you for contributing to JMake!** 🚀

Together, we're revolutionizing Julia-C++ interop.
