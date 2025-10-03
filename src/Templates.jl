#!/usr/bin/env julia
# Templates.jl - JMake Project Seed (Self-Destructing Plant File)
#
# USAGE: Copy this file anywhere, run it, and it:
#   1. Creates proper JMake directory structure
#   2. Writes a marker file (.jmake_project)
#   3. ERASES ITSELF
#
# After planting, the JMake toolchain handles everything:
#   - julia -e 'using JMake; JMake.discover()'  # Scans, walks AST, generates config
#   - julia -e 'using JMake; JMake.compile()'   # Builds the project

module Templates

function plant(target_dir::String=pwd())
    println("🌱 JMake Project Seed - Planting in: $target_dir")
    println("="^70)

    println("\n📁 Creating directory structure...")
    create_structure(target_dir)

    println("\n📝 Writing project marker...")
    write_marker(target_dir)

    println("\n🔥 Self-destructing...")
    self_destruct()

    println("\n✅ JMake project structure planted!")
    println("\n📂 Next steps:")
    println("   1. julia -e 'using JMake; JMake.discover()'")
    println("   2. julia -e 'using JMake; JMake.compile()'")
    println("="^70)
end

function create_structure(root_dir::String)
    structure = [
        "src", "include", "lib", "bin", "julia",
        "build", "build/ir", "build/linked", "build/obj",
        ".jmake_cache", "test", "docs"
    ]

    for dir in structure
        dir_path = joinpath(root_dir, dir)
        if !isdir(dir_path)
            mkpath(dir_path)
            println("  ✅ Created: $dir/")
        else
            println("  ⏭️  Exists:  $dir/")
        end
    end
end

function write_marker(root_dir::String)
    write(joinpath(root_dir, ".jmake_project"), """
    JMake Project - Directory structure created by Templates.jl
    
    Next: julia -e 'using JMake; JMake.discover()'
    LLVM: /home/grim/.julia/julia/JMake/LLVM
    """)
    println("  ✅ Created: .jmake_project")
end

function self_destruct()
    try
        rm(@__FILE__)
        println("  💥 Templates.jl erased")
    catch e
        @warn "Could not self-destruct: $e"
    end
end

export plant

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    Templates.plant(pwd())
end
