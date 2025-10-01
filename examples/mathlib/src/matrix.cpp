#include "../include/matrix.h"

extern "C" {

void matrix_multiply(const double* a, const double* b, double* result, int rows_a, int cols_a, int cols_b) {
    for (int i = 0; i < rows_a; i++) {
        for (int j = 0; j < cols_b; j++) {
            result[i * cols_b + j] = 0.0;
            for (int k = 0; k < cols_a; k++) {
                result[i * cols_b + j] += a[i * cols_a + k] * b[k * cols_b + j];
            }
        }
    }
}

void matrix_transpose(const double* a, double* result, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            result[j * rows + i] = a[i * cols + j];
        }
    }
}

double matrix_determinant_2x2(const double* matrix) {
    return matrix[0] * matrix[3] - matrix[1] * matrix[2];
}

void matrix_identity(double* result, int size) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            result[i * size + j] = (i == j) ? 1.0 : 0.0;
        }
    }
}

}
