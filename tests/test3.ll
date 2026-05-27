; test3.ll - Control flow with branches and PHI nodes

define i32 @factorial(i32 %n) {
entry:
    %cmp = icmp sle i32 %n, 1
    br i1 %cmp, label %return_one, label %recurse

return_one:
    ret i32 1

recurse:
    %n_minus_1 = sub i32 %n, 1
    %call = call i32 @factorial(i32 %n_minus_1)
    %result = mul i32 %n, %call
    ret i32 %result
}

define i32 @max_of_three(i32 %a, i32 %b, i32 %c) {
entry:
    %cmp1 = icmp sgt i32 %a, %b
    br i1 %cmp1, label %a_greater, label %b_greater_or_equal

a_greater:
    %cmp2 = icmp sgt i32 %a, %c
    br i1 %cmp2, label %return_a, label %return_c

b_greater_or_equal:
    %cmp3 = icmp sgt i32 %b, %c
    br i1 %cmp3, label %return_b, label %return_c

return_a:
    ret i32 %a

return_b:
    ret i32 %b

return_c:
    ret i32 %c
}