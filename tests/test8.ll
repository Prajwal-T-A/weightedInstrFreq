define i32 @broken_math(i32 %a, i32 %b) {
entry:
  ; 'fakeop' is not a valid LLVM instruction
  %result = fakeop i32 %a, %b
  ret i32 %result
}
