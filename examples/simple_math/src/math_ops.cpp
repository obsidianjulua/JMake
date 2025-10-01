#include <cmath>

extern "C" {
    double fast_sqrt(double x) {
        return std::sqrt(x);
    }

    double fast_sin(double x) {
        return std::sin(x);
    }

    double fast_pow(double base, double exp) {
        return std::pow(base, exp);
    }

    int add(int a, int b) {
        return a + b;
    }

    int multiply(int a, int b) {
        return a * b;
    }
}
