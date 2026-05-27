; test2.ll - Memory operations and function calls
; Tests load, store, call, alloca, gep

@global_var = global i32 42

declare i32 @external_func(i32)

define i32 @memory_test(i32* %ptr) {
entry:
    %local = alloca i32
    %val = load i32, i32* %ptr
    %gep = getelementptr i32, i32* %ptr, i32 1
    %val2 = load i32, i32* %gep
    %sum = add i32 %val, %val2
    store i32 %sum, i32* %local
    %result = call i32 @external_func(i32 %sum)
    ret i32 %result
}

define void @store_heavy(i32 %x, i32* %p1, i32* %p2, i32* %p3) {
entry:
    store i32 %x, i32* %p1
    store i32 %x, i32* %p2
    store i32 %x, i32* %p3
    %y = add i32 %x, 1
    store i32 %y, i32* %p1
    ret void
}