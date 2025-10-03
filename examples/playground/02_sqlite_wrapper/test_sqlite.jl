#!/usr/bin/env julia
# test_sqlite.jl - Test SQLite wrapper
# Creates an in-memory database and does some CRUD operations

println("🧪 Testing SQLite wrapper")

lib_path = joinpath(@__DIR__, "julia", "lib.so")

if !isfile(lib_path)
    error("Library not found! Build it first.")
end

lib = Libc.Libdl.dlopen(lib_path)

# Get function pointers
db_open = Libc.Libdl.dlsym(lib, :db_open)
db_exec = Libc.Libdl.dlsym(lib, :db_exec)
db_close = Libc.Libdl.dlsym(lib, :db_close)
db_error = Libc.Libdl.dlsym(lib, :db_error)

# Open in-memory database (no file pollution!)
println("📂 Opening in-memory database...")
db = ccall(db_open, Ptr{Nothing}, (Cstring,), ":memory:")

if db == C_NULL
    error("Failed to open database")
end
println("✓ Database opened")

# Create a table
println("📊 Creating table...")
sql = "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
rc = ccall(db_exec, Int32, (Ptr{Nothing}, Cstring), db, sql)
@assert rc == 0 "Failed to create table"
println("✓ Table created")

# Insert some data
println("📝 Inserting data...")
sql = "INSERT INTO users (name, score) VALUES ('Alice', 100), ('Bob', 85), ('Charlie', 92)"
rc = ccall(db_exec, Int32, (Ptr{Nothing}, Cstring), db, sql)
@assert rc == 0 "Failed to insert data"
println("✓ Data inserted")

# Note: We can't easily SELECT with this simple wrapper
# But the important part is it compiles and links!
println("ℹ️  SELECT queries would need a more complex wrapper")

# Cleanup
println("🧹 Closing database...")
ccall(db_close, Nothing, (Ptr{Nothing},), db)
println("✓ Database closed")

Libc.Libdl.dlclose(lib)

println("\n🎉 SQLite wrapper works!")
println("💡 This example shows external library linking (libsqlite3)")
