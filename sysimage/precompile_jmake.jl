#!/usr/bin/env julia
# Precompilation statements for JMake
# This file helps PackageCompiler.jl create an optimized sysimage

using JMake

println("Running JMake precompilation...")

# Core initialization functions
JMake.info()
JMake.help()

# BuildBridge functions - command checking
JMake.BuildBridge.command_exists("gcc")
JMake.BuildBridge.command_exists("clang")
JMake.BuildBridge.command_exists("julia")
try
    JMake.BuildBridge.find_executable("gcc")
catch e
    # Expected to fail sometimes, that's ok
end

# JuliaWrapItUp core functions - identifier handling
JMake.JuliaWrapItUp.make_julia_identifier("test_function")
JMake.JuliaWrapItUp.make_julia_identifier("MyClass::method")
JMake.JuliaWrapItUp.make_julia_identifier("operator+")
JMake.JuliaWrapItUp.make_julia_identifier("123invalid")
JMake.JuliaWrapItUp.make_julia_identifier("while")  # reserved word

# Module name generation
JMake.JuliaWrapItUp.generate_module_name("testlib")
JMake.JuliaWrapItUp.generate_module_name("libmath")
JMake.JuliaWrapItUp.generate_module_name("lib_crypto_ssl")

# Binary type identification
JMake.JuliaWrapItUp.identify_binary_type("/usr/lib/libc.so")
JMake.JuliaWrapItUp.identify_binary_type("test.a")
JMake.JuliaWrapItUp.identify_binary_type("test.o")
JMake.JuliaWrapItUp.identify_binary_type("test.dylib")

# Configuration creation
wrapper_config = JMake.JuliaWrapItUp.create_default_wrapper_config()

# Type registry loading
type_registry = JMake.JuliaWrapItUp.load_type_registry(wrapper_config)

# Create a temporary wrapper config file for testing
temp_dir = mktempdir()
temp_config = joinpath(temp_dir, "test_wrapper_config.toml")
try
    JMake.JuliaWrapItUp.save_wrapper_config(wrapper_config, temp_config)

    # Now create a BinaryWrapper using the temporary config
    test_wrapper = JMake.JuliaWrapItUp.BinaryWrapper(temp_config)

    # Type inference with different types
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "int")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "void*")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "const char*")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "float")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "double")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "uint64_t")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "std::string")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "int*")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, "const int&")
    JMake.JuliaWrapItUp.infer_julia_type(test_wrapper, nothing)

catch e
    @warn "Wrapper instance creation skipped: $e"
finally
    rm(temp_dir, recursive=true, force=true)
end

# Symbol parsing - various C++ signatures
JMake.JuliaWrapItUp.parse_symbol_signature("myfunction(int, float)")
JMake.JuliaWrapItUp.parse_symbol_signature("std::vector<int>::push_back(int const&)")
JMake.JuliaWrapItUp.parse_symbol_signature("operator+(MyClass const&, MyClass const&)")
JMake.JuliaWrapItUp.parse_symbol_signature("simple_func")
JMake.JuliaWrapItUp.parse_symbol_signature("void function()")
JMake.JuliaWrapItUp.parse_symbol_signature("int* getPointer(const char*)")

# Parameter parsing
JMake.JuliaWrapItUp.parse_single_parameter("const int value")
JMake.JuliaWrapItUp.parse_single_parameter("float* ptr")
JMake.JuliaWrapItUp.parse_single_parameter("std::string&")
JMake.JuliaWrapItUp.parse_single_parameter("volatile int x")
JMake.JuliaWrapItUp.parse_single_parameter("double")

# Parameter list parsing
JMake.JuliaWrapItUp.parse_parameter_list("int a, float b, const char* c")
JMake.JuliaWrapItUp.parse_parameter_list("std::vector<int> v, std::map<std::string, int> m")
JMake.JuliaWrapItUp.parse_parameter_list("void")
JMake.JuliaWrapItUp.parse_parameter_list("")

# Templates functions
try
    JMake.Templates.detect_project_type([])
    JMake.Templates.detect_project_type(["main.cpp", "test.h"])
    JMake.Templates.detect_project_type(["main.c", "utils.c"])
catch e
    @warn "Template functions skipped: $e"
end

# Test isexecutable helper
try
    JMake.JuliaWrapItUp.isexecutable("/usr/bin/gcc")
    JMake.JuliaWrapItUp.isexecutable("/usr/lib/libc.so")
catch e
    # May fail on some systems
end

println("✅ Precompilation statements executed successfully")
