// Test file that will trigger "undefined reference to pthread_create" error
// This should be caught and fixed by ErrorLearning system

#include <iostream>
#include <pthread.h>

void* thread_function(void* arg) {
    std::cout << "Hello from thread!" << std::endl;
    return nullptr;
}

int main() {
    pthread_t thread;

    // This will cause linker error without -lpthread
    int result = pthread_create(&thread, nullptr, thread_function, nullptr);

    if (result == 0) {
        pthread_join(thread, nullptr);
        std::cout << "Thread completed successfully" << std::endl;
    }

    return 0;
}
