#!/usr/bin/env julia
# ErrorLearning.jl - Intelligent error pattern matching and fix suggestion
# Uses EngineT (BERT embeddings) for semantic error similarity

module ErrorLearning

using Dates
using LinearAlgebra
using JSON

# SQLite is required - try to load it
const SQLITE_AVAILABLE = Ref(false)
try
    @eval using SQLite
    SQLITE_AVAILABLE[] = true
catch e
    SQLITE_AVAILABLE[] = false
    @warn "SQLite not available. Install with: using Pkg; Pkg.add(\"SQLite\")"
end

# Optional dependency - gracefully handle if EngineT not available
const ENGINET_AVAILABLE = Ref(false)
const ENGINE_INSTANCE = Ref{Any}(nothing)

function __init__()
    try
        # Try to load EngineT
        @eval using EngineT
        ENGINE_INSTANCE[] = EngineT.Engine("bert-base-uncased")
        ENGINET_AVAILABLE[] = true
        @info "ErrorLearning: EngineT loaded successfully - semantic error matching enabled"
    catch e
        ENGINET_AVAILABLE[] = false
        @warn "ErrorLearning: EngineT not available - falling back to exact string matching" exception=e
    end
end

export ErrorDB, find_similar_error, suggest_fix, record_fix, export_knowledge,
       initialize_error_db, bootstrap_common_errors

# ============================================================================
# DATA STRUCTURES
# ============================================================================

"""
ErrorDB: Manages error patterns and their fixes with embeddings
"""
mutable struct ErrorDB
    db_path::String
    conn::Any  # SQLite connection
    use_embeddings::Bool

    function ErrorDB(db_path::String="jmake_errors.db")
        # Check if SQLite is available
        if !SQLITE_AVAILABLE[]
            error("SQLite package not available. Please install it with: using Pkg; Pkg.add(\"SQLite\")")
        end

        conn = SQLite.DB(db_path)

        # Initialize schema if needed
        initialize_schema(conn)

        use_embeddings = ENGINET_AVAILABLE[]

        @info "ErrorDB initialized at $db_path (embeddings: $use_embeddings)"

        return new(db_path, conn, use_embeddings)
    end
end

# ============================================================================
# DATABASE SCHEMA
# ============================================================================

"""
Initialize the error knowledge database schema
"""
function initialize_schema(conn)
    # Error patterns table
    SQLite.execute(conn, """
        CREATE TABLE IF NOT EXISTS error_patterns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            error_text TEXT NOT NULL,
            error_type TEXT,
            error_category TEXT,
            embedding BLOB,
            created_at TEXT NOT NULL,
            last_seen TEXT NOT NULL,
            occurrence_count INTEGER DEFAULT 1
        )
    """)

    # Fixes table (one error can have multiple fixes)
    SQLite.execute(conn, """
        CREATE TABLE IF NOT EXISTS error_fixes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            error_id INTEGER NOT NULL,
            fix_type TEXT NOT NULL,
            fix_description TEXT,
            fix_action TEXT NOT NULL,
            success_count INTEGER DEFAULT 0,
            failure_count INTEGER DEFAULT 0,
            confidence REAL DEFAULT 0.0,
            created_at TEXT NOT NULL,
            FOREIGN KEY(error_id) REFERENCES error_patterns(id)
        )
    """)

    # Fix history (track each application)
    SQLite.execute(conn, """
        CREATE TABLE IF NOT EXISTS fix_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            error_id INTEGER NOT NULL,
            fix_id INTEGER NOT NULL,
            applied_at TEXT NOT NULL,
            success INTEGER NOT NULL,
            project_path TEXT,
            error_context TEXT,
            FOREIGN KEY(error_id) REFERENCES error_patterns(id),
            FOREIGN KEY(fix_id) REFERENCES error_fixes(id)
        )
    """)

    # Indices for fast lookup
    SQLite.execute(conn, "CREATE INDEX IF NOT EXISTS idx_error_category ON error_patterns(error_category)")
    SQLite.execute(conn, "CREATE INDEX IF NOT EXISTS idx_error_type ON error_patterns(error_type)")
    SQLite.execute(conn, "CREATE INDEX IF NOT EXISTS idx_fix_confidence ON error_fixes(confidence DESC)")
