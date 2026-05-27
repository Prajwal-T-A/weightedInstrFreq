#include <stdio.h>

int compute(int a, int b) {
    int sum = a + b;
    int prod = sum * 2;
    int result = prod / 3;
    return result;
}

void swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

int main() {
    int x = 10, y = 20;
    swap(&x, &y);
    int r = compute(x, y);
    printf("Result: %d\n", r);
    return 0;
}
