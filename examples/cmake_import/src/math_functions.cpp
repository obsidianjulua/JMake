#include <cmath>

extern "C" {
    double compute_distance(double x1, double y1, double x2, double y2) {
        double dx = x2 - x1;
        double dy = y2 - y1;
        return std::sqrt(dx*dx + dy*dy);
    }

    double compute_average(double* values, int count) {
        if (count == 0) return 0.0;

        double sum = 0.0;
        for (int i = 0; i < count; i++) {
            sum += values[i];
        }
        return sum / count;
    }
}
