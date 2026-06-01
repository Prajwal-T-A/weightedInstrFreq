; test7.ll — Mixed workload: memory + calls + division (high-cost function)
; Tests: alloca, load, store, call, sdiv, udiv, getelementptr, phi, br
; Purpose: This represents a realistic "expensive" function that combines
;          memory traffic, integer division, and function calls.
;          Expected: call and load/store dominate the weighted cost.

declare i32 @abs(i32)
declare void @llvm.memset.p0i8.i64(i8*, i8, i64, i1)

define i32 @array_sum_normalized(i32* %arr, i32 %n) {
entry:
    %acc = alloca i32
    store i32 0, i32* %acc
    %cmp_init = icmp sle i32 %n, 0
    br i1 %cmp_init, label %done, label %loop

loop:
    %i = phi i32 [ 0, %entry ], [ %i_next, %loop ]
    %gep = getelementptr i32, i32* %arr, i32 %i
    %val = load i32, i32* %gep
    %abs_val = call i32 @abs(i32 %val)
    %cur = load i32, i32* %acc
    %new = add i32 %cur, %abs_val
    store i32 %new, i32* %acc
    %i_next = add i32 %i, 1
    %done_cmp = icmp slt i32 %i_next, %n
    br i1 %done_cmp, label %loop, label %done

done:
    %total = load i32, i32* %acc
    %result = sdiv i32 %total, %n
    ret i32 %result
}

define i32 @integer_divide_series(i32 %x) {
entry:
    %d1 = sdiv i32 %x,  2
    %d2 = udiv i32 %d1, 3
    %d3 = sdiv i32 %d2, 5
    %r1 = srem i32 %x,  7
    %r2 = urem i32 %d3, 11
    %res = add i32 %r1, %r2
    ret i32 %res
}
