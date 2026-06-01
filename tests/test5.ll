; test5.ll — Floating-point intensive computation
; Tests: fadd, fsub, fmul, fdiv, fcmp, sitofp, fptosi
; Purpose: Show that floating-point instructions carry different weights
;          compared to integer arithmetic.

define double @dot_product(double %a0, double %a1, double %a2,
                            double %b0, double %b1, double %b2) {
entry:
    %m0 = fmul double %a0, %b0
    %m1 = fmul double %a1, %b1
    %m2 = fmul double %a2, %b2
    %s0 = fadd double %m0, %m1
    %s1 = fadd double %s0, %m2
    ret double %s1
}

define double @normalize_score(double %raw, double %min, double %max) {
entry:
    %range = fsub double %max, %min
    %shifted = fsub double %raw, %min
    %norm = fdiv double %shifted, %range
    %cmp = fcmp olt double %norm, 0.0
    %neg = fsub double 0.0, %norm
    %result = select i1 %cmp, double %neg, double %norm
    ret double %result
}

define i32 @float_to_int_round(double %x) {
entry:
    %half = fadd double %x, 0.5
    %i = fptosi double %half to i32
    ret i32 %i
}
