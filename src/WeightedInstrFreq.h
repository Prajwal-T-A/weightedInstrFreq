#ifndef WEIGHTED_INSTR_FREQ_H
#define WEIGHTED_INSTR_FREQ_H

#include "llvm/IR/PassManager.h"

namespace llvm {
    struct WeightedInstrFreqPass : public PassInfoMixin<WeightedInstrFreqPass> {
        PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
        static bool isRequired() { return true; }
    };
}

#endif