end

# ============================================================================
# ERROR PATTERN DETECTION
# ============================================================================

"""
Classify error type from error text
"""
function classify_error(error_text::String)
    error_lower = lowercase(error_text)

    # C++ compilation errors
    if contains(error_lower, "undefined reference") || contains(error_lower, "unresolved external")
        return ("linker_error", "undefined_symbol")
    elseif contains(error_lower, "no such file") && contains(error_lower, ".h")
        return ("compiler_error", "missing_header")
    elseif contains(error_lower, "expected") && contains(error_lower, "before")
        return ("syntax_error", "syntax")
    elseif contains(error_lower, "undefined identifier") || contains(error_lower, "was not declared")
        return ("compiler_error", "undefined_identifier")

    # LLVM errors
    elseif contains(error_lower, "invalid ir") || contains(error_lower, "malformed ir")
        return ("llvm_error", "invalid_ir")
    elseif contains(error_lower, "optimization failed")
        return ("llvm_error", "optimization_failure")

    # Linker errors
    elseif contains(error_lower, "cannot find -l")
        return ("linker_error", "missing_library")
    elseif contains(error_lower, "relocation") && contains(error_lower, "pic")
        return ("linker_error", "missing_pic")

    # Build system errors
    elseif contains(error_lower, "permission denied")
        return ("system_error", "permissions")
    elseif contains(error_lower, "command not found")
        return ("system_error", "missing_tool")

    else
        return ("unknown_error", "general")
    end
end

"""
Extract key error information for better matching
"""
function extract_error_features(error_text::String)
    # Extract symbol names, file paths, line numbers
    features = Dict{String,Any}()

    # Extract symbols (common C++ identifiers)
    symbol_match = match(r"['\"]([a-zA-Z_][a-zA-Z0-9_:]*)['\"]", error_text)
    if symbol_match !== nothing
        features["symbol"] = symbol_match.captures[1]
    end

    # Extract file paths
    file_match = match(r"([a-zA-Z0-9_./]+\.(h|hpp|cpp|c|cc))", error_text)
    if file_match !== nothing
        features["file"] = file_match.captures[1]
    end

    # Extract line numbers
    line_match = match(r":(\d+):", error_text)
    if line_match !== nothing
        features["line"] = parse(Int, line_match.captures[1])
    end

    return features
end

# ============================================================================
# EMBEDDING AND SIMILARITY
# ============================================================================

"""
Get embedding vector for error text
"""
function get_error_embedding(error_text::String)
    if !ENGINET_AVAILABLE[]
        return nothing
    end

    try
        engine = ENGINE_INSTANCE[]
        if engine === nothing
            return nothing
        end
        # EngineT should already be loaded from __init__
        embedding = EngineT.get_embeddings(engine, error_text)
        return embedding
    catch e
        @warn "Failed to get embedding" exception=e
        return nothing
    end
end

"""
Calculate cosine similarity between two embeddings
"""
function embedding_similarity(emb1, emb2)
    if emb1 === nothing || emb2 === nothing
        return 0.0
    end

    return dot(emb1, emb2) / (norm(emb1) * norm(emb2))
end

"""
Deserialize embedding from BLOB
"""
function deserialize_embedding(blob)
    if blob === nothing || isempty(blob)
        return nothing
    end

    try
        # Convert BLOB to Float64 array
        n = div(length(blob), 8)  # 8 bytes per Float64
        return reinterpret(Float64, blob)[1:n]
    catch e
        @warn "Failed to deserialize embedding" exception=e
        return nothing
    end
end

"""
Serialize embedding to BLOB
"""
function serialize_embedding(embedding)
    if embedding === nothing
        return UInt8[]
    end

    return reinterpret(UInt8, Vector{Float64}(embedding))
end

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

