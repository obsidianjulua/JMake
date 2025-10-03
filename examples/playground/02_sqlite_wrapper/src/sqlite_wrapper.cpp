// sqlite_wrapper.cpp - Because every build system needs a database example
// This shows you how to link external libraries (libsqlite3 in this case)

#include <sqlite3.h>
#include <string.h>

extern "C" {
    // Wrapper around sqlite3_open - returns database handle
    // Pro tip: Always check the return value in Julia!
    sqlite3* db_open(const char* filename) {
        sqlite3* db;
        int rc = sqlite3_open(filename, &db);
        if (rc != SQLITE_OK) {
            sqlite3_close(db);
            return nullptr;  // We're fancy, we use nullptr not NULL
        }
        return db;
    }
    
    // Execute SQL - fire and forget style
    // Returns 0 on success, error code otherwise
    int db_exec(sqlite3* db, const char* sql) {
        char* err_msg = nullptr;
        int rc = sqlite3_exec(db, sql, nullptr, nullptr, &err_msg);
        if (err_msg) {
            sqlite3_free(err_msg);  // Don't leak memory kids
        }
        return rc;
    }
    
    // Close the database like a responsible adult
    void db_close(sqlite3* db) {
        if (db) {
            sqlite3_close(db);
        }
    }
    
    // Get the last error message
    // (Because "something went wrong" is not a helpful error message)
    const char* db_error(sqlite3* db) {
        return sqlite3_errmsg(db);
    }
}
