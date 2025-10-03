// vector_math.cpp - The implementation
#include "vector_math.h"
#include <cmath>

extern "C" {
    void vector_add(const double* a, const double* b, double* result, int n) {
        // Could use SIMD here but let's keep it simple
        // The compiler will probably auto-vectorize anyway
        for (int i = 0; i < n; i++) {
            result[i] = a[i] + b[i];
        }
    }
    
    double vector_dot(const double* a, const double* b, int n) {
        double sum = 0.0;
        for (int i = 0; i < n; i++) {
            sum += a[i] * b[i];
        }
        return sum;
    }
    
    double vector_magnitude(const double* v, int n) {
        // sqrt(v·v) - classic Pythagorean theorem generalized to n dimensions
        return std::sqrt(vector_dot(v, v, n));
    }
}
