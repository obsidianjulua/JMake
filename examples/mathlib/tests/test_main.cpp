#include "../include/vector.h"
#include "../include/matrix.h"
#include "../include/statistics.h"
#include <iostream>
#include <iomanip>

int main() {
    std::cout << "MathLib Test Suite\n";
    std::cout << "==================\n\n";

    // Test vector operations
    std::cout << "Vector Operations:\n";
    double v1[] = {1.0, 2.0, 3.0};
    double v2[] = {4.0, 5.0, 6.0};
    double v_result[3];

    std::cout << "  Dot product: " << vector_dot(v1, v2, 3) << " (expected: 32)\n";

    vector_add(v1, v2, v_result, 3);
    std::cout << "  Vector add: [" << v_result[0] << ", " << v_result[1] << ", " << v_result[2] << "]\n";

    std::cout << "  Magnitude: " << vector_magnitude(v1, 3) << "\n\n";

    // Test matrix operations
    std::cout << "Matrix Operations:\n";
    double m1[] = {1.0, 2.0, 3.0, 4.0};  // 2x2
    double m2[] = {5.0, 6.0, 7.0, 8.0};  // 2x2
    double m_result[4];

    matrix_multiply(m1, m2, m_result, 2, 2, 2);
    std::cout << "  Matrix multiply result:\n";
    std::cout << "    [" << m_result[0] << ", " << m_result[1] << "]\n";
    std::cout << "    [" << m_result[2] << ", " << m_result[3] << "]\n";

    std::cout << "  Determinant: " << matrix_determinant_2x2(m1) << " (expected: -2)\n\n";

    // Test statistics
    std::cout << "Statistics:\n";
    double data[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    std::cout << "  Mean: " << mean(data, 5) << " (expected: 3)\n";
    std::cout << "  Variance: " << variance(data, 5) << " (expected: 2)\n";
    std::cout << "  Std Dev: " << std_deviation(data, 5) << "\n";

    double data_copy[] = {5.0, 1.0, 3.0, 2.0, 4.0};
    std::cout << "  Median: " << median(data_copy, 5) << " (expected: 3)\n";

    std::cout << "\n✅ All tests completed!\n";
    return 0;
}
