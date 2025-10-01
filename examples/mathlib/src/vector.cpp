#include "../include/vector.h"
#include <cmath>

extern "C" {

double vector_dot(const double* a, const double* b, int size) {
    double result = 0.0;
    for (int i = 0; i < size; i++) {
        result += a[i] * b[i];
    }
    return result;
}

void vector_add(const double* a, const double* b, double* result, int size) {
    for (int i = 0; i < size; i++) {
        result[i] = a[i] + b[i];
    }
}

void vector_scale(const double* a, double scalar, double* result, int size) {
    for (int i = 0; i < size; i++) {
        result[i] = a[i] * scalar;
    }
}

double vector_magnitude(const double* a, int size) {
    double sum = 0.0;
    for (int i = 0; i < size; i++) {
        sum += a[i] * a[i];
    }
    return std::sqrt(sum);
}

}
