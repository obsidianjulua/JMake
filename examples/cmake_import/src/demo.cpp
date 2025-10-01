#include <iostream>

extern "C" {
    double compute_distance(double x1, double y1, double x2, double y2);
}

int main() {
    double dist = compute_distance(0.0, 0.0, 3.0, 4.0);
    std::cout << "Distance: " << dist << std::endl;
    return 0;
}
