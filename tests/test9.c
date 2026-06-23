#include <stdio.h>

float calculate_discount(float price, int discount_percent) {
    if (discount_percent <= 0 || discount_percent > 100) {
        return price;
    }
    float discount = price * (discount_percent / 100.0f);
    return price - discount;
}

int main() {
    float price = 150.0f;
    float final_price = calculate_discount(price, 20);
    printf("Final price: %.2f\n", final_price);
    return 0;
}
