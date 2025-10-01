#ifndef VECTOR_H
#define VECTOR_H

#ifdef __cplusplus
extern "C" {
#endif

// Vector operations
double vector_dot(const double* a, const double* b, int size);
void vector_add(const double* a, const double* b, double* result, int size);
void vector_scale(const double* a, double scalar, double* result, int size);
double vector_magnitude(const double* a, int size);

#ifdef __cplusplus
}
#endif

#endif // VECTOR_H
