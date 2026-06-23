#include <stdio.h>
#include <stdlib.h>

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

int main() {
    int *arr = (int *)malloc(5 * sizeof(int));
    for (int i = 0; i < 5; i++) {
        arr[i] = factorial(i + 1);
        printf("factorial(%d) = %d\n", i + 1, arr[i]);
    }
    free(arr);
    return 0;
}
