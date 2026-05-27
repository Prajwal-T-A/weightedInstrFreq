#include "WeightedInstrFreq.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return {
        LLVM_PLUGIN_API_VERSION,
        "WeightedInstrFreqPass",
        LLVM_VERSION_STRING,
        [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                    if (Name == "weighted-instr-freq") {
                        FPM.addPass(WeightedInstrFreqPass());
                        return true;
                    }
                    return false;
                }
            );
            
            PB.registerOptimizerLastEPCallback(
                [](ModulePassManager &MPM, OptimizationLevel Level,
                   ThinOrFullLTOPhase Phase) {
                    if (Level == OptimizationLevel::O2 || 
                        Level == OptimizationLevel::O3) {
                        FunctionPassManager FPM;
                        FPM.addPass(WeightedInstrFreqPass());
                        MPM.addPass(createModuleToFunctionPassAdaptor(std::move(FPM)));
                    }
                }
            );
        }
    };
}