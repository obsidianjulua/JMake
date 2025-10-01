#!/bin/bash
# Complete example: C++ → Julia with UnifiedBridge

set -e

PROJECT_DIR="$HOME/my_cpp_project"
JMAKE_DIR="$HOME/.julia/julia/JMake"

echo "🚀 Setting up C++ → Julia compilation with UnifiedBridge"
echo "========================================================="

# 1. Create example C++ project
mkdir -p "$PROJECT_DIR/src" "$PROJECT_DIR/include"

cat > "$PROJECT_DIR/src/math_lib.cpp" <<'EOF'
#include "math_lib.h"
#include <cmath>

double fast_sqrt(double x) {
    return std::sqrt(x);
}

double fast_sin(double x) {
    return std::sin(x);
}

int add(int a, int b) {
    return a + b;
}
EOF

cat > "$PROJECT_DIR/include/math_lib.h" <<'EOF'
#pragma once

double fast_sqrt(double x);
double fast_sin(double x);
int add(int a, int b);
EOF

# 2. Create config
cat > "$PROJECT_DIR/bridge_llvm.toml" <<'EOF'
[project]
name = "MathLib"
root = "."

[paths]
source = "src"
output = "julia"
build = "build"
include = ["include"]

[bridge]
auto_discover = true
enable_learning = true

[compile]
flags = ["-O2", "-fPIC", "-std=c++17"]
walk_dependencies = true

[target]
cpu = "native"
opt_level = "O2"

[workflow]
stages = [
    "discover_tools",
    "walk_deps",
    "parse_ast",
    "compile_to_ir",
    "optimize_ir",
    "link_ir",
    "create_library",
    "extract_symbols",
    "generate_bindings"
]
EOF

# 3. Run compilation
cd "$PROJECT_DIR"
julia "$JMAKE_DIR/src/bridge_compiler.jl" compile bridge_llvm.toml

# 4. Show results
echo ""
echo "📊 Results:"
ls -lh julia/libMathLib.so
echo ""

# 5. Show learning stats
julia "$JMAKE_DIR/src/bridge_compiler.jl" stats

# 6. Test the generated Julia bindings
cat > test_mathlib.jl <<'EOF'
# Test generated bindings
include("julia/MathLib.jl")
using .MathLib

println("Testing MathLib...")
println("fast_sqrt(16.0) = ", fast_sqrt(16.0))
println("fast_sin(1.57) = ", fast_sin(1.57))
println("add(5, 3) = ", add(5, 3))
EOF

echo ""
echo "🧪 Running tests..."
julia test_mathlib.jl

echo ""
echo "✅ Complete! Your C++ is now callable from Julia."
echo "📁 Library: $PROJECT_DIR/julia/libMathLib.so"
echo "📝 Bindings: $PROJECT_DIR/julia/MathLib.jl"
