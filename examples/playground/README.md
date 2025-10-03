# JMake Playground 🎮

**A fun testing ground for experimenting with JMake builds**

This directory contains small, working examples you can modify and build to learn JMake.

## Quick Start

```bash
cd examples/playground/01_hello_cpp
julia -e 'using JMake; JMake.discover(); JMake.compile()'
```

## Examples

### 01_hello_cpp - Your First Build
Simple C++ function that adds two numbers. Perfect for testing the basics.

### 02_sqlite_wrapper - Real Library Linking
Wrap SQLite3 database functions. Shows external library linking.

### 03_math_library - Multi-File Project
Small math library with multiple source files and headers.

## What You'll Learn

- How JMake discovers your code
- TOML configuration basics
- Compiling C++ to LLVM IR
- Linking shared libraries
- Calling C++ from Julia

## Tips & Tricks

💡 **Fast iteration:** After first build, just modify C++ and recompile
🔍 **Check the TOML:** `jmake.toml` shows what JMake discovered
🛠️ **Custom tools:** Specify different compilers in TOML if you want
🚀 **Daemon mode:** Start daemons for parallel builds (see /daemons/)

## When Things Go Wrong

- Missing tools? Check `config.llvm["tools"]` in TOML
- Path issues? All paths relative to `project.root` in TOML
- Build errors? Check `.jmake_cache/` for intermediate files

**REMEMBER:** The TOML is your source of truth. If something's wrong, check there first!

Happy hacking! 🚀
