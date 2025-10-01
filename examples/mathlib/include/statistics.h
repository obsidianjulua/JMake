#ifndef STATISTICS_H
#define STATISTICS_H

#ifdef __cplusplus
extern "C" {
#endif

// Statistical operations
double mean(const double* data, int size);
double variance(const double* data, int size);
double std_deviation(const double* data, int size);
double median(double* data, int size);  // Note: modifies data (sorts it)

#ifdef __cplusplus
}
#endif

#endif // STATISTICS_H
