//===----------------------------------------------------------------------===//
//
// Weighted Instruction Frequency Analysis Pass
//
// Single-file approach: pass class + plugin registration in one file
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"    // <-- FIXED PATH for LLVM 22
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Format.h"
#include <map>
#include <string>

using namespace llvm;

namespace {

std::map<unsigned, unsigned> InstructionWeights = {
    {Instruction::Add,   1}, {Instruction::FAdd,  1},
    {Instruction::Sub,   1}, {Instruction::FSub,  1},
    {Instruction::Mul,   2}, {Instruction::FMul,  2},
    {Instruction::UDiv,  4}, {Instruction::SDiv,  4},
    {Instruction::FDiv,  4}, {Instruction::URem,  4},
    {Instruction::SRem,  4},
    {Instruction::Load,  3}, {Instruction::Store, 3},
    {Instruction::Alloca, 2},
    {Instruction::Call,  5}, {Instruction::Invoke, 5},
    {Instruction::ICmp, 1}, {Instruction::FCmp, 1},
    {Instruction::Shl,  1}, {Instruction::LShr, 1},
    {Instruction::AShr, 1}, {Instruction::And,  1},
    {Instruction::Or,   1}, {Instruction::Xor,  1},
    {Instruction::Trunc, 1}, {Instruction::ZExt, 1},
    {Instruction::SExt, 1}, {Instruction::FPToUI, 2},
    {Instruction::FPToSI, 2}, {Instruction::UIToFP, 2},
    {Instruction::SIToFP, 2}, {Instruction::FPTrunc, 2},
    {Instruction::FPExt, 2}, {Instruction::PtrToInt, 1},
    {Instruction::IntToPtr, 1}, {Instruction::BitCast, 1},
    {Instruction::AddrSpaceCast, 1},
    {Instruction::Br, 2}, {Instruction::Switch, 3},
    {Instruction::IndirectBr, 3},
    {Instruction::Ret, 1}, {Instruction::PHI, 1},
    {Instruction::Select, 1}, {Instruction::GetElementPtr, 1},
    {Instruction::AtomicRMW, 10}, {Instruction::AtomicCmpXchg, 10},
    {Instruction::ExtractElement, 2}, {Instruction::InsertElement, 2},
    {Instruction::ShuffleVector, 3}, {Instruction::ExtractValue, 1},
    {Instruction::InsertValue, 2}, {Instruction::LandingPad, 5},
    {Instruction::CatchPad, 5}, {Instruction::CleanupPad, 5},
    {Instruction::VAArg, 2},
};

const unsigned DEFAULT_WEIGHT = 1;

std::string getOpcodeName(unsigned Opcode) {
    switch (Opcode) {
        case Instruction::Add:   return "add";
        case Instruction::FAdd:  return "fadd";
        case Instruction::Sub:   return "sub";
        case Instruction::FSub:  return "fsub";
        case Instruction::Mul:   return "mul";
        case Instruction::FMul:  return "fmul";
        case Instruction::UDiv:  return "udiv";
        case Instruction::SDiv:  return "sdiv";
        case Instruction::FDiv:  return "fdiv";
        case Instruction::URem:  return "urem";
        case Instruction::SRem:  return "srem";
        case Instruction::Load:  return "load";
        case Instruction::Store: return "store";
        case Instruction::Alloca: return "alloca";
        case Instruction::Call:  return "call";
        case Instruction::Invoke: return "invoke";
        case Instruction::ICmp:  return "icmp";
        case Instruction::FCmp:  return "fcmp";
        case Instruction::Shl:   return "shl";
        case Instruction::LShr:  return "lshr";
        case Instruction::AShr:  return "ashr";
        case Instruction::And:   return "and";
        case Instruction::Or:    return "or";
        case Instruction::Xor:   return "xor";
        case Instruction::Trunc:  return "trunc";
        case Instruction::ZExt:   return "zext";
        case Instruction::SExt:   return "sext";
        case Instruction::FPToUI: return "fptoui";
        case Instruction::FPToSI: return "fptosi";
        case Instruction::UIToFP: return "uitofp";
        case Instruction::SIToFP: return "sitofp";
        case Instruction::FPTrunc: return "fptrunc";
        case Instruction::FPExt:   return "fpext";
        case Instruction::PtrToInt: return "ptrtoint";
        case Instruction::IntToPtr: return "inttoptr";
        case Instruction::BitCast:  return "bitcast";
        case Instruction::AddrSpaceCast: return "addrspacecast";
        case Instruction::Br:       return "br";
        case Instruction::Switch:   return "switch";
        case Instruction::IndirectBr: return "indirectbr";
        case Instruction::Ret:      return "ret";
        case Instruction::PHI:      return "phi";
        case Instruction::Select:   return "select";
        case Instruction::GetElementPtr: return "getelementptr";
        case Instruction::AtomicRMW:     return "atomicrmw";
        case Instruction::AtomicCmpXchg: return "cmpxchg";
        case Instruction::ExtractElement: return "extractelement";
        case Instruction::InsertElement:  return "insertelement";
        case Instruction::ShuffleVector:  return "shufflevector";
        case Instruction::ExtractValue:   return "extractvalue";
        case Instruction::InsertValue:    return "insertvalue";
        case Instruction::LandingPad:     return "landingpad";
        case Instruction::CatchPad:       return "catchpad";
        case Instruction::CleanupPad:     return "cleanuppad";
        case Instruction::VAArg:          return "vaarg";
        default: return "unknown(" + std::to_string(Opcode) + ")";
    }
}

unsigned getInstructionWeight(unsigned Opcode) {
    auto It = InstructionWeights.find(Opcode);
    if (It != InstructionWeights.end()) return It->second;
    return DEFAULT_WEIGHT;
}

} // end anonymous namespace

