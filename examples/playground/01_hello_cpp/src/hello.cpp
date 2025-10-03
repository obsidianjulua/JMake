// hello.cpp - Your first JMake build! 
// This is about as simple as it gets - just add two numbers
// No fancy templates, no STL, just pure C++ goodness

extern "C" {
    // The "extern C" tells the compiler not to mangle the name
    // So Julia can easily find this function in the .so file
    
    int add(int a, int b) {
        // TODO: Make this more complicated? Nah, simple is beautiful.
        return a + b;
    }
    
    int multiply(int a, int b) {
        // Why write a loop when CPU has a MUL instruction?
        return a * b;
    }
    
    double divide(double a, double b) {
        // Note: No division by zero check because we live dangerously
        // (JK, Julia will catch it anyway)
        return a / b;
    }
    
    int fibonacci(int n) {
        // Classic fib - exponential time baby!
        // Don't use this for n > 40 unless you like waiting
        if (n <= 1) return n;
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}
