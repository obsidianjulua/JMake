#include <cstring>
#include <cctype>

extern "C" {
    int string_length(const char* str) {
        return strlen(str);
    }

    void to_uppercase(char* str) {
        for (int i = 0; str[i]; i++) {
            str[i] = toupper(str[i]);
        }
    }
}
