#ifndef MATRIX_H
#define MATRIX_H

#ifdef __cplusplus
extern "C" {
#endif

// Matrix operations (row-major order)
void matrix_multiply(const double* a, const double* b, double* result, int rows_a, int cols_a, int cols_b);
void matrix_transpose(const double* a, double* result, int rows, int cols);
double matrix_determinant_2x2(const double* matrix);
void matrix_identity(double* result, int size);

#ifdef __cplusplus
}
#endif

#endif // MATRIX_H