"""
Find similar errors in the database
"""
function find_similar_error(db::ErrorDB, error_text::String; threshold::Float64=0.75, limit::Int=5)
    error_type, error_category = classify_error(error_text)
    query_embedding = get_error_embedding(error_text)

    # Query database for errors of similar type
    query = """
        SELECT id, error_text, error_type, error_category, embedding, occurrence_count
        FROM error_patterns
        WHERE error_category = ?
        ORDER BY occurrence_count DESC
        LIMIT 50
    """

    results = SQLite.DBInterface.execute(db.conn, query, (error_category,))

    similar_errors = []

    for row in results
        if db.use_embeddings && query_embedding !== nothing
            # Semantic similarity using embeddings
            stored_embedding = deserialize_embedding(row.embedding)
            similarity = embedding_similarity(query_embedding, stored_embedding)
        else
            # Fallback to string similarity
            similarity = simple_string_similarity(error_text, row.error_text)
        end

        if similarity >= threshold
            push!(similar_errors, (
                id = row.id,
                error_text = row.error_text,
                similarity = similarity,
                occurrence_count = row.occurrence_count,
                error_type = row.error_type,
                error_category = row.error_category
            ))
        end
    end

    # Sort by similarity and limit
    sort!(similar_errors, by = x -> x.similarity, rev=true)
    return similar_errors[1:min(limit, length(similar_errors))]
end

"""
Simple string similarity (fallback when embeddings unavailable)
"""
function simple_string_similarity(s1::String, s2::String)
    # Jaccard similarity on words
    words1 = Set(split(lowercase(s1)))
    words2 = Set(split(lowercase(s2)))

    intersection_size = length(intersect(words1, words2))
    union_size = length(Base.union(words1, words2))

    return union_size > 0 ? intersection_size / union_size : 0.0
end

"""
Suggest fixes for an error
"""
function suggest_fix(db::ErrorDB, error_text::String; confidence_threshold::Float64=0.6)
    # Find similar errors
    similar_errors = find_similar_error(db, error_text, threshold=confidence_threshold)

    if isempty(similar_errors)
        return []
    end

    # Get fixes for the most similar errors
    all_fixes = []

    for error in similar_errors
        query = """
            SELECT id, fix_type, fix_description, fix_action,
                   success_count, failure_count, confidence
            FROM error_fixes
            WHERE error_id = ?
            ORDER BY confidence DESC
        """

        fixes = SQLite.DBInterface.execute(db.conn, query, (error.id,))

        for fix in fixes
            # Weight confidence by error similarity
            weighted_confidence = fix.confidence * error.similarity

            push!(all_fixes, (
                fix_id = fix.id,
                error_id = error.id,
                fix_type = fix.fix_type,
                fix_description = fix.fix_description,
                fix_action = fix.fix_action,
                confidence = weighted_confidence,
                success_count = fix.success_count,
                failure_count = fix.failure_count,
                error_similarity = error.similarity
            ))
        end
    end

    # Sort by weighted confidence
    sort!(all_fixes, by = x -> x.confidence, rev=true)

    return all_fixes
end

