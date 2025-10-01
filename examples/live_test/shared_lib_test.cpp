// Test file that will trigger "recompile with -fPIC" error
// When trying to create a shared library without position-independent code

#include <iostream>

class MathUtils {
public:
    static int add(int a, int b) {
        return a + b;
    }

    static int multiply(int a, int b) {
        return a * b;
    }
};

extern "C" {
    int math_add(int a, int b) {
        return MathUtils::add(a, b);
    }

    int math_multiply(int a, int b) {
        return MathUtils::multiply(a, b);
    }
}
