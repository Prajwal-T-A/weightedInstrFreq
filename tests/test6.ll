; test6.ll — Bitwise operations and integer type conversions
; Tests: and, or, xor, shl, lshr, ashr, trunc, zext, sext, icmp
; Purpose: Demonstrate that bitwise and cast instructions have lower weights
;          than memory or call instructions, yielding a low overall cost.

define i32 @bitwise_ops(i32 %a, i32 %b) {
entry:
    %and_r = and i32 %a, %b
    %or_r  = or  i32 %a, %b
    %xor_r = xor i32 %a, %b
    %shl_r = shl i32 %a, 2
    %lshr_r = lshr i32 %b, 1
    %ashr_r = ashr i32 %b, 3
    %sum1  = add i32 %and_r, %or_r
    %sum2  = add i32 %xor_r, %shl_r
    %sum3  = add i32 %lshr_r, %ashr_r
    %final = add i32 %sum1, %sum2
    %res   = add i32 %final, %sum3
    ret i32 %res
}

define i64 @type_conversions(i8 %byte, i16 %word) {
entry:
    %z8  = zext i8  %byte to i32
    %s16 = sext i16 %word to i32
    %sum = add  i32 %z8, %s16
    %ext = sext i32 %sum to i64
    ret i64 %ext
}

define i1 @compare_all(i32 %a, i32 %b, i32 %c) {
entry:
    %c1 = icmp slt i32 %a, %b
    %c2 = icmp sgt i32 %b, %c
    %c3 = icmp eq  i32 %a, %c
    %r1 = and i1 %c1, %c2
    %r2 = or  i1 %r1, %c3
    ret i1 %r2
}
