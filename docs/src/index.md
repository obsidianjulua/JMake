# JMake Documentation

Welcome to the documentation for JMake.jl!

JMake is a powerful, TOML-based build system for Julia projects that seamlessly integrates with LLVM and Clang. It's designed to simplify the process of generating Julia bindings from C++ source code and wrapping existing binary libraries, offering a robust solution for complex interlanguage interoperability.

## Strong Points & Key Features

*   **Deep LLVM/Clang Integration:** JMake leverages the full power of LLVM and Clang for advanced C++ compilation, analysis, and Julia bindings generation. This allows for fine-grained control over the build process and efficient code generation.
*   **Intelligent Error Learning System:** With its integrated `ErrorLearning` module, JMake can analyze compiler errors, learn from them, and even suggest fixes, significantly streamlining the debugging process for C++ projects.
*   **Persistent Daemons & Job Queue System:** JMake employs a system of persistent daemons (`DaemonManager`) to handle background tasks such such as compilation, dependency discovery, and other build-related operations. This ensures efficient resource utilization and a responsive development experience.
*   **CMake Project Integration:** Easily import existing CMake projects using the `CMakeParser` module, allowing JMake to understand and build complex C++ projects without requiring a full CMake build system.
*   **Flexible TOML-based Configuration:** All aspects of your build, from compiler flags to binding generation rules, are configured using simple and human-readable TOML files (`ConfigurationManager`), making project setup and maintenance straightforward.
*   **Advanced AST Analysis:** The `ASTWalker` module performs in-depth Abstract Syntax Tree (AST) analysis to understand code dependencies, which is crucial for efficient incremental builds and accurate binding generation.

## Getting Started: Easy API Calls

JMake provides a set of high-level functions for common tasks:

*   **`JMake.init(project_dir::String="."; type::Symbol=:cpp)`**
    Initialize a new JMake project with the appropriate directory structure.
    ```julia
    JMake.init("myproject")  # Initialize a C++ project
    JMake.init("mybindings", type=:binary)  # Initialize a binary wrapping project
    ```

*   **`JMake.compile(config_file::String="jmake.toml")`**
    Compile a C++ project to Julia bindings using the JMake system.
    ```julia
    JMake.compile()  # Use default jmake.toml
    JMake.compile("custom_config.toml")
    ```

*   **`JMake.wrap(config_file::String="wrapper_config.toml")`**
    Generate Julia wrappers for existing binary files based on a configuration.
    ```julia
    JMake.wrap()  # Use default wrapper_config.toml
    JMake.wrap("custom_wrapper.toml")
    ```

*   **`JMake.wrap_binary(binary_path::String; config_file::String="wrapper_config.toml")`**
    Wrap a specific binary file to Julia bindings.
    ```julia
    JMake.wrap_binary("/usr/lib/libmath.so")
    JMake.wrap_binary("./build/libmylib.so")
    ```

*   **`JMake.info()` and `JMake.help()`**
    Display general information about JMake or a command reference.
    ```julia
    JMake.info()
    JMake.help()
    ```

## Advanced Usage: Diving into the API

For more fine-grained control and advanced scenarios, you can interact with JMake's submodules and their specific functions.

### `JMake.JuliaWrapItUp` - Advanced Binary Wrapping

The `JuliaWrapItUp` submodule is at the core of JMake's binary wrapping capabilities. It provides tools to analyze binaries, extract symbols, and generate robust Julia wrappers.

*   **`JMake.JuliaWrapItUp.generate_wrappers(wrapper::BinaryWrapper)`**
    Generate Julia wrappers for all binaries defined in a `BinaryWrapper` configuration.
*   **`JMake.JuliaWrapItUp.scan_binaries(wrapper::BinaryWrapper)`**
    Scan the configured binary paths to discover available binaries and their properties.

### `JMake.LLVMake` - C++ Compilation and Julia Binding Generation

The `LLVMake` submodule handles the intricate process of compiling C++ code and generating Julia bindings using LLVM.

*   **`JMake.LLVMake.compile_project(config::CompilerConfig)`**
    Compiles the C++ project defined by the `CompilerConfig` and generates Julia bindings.

### Daemon Management

JMake's daemon system allows for background processing. You can control these daemons directly:

*   **`JMake.start_daemons(;project_root=pwd())`**
    Start all JMake daemon servers (discovery, setup, compilation, orchestrator).
    ```julia
    JMake.start_daemons()
    ```
*   **`JMake.stop_daemons()`**
    Stop all running JMake daemons gracefully.
    ```julia
    JMake.stop_daemons()
    ```
*   **`JMake.daemon_status()`**
    Display the current status of all JMake daemons.
    ```julia
    JMake.daemon_status()
    ```
*   **`JMake.ensure_daemons()`**
    Check if all daemons are running and restart any that have crashed.
    ```julia
    if !JMake.ensure_daemons()
        println("Some daemons failed to restart")
    end
    ```

### `JMake.import_cmake` - Integrating CMake Projects

*   **`JMake.import_cmake(cmake_file::String="CMakeLists.txt"; target::String="", output::String="jmake.toml")`**
    Import a CMake project and generate a `jmake.toml` configuration file from it.
    ```julia
    JMake.import_cmake("path/to/CMakeLists.txt")
    JMake.import_cmake("opencv/CMakeLists.txt", target="opencv_core")
    ```

### Project Discovery and Analysis

*   **`JMake.scan(path="."; generate_config=true, output="jmake.toml")`**
    Scan a directory, analyze its structure, and optionally generate a `jmake.toml` configuration.
    ```julia
    JMake.scan()  # Scan current directory
    JMake.scan("path/to/project", generate_config=false)
    ```
*   **`JMake.analyze(path=".")`**
    Analyze project structure and return detailed analysis results.
    ```julia
    result = JMake.analyze("path/to/project")
    println("Found \$(length(result[:scan_results].cpp_sources)) C++ files")
    ```

### Error Learning Database Export

*   **`JMake.export_errors(output_path::String="error_log.md")`**
    Export the error learning database to an Obsidian-friendly Markdown format.
    ```julia
    JMake.export_errors("docs/errors.md")
    ```

## Further Exploration

JMake is composed of several powerful submodules. For deeper customization and understanding, you can explore their individual functionalities:

*   `JMake.LLVMEnvironment`: Manage LLVM toolchains.
*   `JMake.ConfigurationManager`: Programmatic access to JMake configurations.
*   `JMake.ASTWalker`: Detailed C++ AST analysis.
*   `JMake.Discovery`: Project structure discovery.
*   `JMake.ErrorLearning`: Advanced error analysis and suggestion.
*   `JMake.BuildBridge`: Low-level build operations and command execution.
*   `JMake.ClangJLBridge`: Direct interaction with Clang.

This documentation provides a starting point. As you add more content to your `docs/src` directory, you can expand on these sections and create dedicated pages for each submodule and its functions.