struct WeightedInstrFreqPass : public PassInfoMixin<WeightedInstrFreqPass> {
    
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM) {
        if (F.isDeclaration()) return PreservedAnalyses::all();
        
        std::map<unsigned, unsigned> OpcodeCounts;
        std::map<unsigned, unsigned> OpcodeCosts;
        unsigned TotalInstructions = 0;
        unsigned TotalWeightedCost = 0;
        
        for (BasicBlock &BB : F) {
            for (Instruction &I : BB) {
                unsigned Opcode = I.getOpcode();
                unsigned Weight = getInstructionWeight(Opcode);
                OpcodeCounts[Opcode]++;
                OpcodeCosts[Opcode] += Weight;
                TotalInstructions++;
                TotalWeightedCost += Weight;
            }
        }
        
        errs() << "\n";
        errs() << "=================================================\n";
        errs() << "  Weighted Instruction Frequency Analysis\n";
        errs() << "=================================================\n";
        errs() << "Function: " << F.getName() << "\n";
        errs() << "Total Instructions: " << TotalInstructions << "\n";
        errs() << "\n";
        errs() << "Instruction Frequency:\n";
        errs() << "  " << std::string(45, '-') << "\n";
        errs() << "  " << format("%-20s %10s %10s\n", "Instruction", "Count", "Cost");
        errs() << "  " << std::string(45, '-') << "\n";
        
        for (auto &Entry : OpcodeCounts) {
            unsigned Opcode = Entry.first;
            unsigned Count = Entry.second;
            unsigned Cost = OpcodeCosts[Opcode];
            std::string Name = getOpcodeName(Opcode);
            errs() << "  " << format("%-20s %10u %10u\n", Name.c_str(), Count, Cost);
        }
        errs() << "  " << std::string(45, '-') << "\n";
        
        unsigned MaxCost = 0;
        unsigned MaxOpcode = 0;
        for (auto &Entry : OpcodeCosts) {
            if (Entry.second > MaxCost) {
                MaxCost = Entry.second;
                MaxOpcode = Entry.first;
            }
        }
        
        errs() << "\n";
        errs() << "Total Weighted Cost: " << TotalWeightedCost << "\n";
        errs() << "\n";
        
        if (MaxCost > 0) {
            errs() << "Most Expensive Instruction Type: " 
                   << getOpcodeName(MaxOpcode) 
                   << " (cost: " << MaxCost << ")\n";
        } else {
            errs() << "Most Expensive Instruction Type: N/A (empty function)\n";
        }
        
        errs() << "=================================================\n";
        errs() << "\n";
        
        return PreservedAnalyses::all();
    }
    
    static bool isRequired() { return true; }
};

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