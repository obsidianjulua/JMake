// vector_math.h - Because what's a programming tutorial without vectors?
#pragma once

extern "C" {
    // Add two vectors element-wise
    // Note: No bounds checking because we're living on the edge
    void vector_add(const double* a, const double* b, double* result, int n);
    
    // Dot product - returns a single number
    double vector_dot(const double* a, const double* b, int n);
    
    // Vector magnitude (L2 norm for the math nerds)
    double vector_magnitude(const double* v, int n);
}
