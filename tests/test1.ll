; test1.ll - Simple arithmetic operations
; Expected: add=4, mul=2, sub=1

define i32 @simple_math(i32 %a, i32 %b) {
entry:
    %sum1 = add i32 %a, %b
    %sum2 = add i32 %sum1, 10
    %prod = mul i32 %sum2, %b
    %prod2 = mul i32 %prod, 2
    %diff = sub i32 %prod2, %a
    ret i32 %diff
}

define i32 @just_add(i32 %x, i32 %y) {
entry:
    %r1 = add i32 %x, %y
    %r2 = add i32 %r1, 5
    %r3 = add i32 %r2, 10
    ret i32 %r3
}