"""
Record a fix (success or failure)
"""
function record_fix(db::ErrorDB, error_text::String, fix_action::String,
                   success::Bool; fix_type::String="config_change",
                   fix_description::String="", project_path::String="")
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")

    # Get or create error pattern
    error_type, error_category = classify_error(error_text)
    embedding = get_error_embedding(error_text)

    # Check if error exists
    existing = SQLite.DBInterface.execute(db.conn,
        "SELECT id FROM error_patterns WHERE error_text = ?", (error_text,))

    error_id = nothing
    for row in existing
        error_id = row.id
        break
    end

    if error_id === nothing
        # Insert new error pattern
        SQLite.execute(db.conn, """
            INSERT INTO error_patterns (error_text, error_type, error_category, embedding, created_at, last_seen)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (error_text, error_type, error_category, serialize_embedding(embedding), timestamp, timestamp))

        error_id = SQLite.last_insert_rowid(db.conn)
    else
        # Update last seen and count
        SQLite.execute(db.conn, """
            UPDATE error_patterns
            SET last_seen = ?, occurrence_count = occurrence_count + 1
            WHERE id = ?
        """, (timestamp, error_id))
    end

    # Check if fix exists for this error
    existing_fix = SQLite.DBInterface.execute(db.conn,
        "SELECT id FROM error_fixes WHERE error_id = ? AND fix_action = ?",
        (error_id, fix_action))

    fix_id = nothing
    for row in existing_fix
        fix_id = row.id
        break
    end

    if fix_id === nothing
        # Insert new fix
        SQLite.execute(db.conn, """
            INSERT INTO error_fixes (error_id, fix_type, fix_description, fix_action,
                                    success_count, failure_count, confidence, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (error_id, fix_type, fix_description, fix_action,
              success ? 1 : 0, success ? 0 : 1, success ? 1.0 : 0.0, timestamp))

        fix_id = SQLite.last_insert_rowid(db.conn)
    else
        # Update fix statistics
        if success
            SQLite.execute(db.conn, """
                UPDATE error_fixes
                SET success_count = success_count + 1,
                    confidence = CAST(success_count + 1 AS REAL) / (success_count + failure_count + 1)
                WHERE id = ?
            """, (fix_id,))
        else
            SQLite.execute(db.conn, """
                UPDATE error_fixes
                SET failure_count = failure_count + 1,
                    confidence = CAST(success_count AS REAL) / (success_count + failure_count + 1)
                WHERE id = ?
            """, (fix_id,))
        end
    end

    # Record in history
    SQLite.execute(db.conn, """
        INSERT INTO fix_history (error_id, fix_id, applied_at, success, project_path, error_context)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (error_id, fix_id, timestamp, success ? 1 : 0, project_path, error_text))

    @info "Recorded fix" error_id=error_id fix_id=fix_id success=success

    return (error_id=error_id, fix_id=fix_id)
end

"""
Export error knowledge to another database or JSON
"""
function export_knowledge(db::ErrorDB, output_path::String)
    # Export all errors and fixes
    errors_query = "SELECT * FROM error_patterns"
    fixes_query = "SELECT * FROM error_fixes"

    errors = SQLite.DBInterface.execute(db.conn, errors_query)
    fixes = SQLite.DBInterface.execute(db.conn, fixes_query)

    knowledge = Dict(
        "errors" => [Dict(pairs(row)) for row in errors],
        "fixes" => [Dict(pairs(row)) for row in fixes],
        "exported_at" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )

    open(output_path, "w") do io
        JSON.print(io, knowledge, 2)
    end

    @info "Knowledge exported to $output_path"
end

# ============================================================================
# BOOTSTRAP COMMON ERRORS
# ============================================================================

"""
Bootstrap database with common C++/LLVM error patterns
"""
function bootstrap_common_errors(db::ErrorDB)
    common_errors = [
        # Missing headers
        ("fatal error: iostream: No such file or directory",
         "add_include_dir", "Add standard library include directory",
         "flags += [\"-I/usr/include/c++/11\"]", "missing_header"),

        # Undefined reference
        ("undefined reference to `pthread_create'",
         "add_library", "Link pthread library",
         "libraries += [\"pthread\"]", "undefined_symbol"),

        # Missing -fPIC
        ("relocation R_X86_64_32 against `.rodata' can not be used when making a shared object; recompile with -fPIC",
         "add_flag", "Add -fPIC flag for shared library",
         "flags += [\"-fPIC\"]", "missing_pic"),

        # LLVM optimization
        ("Instruction does not dominate all uses!",
         "reduce_optimization", "Lower optimization level",
         "opt_level = \"O1\"", "optimization_failure"),

        # Missing library
        ("cannot find -lstdc++",
         "add_library", "Add standard C++ library",
         "libraries += [\"stdc++\"]", "missing_library"),

        # ABI issues
        ("undefined symbol: _ZNSt",
         "fix_abi", "C++ ABI mismatch - check compiler version",
         "flags += [\"-D_GLIBCXX_USE_CXX11_ABI=1\"]", "undefined_symbol"),

        # Template instantiation
        ("undefined reference to vtable",
         "fix_vtable", "Missing virtual function implementation",
         "Check for pure virtual functions without implementation", "undefined_symbol"),

        # Invalid IR
        ("Invalid bitcast",
         "fix_ir", "Type mismatch in LLVM IR",
         "flags += [\"-Wno-invalid-bitcast\"]", "invalid_ir"),
    ]

    @info "Bootstrapping with $(length(common_errors)) common error patterns..."

    for (error_text, fix_type, fix_desc, fix_action, category) in common_errors
        record_fix(db, error_text, fix_action, true,
                  fix_type=fix_type, fix_description=fix_desc)
    end

    @info "Bootstrap complete!"
end

end # module ErrorLearning
