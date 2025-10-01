#include "../include/statistics.h"
#include <cmath>
#include <algorithm>

extern "C" {

double mean(const double* data, int size) {
    if (size == 0) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < size; i++) {
        sum += data[i];
    }
    return sum / size;
}

double variance(const double* data, int size) {
    if (size == 0) return 0.0;

    double m = mean(data, size);
    double sum_sq = 0.0;
    for (int i = 0; i < size; i++) {
        double diff = data[i] - m;
        sum_sq += diff * diff;
    }
    return sum_sq / size;
}

double std_deviation(const double* data, int size) {
    return std::sqrt(variance(data, size));
}

double median(double* data, int size) {
    if (size == 0) return 0.0;

    std::sort(data, data + size);

    if (size % 2 == 0) {
        return (data[size/2 - 1] + data[size/2]) / 2.0;
    } else {
        return data[size/2];
    }
}

}
