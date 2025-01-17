import wso2/nballerina.err;
import wso2/nballerina.bir;
import wso2/nballerina.types as t;
import wso2/nballerina.print.llvm;

type BuildError err:Semantic|err:Unimplemented;

type Alignment 1|8;

// Pointer tagging
// JBUG #31394 would be better to use shifts for these
                     //1234567812345678
const TAG_FACTOR   = 0x0100000000000000;
const POINTER_MASK = 0x00ffffffffffffff;

const int TAG_MASK     = 0x1f * TAG_FACTOR;
const int TAG_NIL      = 0;
const int TAG_BOOLEAN  = t:UT_BOOLEAN * TAG_FACTOR;
const int TAG_INT      = t:UT_INT * TAG_FACTOR;
const int TAG_FLOAT    = t:UT_FLOAT * TAG_FACTOR;
const int TAG_STRING   = t:UT_STRING * TAG_FACTOR;
const int TAG_ERROR   = t:UT_ERROR * TAG_FACTOR;

const int TAG_LIST_RW  = t:UT_LIST_RW * TAG_FACTOR;

const int TAG_BASIC_TYPE_MASK = 0xf * TAG_FACTOR;
const int TAG_BASIC_TYPE_LIST = t:UT_LIST_RO * TAG_FACTOR;
const int TAG_BASIC_TYPE_MAPPING = t:UT_MAPPING_RO * TAG_FACTOR;

const int FLAG_IMMEDIATE = 0x20 * TAG_FACTOR;

const TAG_SHIFT = 56;

const HEAP_ADDR_SPACE = 1;
const ALIGN_HEAP = 8;

const LLVM_INT = "i64";
const LLVM_DOUBLE = "double";
const LLVM_BOOLEAN = "i1";
const LLVM_VOID = "void";

final llvm:PointerType LLVM_TAGGED_PTR = heapPointerType("i8");
final llvm:PointerType LLVM_NIL_TYPE = LLVM_TAGGED_PTR;
final llvm:PointerType LLVM_TAGGED_PTR_WITHOUT_ADDR_SPACE = llvm:pointerType("i8");

type ValueType llvm:IntegralType;

type DIBuilder llvm:DIBuilder;
type DISubprogram llvm:Metadata;
type DILocation llvm:Metadata;
type DIFile llvm:Metadata;
type DICompileUnit llvm:Metadata;
type DISubroutineType llvm:Metadata;

// A Repr is way of representing values.
// It's a mapping from a SemType to an LLVM type.

enum UniformBaseRepr {
    BASE_REPR_INT,
    BASE_REPR_FLOAT,
    BASE_REPR_BOOLEAN,
    BASE_REPR_ERROR
}

const BASE_REPR_VOID = "BASE_REPR_VOID";
const BASE_REPR_TAGGED = "BASE_REPR_TAGGED";
type BaseRepr UniformBaseRepr|BASE_REPR_TAGGED;
type RetBaseRepr BaseRepr|BASE_REPR_VOID;

type UniformRepr readonly & record {|
    UniformBaseRepr base;
    llvm:SingleValueType llvm;
    t:UniformTypeBitSet subtype?;
|};

// Maps any Ballerina value to a tagged pointer
type TaggedRepr readonly & record {|
    BaseRepr base;
    t:UniformTypeBitSet subtype;
    llvm:IntegralType llvm;
|};

type Repr UniformRepr|TaggedRepr;

type VoidRepr readonly & record {|
    BASE_REPR_VOID base;
    LLVM_VOID llvm;
|};

type RetRepr Repr|VoidRepr;

const PANIC_ARITHMETIC_OVERFLOW = 1;
const PANIC_DIVIDE_BY_ZERO = 2;
const PANIC_TYPE_CAST = 3;
const PANIC_STACK_OVERFLOW = 4;
const PANIC_INDEX_OUT_OF_BOUNDS = 5;
const PANIC_LIST_TOO_LONG = 6;
const PANIC_STRING_TOO_LONG = 7;
const PANIC_LIST_STORE = 8;
const PANIC_MAPPING_STORE = 9;

type PanicIndex PANIC_ARITHMETIC_OVERFLOW|PANIC_DIVIDE_BY_ZERO|PANIC_TYPE_CAST|PANIC_STACK_OVERFLOW|PANIC_INDEX_OUT_OF_BOUNDS;

type RuntimeFunctionName "panic"|"panic_construct"|"error_construct"|"alloc"|
                         "list_set"|"list_has_type"|
                         "mapping_set"|"mapping_get"|"mapping_init_member"|"mapping_construct"|"mapping_has_type"|
                         "int_to_tagged"|"tagged_to_int"|"float_to_tagged"|
                         "string_eq"|"string_cmp"|"string_concat"|"eq"|"exact_eq"|"float_eq"|"float_exact_eq"|"tagged_to_float"|"float_to_int";

type RuntimeFunction readonly & record {|
    RuntimeFunctionName name;
    llvm:FunctionType ty;
    llvm:EnumAttribute[] attrs;
|};

final RuntimeFunction panicFunction = {
    name: "panic",
    ty: {
        returnType: "void",
        paramTypes: [LLVM_TAGGED_PTR]
    },
    attrs: ["noreturn", "cold"]
};

final RuntimeFunction panicConstructFunction = {
    name: "panic_construct",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: ["i64"]
    },
    attrs: ["cold"]
};

final RuntimeFunction errorConstructFunction = {
    name: "error_construct",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: [LLVM_TAGGED_PTR, "i64"]
    },
    attrs: []
};

final RuntimeFunction allocFunction = {
    name: "alloc",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: ["i64"]
    },
    attrs: []
};

final RuntimeFunction listSetFunction = {
    name: "list_set",
    ty: {
        returnType: "i64",
        paramTypes: [LLVM_TAGGED_PTR, "i64", LLVM_TAGGED_PTR]
    },
    attrs: []
};

final RuntimeFunction listHasTypeFunction = {
    name: "list_has_type",
    ty: {
        returnType: "i1",
        paramTypes: [LLVM_TAGGED_PTR, "i64"]
    },
    attrs: ["readonly"]
};

final RuntimeFunction mappingSetFunction = {
    name: "mapping_set",
    ty: {
        returnType: "i64",
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: []
};

final RuntimeFunction mappingGetFunction = {
    name: "mapping_get",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: ["readonly"]
};

final RuntimeFunction mappingInitMemberFunction = {
    name: "mapping_init_member",
    ty: {
        returnType: REPR_VOID.llvm,
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: []
};

final RuntimeFunction mappingConstructFunction = {
    name: "mapping_construct",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: ["i64", "i64"]
    },
    attrs: []
};

final RuntimeFunction mappingHasTypeFunction = {
    name: "mapping_has_type",
    ty: {
        returnType: "i1",
        paramTypes: [LLVM_TAGGED_PTR, "i64"]
    },
    attrs: ["readonly"]
};

final RuntimeFunction intToTaggedFunction = {
    name: "int_to_tagged",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: ["i64"]
    },
    attrs: [] // NB not readonly because it allocates storage
};

final RuntimeFunction floatToTaggedFunction = {
    name: "float_to_tagged",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: ["double"]
    },
    attrs: [] // NB not readonly because it allocates storage
};

final RuntimeFunction floatToIntFunction = {
    name: "float_to_int",
    ty: {
        returnType: llvm:structType(["i64", "i1"]),
        paramTypes: ["double"]
    },
    attrs: ["nounwind", "readnone", "speculatable", "willreturn"]
};

final RuntimeFunction taggedToIntFunction = {
    name: "tagged_to_int",
    ty: {
        returnType: "i64",
        paramTypes: [LLVM_TAGGED_PTR]
    },
    attrs: ["readonly"]
};

final RuntimeFunction eqFunction = {
    name: "eq",
    ty: {
        returnType: "i1",
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: [["return", "zeroext"], "readonly"]
};

final RuntimeFunction exactEqFunction = {
    name: "exact_eq",
    ty: {
        returnType: "i1",
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: [["return", "zeroext"], "readonly"]
};

final RuntimeFunction taggedToFloatFunction = {
    name: "tagged_to_float",
    ty: {
        returnType: "double",
        paramTypes: [LLVM_TAGGED_PTR]
    },
    attrs: ["readonly"]
};

final RuntimeFunction floatEqFunction = {
    name: "float_eq",
    ty: {
        returnType: "i1",
        paramTypes:  ["double", "double"]
    },
    attrs: [["return", "zeroext"], "readonly"]
};

final RuntimeFunction floatExactEqFunction = {
    name: "float_exact_eq",
    ty: {
        returnType: "i1",
        paramTypes:  ["double", "double"]
    },
    attrs: [["return", "zeroext"], "readonly"]
};

final RuntimeFunction stringEqFunction = {
    name: "string_eq",
    ty: {
        returnType: "i1",
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: [["return", "zeroext"], "readonly"]
};

final RuntimeFunction stringCmpFunction = {
    name: "string_cmp",
    ty: {
        returnType: "i64",
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: ["readonly"]
};

final RuntimeFunction stringConcatFunction = {
    name: "string_concat",
    ty: {
        returnType: LLVM_TAGGED_PTR,
        paramTypes: [LLVM_TAGGED_PTR, LLVM_TAGGED_PTR]
    },
    attrs: []
};

final bir:ModuleId runtimeModule = {
    organization: "ballerinai",
    names: ["runtime"]
};

type ImportedFunction record {|
    readonly bir:ExternalSymbol symbol;
    llvm:FunctionDecl decl;
|};

type ImportedFunctionTable table<ImportedFunction> key(symbol);

//const STRING_VARIANT_SMALL = 0;
const STRING_VARIANT_MEDIUM = 0;
const STRING_VARIANT_LARGE = 1;

type StringVariant STRING_VARIANT_MEDIUM|STRING_VARIANT_LARGE; // STRING_VARIANT_SMALL|;

type StringDefn llvm:ConstPointerValue;

type Module record {|
    llvm:Context llContext;
    llvm:Module llMod;
    // LLVM functions in the module indexed by (unmangled) identifier within the module
    map<llvm:FunctionDefn> functionDefns;
     // List of all imported functions that have been added to the LLVM module
    ImportedFunctionTable importedFunctions = table [];
    llvm:PointerValue stackGuard;
    map<StringDefn> stringDefns = {};
    t:TypeCheckContext typeCheckContext;
    bir:Module bir;
    bir:File[] partFiles;
    ModuleDI? di;
|};

type ModuleDI record {|
    DIBuilder builder;
    DIFile[] files;
    DICompileUnit compileUnit;
    DISubroutineType funcType;
|};


class Scaffold {
    private final Module mod;
    private final bir:File file;
    private final llvm:FunctionDefn llFunc;
    private final DISubprogram? diFunc;

    // Representation for each BIR register
    private final Repr[] reprs;
    private final RetRepr retRepr;
    // LLVM ValueRef referring to address (allocated with alloca)
    // of each BIR register
    private final llvm:PointerValue[] addresses;
    // LLVM basic blocks indexed by BIR label
    private final llvm:BasicBlock[] blocks;
    private bir:Label? onPanicLabel = ();
    private final bir:BasicBlock[] birBlocks;
    private final int nParams;

    function init(Module mod, llvm:FunctionDefn llFunc, DISubprogram? diFunc, llvm:Builder builder, bir:FunctionDefn defn, bir:FunctionCode code) returns BuildError? {
        self.mod = mod;
        self.file = mod.partFiles[defn.partIndex];
        self.llFunc = llFunc;
        self.diFunc = diFunc;
        self.birBlocks = code.blocks;
        final Repr[] reprs = from var reg in code.registers select check semTypeRepr(reg.semType);
        self.reprs = reprs;
        self.retRepr = check semTypeRetRepr(defn.signature.returnType);
        self.nParams = defn.signature.paramTypes.length();
        llvm:BasicBlock entry = llFunc.appendBasicBlock();

        self.blocks = from var b in code.blocks select llFunc.appendBasicBlock(b.name);

        builder.positionAtEnd(entry);
        self.addresses = [];
        foreach int i in 0 ..< reprs.length() {
            self.addresses.push(builder.alloca(reprs[i].llvm, (), code.registers[i].varName));
        } 
    }

    function saveParams(llvm:Builder builder) {
         foreach int i in 0 ..< self.nParams {
            builder.store(self.llFunc.getParam(i), self.addresses[i]);
        }
    }

    function address(bir:Register r) returns llvm:PointerValue => self.addresses[r.number];
       
    function basicBlock(int label) returns llvm:BasicBlock  => self.blocks[label];

    function getRepr(bir:Register r) returns Repr => self.reprs[r.number];

    function getRetRepr() returns RetRepr => self.retRepr;

    function getFunctionDefn(string name) returns llvm:FunctionDefn => self.mod.functionDefns.get(name);

    function getModule() returns llvm:Module => self.mod.llMod;

    function stackGuard() returns llvm:PointerValue => self.mod.stackGuard;

    function getImportedFunction(bir:ExternalSymbol symbol) returns llvm:FunctionDecl? {
        ImportedFunction? fn = self.mod.importedFunctions[symbol];
        return fn is () ? () : fn.decl;
    }
    
    function addImportedFunction(bir:ExternalSymbol symbol, llvm:FunctionDecl decl) {
        self.mod.importedFunctions.add({symbol, decl});
    }

    function getIntrinsicFunction(llvm:IntrinsicFunctionName name) returns llvm:FunctionDecl {
        return self.mod.llMod.getIntrinsicDeclaration(name);
    }

    function getString(string str) returns StringDefn|BuildError {
        StringDefn? curDefn = self.mod.stringDefns[str];
        if !(curDefn is ()) {
            return curDefn;
        }
        StringDefn newDefn = check addStringDefn(self.mod.llContext, self.mod.llMod, self.mod.stringDefns.length(), str);
        self.mod.stringDefns[str] = newDefn;
        return newDefn;
    }

    function addBasicBlock() returns llvm:BasicBlock {
        return self.llFunc.appendBasicBlock();
    }

    function setBasicBlock(bir:BasicBlock block) {
        self.onPanicLabel = block.onPanic;
    }

    function getOnPanic() returns llvm:BasicBlock {
        return self.blocks[<bir:Label>self.onPanicLabel];
    }

    function panicAddress() returns llvm:PointerValue {
        bir:Insn catchInsn = self.birBlocks[<bir:Label>self.onPanicLabel].insns[0];
        return self.address((<bir:CatchInsn>catchInsn).result);
    }

    function lineNumber(bir:Position pos) returns int {
       return self.file.lineColumn(pos)[0];
    }

    function typeCheckContext() returns t:TypeCheckContext => self.mod.typeCheckContext;

    function location(bir:Position pos) returns err:Location {
        return err:location(self.file, pos);
    }

    function setDebugLocation(llvm:Builder builder, bir:Position pos) {
        DISubprogram? diFunc = self.diFunc;
        if !(diFunc is ()) {           
            var [line, column] = self.file.lineColumn(pos);
            ModuleDI di = <ModuleDI>self.mod.di;
            builder.setCurrentDebugLocation(di.builder.createDebugLocation(self.mod.llContext, line, column, self.diFunc));
        }
    }

    function clearDebugLocation(llvm:Builder builder) {
        if !(self.diFunc is ()) {
            builder.setCurrentDebugLocation(());
        }
    }
}

public function buildModule(bir:Module birMod, llvm:Context llContext, *Options options) returns llvm:Module|BuildError {
    bir:ModuleId modId = birMod.getId();
    llvm:Module llMod = llContext.createModule();
    bir:File[] partFiles = birMod.getPartFiles();
    ModuleDI? di = ();
    if options.debugLevel > 0 {
        di = createModuleDI(llMod, partFiles);
    } 
    bir:FunctionDefn[] functionDefns = birMod.getFunctionDefns();
    llvm:FunctionDefn[] llFuncs = [];
    DISubprogram[] diFuncs = [];
    llvm:FunctionType[] llFuncTypes = [];
    map<llvm:FunctionDefn> llFuncMap = {};
    foreach var defn in functionDefns {
        llvm:FunctionType ty = check buildFunctionSignature(defn.signature);
        llFuncTypes.push(ty);
        bir:InternalSymbol symbol = defn.symbol;
        string mangledName = mangleInternalSymbol(modId, symbol);
        llvm:FunctionDefn llFunc = llMod.addFunctionDefn(mangledName, ty);
        if !(di is ()) {
            DISubprogram diFunc = createFunctionDI(di, partFiles, defn, llFunc, mangledName);
            diFuncs.push(diFunc);
            llFunc.setSubprogram(diFunc);
        }   
        if !(options.gcName is ()) {
            llFunc.setGC(options.gcName);
        }
        if !symbol.isPublic {
            llFunc.setLinkage("internal");
        }
        llFuncs.push(llFunc);
        llFuncMap[defn.symbol.identifier] = llFunc;
    }
    llvm:Builder builder = llContext.createBuilder();
    Module mod = {
        bir: birMod,
        llContext,
        llMod,
        partFiles,
        di,
        typeCheckContext: birMod.getTypeCheckContext(),
        functionDefns: llFuncMap,
        stackGuard: llMod.addGlobal(llvm:pointerType("i8"), mangleRuntimeSymbol("stack_guard"))
    };  
    foreach int i in 0 ..< functionDefns.length() {
        bir:FunctionDefn defn = functionDefns[i];
        bir:FunctionCode code = check birMod.generateFunctionCode(i);
        check bir:verifyFunctionCode(birMod, defn, code);
        DISubprogram? diFunc = di is () ? () : diFuncs[i];
        Scaffold scaffold = check new(mod, llFuncs[i], diFunc, builder, defn, code);
        buildPrologue(builder, scaffold, defn.position);
        check buildFunctionBody(builder, scaffold, code);
    }
    return llMod;
}

function createModuleDI(llvm:Module mod, bir:File[] partFiles) returns ModuleDI {
    DIBuilder builder = mod.createDIBuilder();
    mod.addModuleFlag("error", ["Debug Info Version", 3]);
    DIFile[] files = from var f in partFiles select builder.createFile(f.filename(), f.directory() ?: "");
    DICompileUnit compileUnit = builder.createCompileUnit(file=files[0]);
    DISubroutineType funcType = builder.createSubroutineType(files[0]);
    return { builder, files, compileUnit, funcType };
}

function createFunctionDI(ModuleDI mod, bir:File[] files, bir:FunctionDefn birFunc, llvm:FunctionDefn llFunc, string mangledName) returns DISubprogram {
    int partIndex = birFunc.partIndex;
    var [lineNo, _] = files[partIndex].lineColumn(birFunc.position); 
    DIFile file = mod.files[partIndex];
    return mod.builder.createFunction({
        file,
        scope: file, // XXX Should we use the compileUnit or the File here?
        ty: mod.funcType,
        linkageName: mangledName,
        lineNo,
        isDefinition: true,
        name: birFunc.symbol.identifier,
        scopeLine: lineNo // XXX should be line number of opening brace
    });
}

function buildPrologue(llvm:Builder builder, Scaffold scaffold, bir:Position pos) {
    llvm:BasicBlock overflowBlock = scaffold.addBasicBlock();
    llvm:BasicBlock firstBlock = scaffold.basicBlock(0);
    builder.condBr(builder.iCmp("ult", builder.alloca("i8"), builder.load(scaffold.stackGuard())),
                   overflowBlock, firstBlock);
    builder.positionAtEnd(overflowBlock);
    buildCallPanic(builder, scaffold, buildErrorForConstPanic(builder, scaffold, PANIC_STACK_OVERFLOW, pos));
    builder.positionAtEnd(firstBlock);
    scaffold.saveParams(builder);
}

function buildFunctionBody(llvm:Builder builder, Scaffold scaffold, bir:FunctionCode code) returns BuildError? {
    foreach var b in code.blocks {
        check buildBasicBlock(builder, scaffold, b);
    }
}

function buildBasicBlock(llvm:Builder builder, Scaffold scaffold, bir:BasicBlock block) returns BuildError? {
    scaffold.setBasicBlock(block);
    builder.positionAtEnd(scaffold.basicBlock(block.label));
    foreach var insn in block.insns {
        if insn is bir:IntArithmeticBinaryInsn {
            buildArithmeticBinary(builder, scaffold, insn);
        }
        else if insn is bir:IntNoPanicArithmeticBinaryInsn {
            buildNoPanicArithmeticBinary(builder, scaffold, insn);
        }
        else if insn is bir:IntBitwiseBinaryInsn {
            buildBitwiseBinary(builder, scaffold, insn);
        }
        else if insn is bir:CompareInsn {
            check buildCompare(builder, scaffold, insn);
        }
        else if insn is bir:EqualityInsn {
            check buildEquality(builder, scaffold, insn);
        }
        else if insn is bir:BooleanNotInsn {
            buildBooleanNot(builder, scaffold, insn);
        }
        else if insn is bir:RetInsn {
            check buildRet(builder, scaffold, insn);
        }
        else if insn is bir:AssignInsn {
            check buildAssign(builder, scaffold, insn);
        }
        else if insn is bir:TypeCastInsn {
            check buildTypeCast(builder, scaffold, insn);
        }
        else if insn is bir:ConvertToIntInsn {
            check buildConvertToInt(builder, scaffold, insn);
        }
        else if insn is bir:ConvertToFloatInsn {
            check buildConvertToFloat(builder, scaffold, insn);
        }
        else if insn is bir:TypeTestInsn {
            check buildTypeTest(builder, scaffold, insn);
        }
        else if insn is bir:CondNarrowInsn {
            check buildCondNarrow(builder, scaffold, insn);
        }
        else if insn is bir:CallInsn {
            check buildCall(builder, scaffold, insn);
        }
        else if insn is bir:ListConstructInsn {
            check buildListConstruct(builder, scaffold, insn);
        }
        else if insn is bir:ListGetInsn {
            check buildListGet(builder, scaffold, insn);
        }
        else if insn is bir:ListSetInsn {
            check buildListSet(builder, scaffold, insn);
        }
        else if insn is bir:BranchInsn {
            check buildBranch(builder, scaffold, insn);
        }
        else if insn is bir:MappingConstructInsn {
            check buildMappingConstruct(builder, scaffold, insn);
        }
        else if insn is bir:MappingGetInsn {
            check buildMappingGet(builder, scaffold, insn);
        }
        else if insn is bir:MappingSetInsn {
            check buildMappingSet(builder, scaffold, insn);
        }
        else if insn is bir:StringConcatInsn {
            check buildStringConcat(builder, scaffold, insn);
        }
        else if insn is bir:CondBranchInsn {
            check buildCondBranch(builder, scaffold, insn);
        }
        else if insn is bir:AbnormalRetInsn {
            buildAbnormalRet(builder, scaffold, insn);
        }
        else if insn is bir:PanicInsn {
            buildPanic(builder, scaffold, insn);
        }
        else if insn is bir:ErrorConstructInsn {
            check buildErrorConstruct(builder, scaffold, insn);
        }
        else if insn is bir:FloatArithmeticBinaryInsn {
            buildFloatArithmeticBinary(builder, scaffold, insn);
        }
        else if insn is bir:FloatNegateInsn {
            buildFloatNegate(builder, scaffold, insn);
        }
        else {
            bir:CatchInsn unused = insn;
            // nothing to do
            // scaffold.panicAddress uses this to figure out where to store the panic info
        }
        scaffold.clearDebugLocation(builder);
    }
}

function buildBranch(llvm:Builder builder, Scaffold scaffold, bir:BranchInsn insn) returns BuildError? {
    builder.br(scaffold.basicBlock(insn.dest));
}

function buildCondBranch(llvm:Builder builder, Scaffold scaffold, bir:CondBranchInsn insn) returns BuildError? {
    builder.condBr(builder.load(scaffold.address(insn.operand)),
                   scaffold.basicBlock(insn.ifTrue),
                   scaffold.basicBlock(insn.ifFalse));
}

function buildRet(llvm:Builder builder, Scaffold scaffold, bir:RetInsn insn) returns BuildError? {
    RetRepr repr = scaffold.getRetRepr();
    builder.ret(repr is Repr ? check buildRepr(builder, scaffold, insn.operand, repr) : ());
}

function buildAbnormalRet(llvm:Builder builder, Scaffold scaffold, bir:AbnormalRetInsn insn) {
    buildCallPanic(builder, scaffold, <llvm:PointerValue>builder.load(scaffold.address(insn.operand)));
}

function buildPanic(llvm:Builder builder, Scaffold scaffold, bir:PanicInsn insn) {
    builder.store(builder.load(scaffold.address(insn.operand)), scaffold.panicAddress());
    builder.br(scaffold.getOnPanic());
}

function buildCallPanic(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue err) {
    _ = builder.call(buildRuntimeFunctionDecl(scaffold, panicFunction), [err]);
    builder.unreachable();
}

function buildAssign(llvm:Builder builder, Scaffold scaffold, bir:AssignInsn insn) returns BuildError? {
    builder.store(check buildRepr(builder, scaffold, insn.operand, scaffold.getRepr(insn.result)), scaffold.address(insn.result));
}

function buildCall(llvm:Builder builder, Scaffold scaffold, bir:CallInsn insn) returns BuildError? {
    scaffold.setDebugLocation(builder, insn.position);
    // Handler indirect calls later
    bir:FunctionRef funcRef = <bir:FunctionRef>insn.func;
    llvm:Value[] args = [];
    t:SemType[] paramTypes = funcRef.signature.paramTypes;
    foreach int i in 0 ..< insn.args.length() {
        args.push(check buildRepr(builder, scaffold, insn.args[i], check semTypeRepr(paramTypes[i])));
    }

    bir:Symbol funcSymbol = funcRef.symbol;
    llvm:Function func;
    if funcSymbol is bir:InternalSymbol {
        func = scaffold.getFunctionDefn(funcSymbol.identifier);
    }
    else {
        func = check buildFunctionDecl(scaffold, funcSymbol, funcRef.signature);
    }  
    llvm:Value? retValue = builder.call(func, args);
    RetRepr retRepr = check semTypeRetRepr(funcRef.signature.returnType);
    check buildStoreRet(builder, scaffold, retRepr, retValue, insn.result);
}

const LLVM_INDEX = "i32";

function buildListConstruct(llvm:Builder builder, Scaffold scaffold, bir:ListConstructInsn insn) returns BuildError? {
    final llvm:Type unsizedArrayType = llvm:arrayType(LLVM_TAGGED_PTR, 0);
    final llvm:PointerType ptrUnsizedArrayType = heapPointerType(unsizedArrayType);
    final llvm:Type structType = llvm:structType([LLVM_INT, LLVM_INT, LLVM_INT, ptrUnsizedArrayType]);
    final int length = insn.operands.length();
    llvm:PointerValue array;
    if length > 0 {
        final llvm:Type sizedArrayType = llvm:arrayType(LLVM_TAGGED_PTR, length);
        final llvm:PointerType ptrSizedArrayType = heapPointerType(sizedArrayType);

        array = buildTypedAlloc(builder, scaffold, sizedArrayType);
        foreach int i in 0 ..< length {
            builder.store(check buildRepr(builder, scaffold, insn.operands[i], REPR_ANY),
                          builder.getElementPtr(array, [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INT, i)], "inbounds"));
        }
        array = builder.bitCast(array, ptrUnsizedArrayType);
    }
    else {
        array = llvm:constNull(ptrUnsizedArrayType);
    }
    final llvm:PointerValue structMem = buildUntypedAlloc(builder, scaffold, structType);
    final llvm:PointerValue struct = builder.bitCast(structMem, heapPointerType(structType));
    // Store the member bitset as the ListDesc
    t:UniformTypeBitSet? memberType = t:simpleArrayMemberType(scaffold.typeCheckContext().env, insn.result.semType);
    if memberType == () {
        return err:unimplemented("unsupported member type for arrat");
    }
    else {
        builder.store(llvm:constInt(LLVM_INT, memberType),
                      builder.getElementPtr(struct, [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INDEX, 0)], "inbounds"));
    }
    foreach int i in 1 ..< 3 {
        builder.store(llvm:constInt(LLVM_INT, length),
                      builder.getElementPtr(struct, [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INDEX, i)], "inbounds"));
    }
    builder.store(array,
                  builder.getElementPtr(struct, [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INDEX, 3)], "inbounds"));
    // Don't need to convert here
    builder.store(buildTaggedPtr(builder, structMem, TAG_LIST_RW), scaffold.address(insn.result));
}

function buildListGet(llvm:Builder builder, Scaffold scaffold, bir:ListGetInsn insn) returns BuildError? {
    final llvm:Type unsizedArrayType = llvm:arrayType(LLVM_TAGGED_PTR, 0);
    final llvm:PointerType ptrUnsizedArrayType = heapPointerType(unsizedArrayType);
    final llvm:Type structType = llvm:structType([LLVM_INT, LLVM_INT, LLVM_INT, ptrUnsizedArrayType]);

    llvm:Value index = buildInt(builder, scaffold, insn.operand);
    // struct is the untagged pointer to the struct
    llvm:PointerValue struct = builder.bitCast(<llvm:PointerValue>builder.call(scaffold.getIntrinsicFunction("ptrmask.p1i8.i64"),
                                                                               [builder.load(scaffold.address(insn.list)), llvm:constInt(LLVM_INT, POINTER_MASK)]),
                                               heapPointerType(structType));
    llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
    llvm:BasicBlock outOfBoundsBlock = scaffold.addBasicBlock();
    builder.condBr(builder.iCmp("ult",
                                index,
                                builder.load(builder.getElementPtr(struct, [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INDEX, 1)]), ALIGN_HEAP)),
                   continueBlock,
                   outOfBoundsBlock);
    builder.positionAtEnd(outOfBoundsBlock);
    builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_INDEX_OUT_OF_BOUNDS, insn.position), scaffold.panicAddress());
    builder.br(scaffold.getOnPanic());
    builder.positionAtEnd(continueBlock);
    // array is a pointer to the array
    llvm:PointerValue array = <llvm:PointerValue>builder.load(builder.getElementPtr(struct,
                                                                                    [llvm:constInt(LLVM_INT, 0), llvm:constInt(LLVM_INDEX, 3)], "inbounds"),
                                                                                    ALIGN_HEAP);
    buildStoreTagged(builder, scaffold,
                     builder.load(builder.getElementPtr(array,
                                                        [llvm:constInt(LLVM_INT, 0), index], "inbounds"),
                                  ALIGN_HEAP),
                     insn.result);
}

function buildListSet(llvm:Builder builder, Scaffold scaffold, bir:ListSetInsn insn) returns BuildError? {
    llvm:Value? err = builder.call(buildRuntimeFunctionDecl(scaffold, listSetFunction),
                                   [builder.load(scaffold.address(insn.list)),
                                    buildInt(builder, scaffold, insn.index),
                                    check buildRepr(builder, scaffold, insn.operand, REPR_ANY)]);
    buildCheckError(builder, scaffold, <llvm:Value>err, insn.position);                                
   
}

function buildCheckError(llvm:Builder builder, Scaffold scaffold, llvm:Value err, bir:Position pos) {
    llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
    llvm:BasicBlock errorBlock = scaffold.addBasicBlock();
    builder.condBr(builder.iCmp("eq", err, llvm:constInt("i64", 0)),
                   continueBlock,
                   errorBlock);
    builder.positionAtEnd(errorBlock);
    builder.store(buildErrorForPanic(builder, scaffold, err, pos), scaffold.panicAddress());
    builder.br(scaffold.getOnPanic());
    builder.positionAtEnd(continueBlock);
}

function buildMappingConstruct(llvm:Builder builder, Scaffold scaffold, bir:MappingConstructInsn insn) returns BuildError? {
    int length = insn.operands.length();
    t:UniformTypeBitSet? memberType = t:simpleMapMemberType(scaffold.typeCheckContext().env, insn.result.semType);
    llvm:PointerValue m;
    if memberType == () {
        return err:unimplemented("unsupported member type for mapping");
    }
    else {
        m = <llvm:PointerValue>builder.call(buildRuntimeFunctionDecl(scaffold, mappingConstructFunction),
                                            [llvm:constInt(LLVM_INT, memberType), llvm:constInt(LLVM_INT, length)]);
    }
    
    foreach int i in 0 ..< length {
        _ = builder.call(buildRuntimeFunctionDecl(scaffold, mappingInitMemberFunction),
                         [
                             m,
                             check buildConstString(builder, scaffold, insn.fieldNames[i]),
                             check buildRepr(builder, scaffold, insn.operands[i], REPR_ANY)
                         ]);
    }
    builder.store(m, scaffold.address(insn.result));
}

function buildMappingGet(llvm:Builder builder, Scaffold scaffold, bir:MappingGetInsn insn) returns BuildError? {
    llvm:Value value = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, mappingGetFunction),
                                                [
                                                    builder.load(scaffold.address(insn.operands[0])),
                                                    check buildString(builder, scaffold, insn.operands[1])
                                                ]);
    buildStoreTagged(builder, scaffold, value, insn.result);
}

function buildMappingSet(llvm:Builder builder, Scaffold scaffold, bir:MappingSetInsn insn) returns BuildError? {
    llvm:Value? err = builder.call(buildRuntimeFunctionDecl(scaffold, mappingSetFunction),
                                   [
                                       builder.load(scaffold.address(insn.operands[0])),
                                       check buildString(builder, scaffold, insn.operands[1]),
                                       check buildRepr(builder, scaffold, insn.operands[2], REPR_ANY)
                                   ]);
    buildCheckError(builder, scaffold, <llvm:Value>err, insn.position);                                
}

function buildErrorConstruct(llvm:Builder builder, Scaffold scaffold, bir:ErrorConstructInsn insn) returns BuildError? {
    llvm:Value value = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, errorConstructFunction),
                                                [
                                                    check buildString(builder, scaffold, insn.operand),
                                                    llvm:constInt(LLVM_INT, scaffold.lineNumber(insn.position))
                                                ]);
    builder.store(value, scaffold.address(insn.result));
}


function buildStringConcat(llvm:Builder builder, Scaffold scaffold, bir:StringConcatInsn insn) returns BuildError? {
    llvm:Value value = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, stringConcatFunction),
                                                [
                                                    check buildString(builder, scaffold, insn.operands[0]),
                                                    check buildString(builder, scaffold, insn.operands[1])
                                                ]);
    builder.store(value, scaffold.address(insn.result));
}

function buildStoreRet(llvm:Builder builder, Scaffold scaffold, RetRepr retRepr, llvm:Value? retValue, bir:Register reg) returns BuildError? {
    if retRepr is Repr {
        builder.store(check buildConvertRepr(builder, scaffold, retRepr, <llvm:Value>retValue, scaffold.getRepr(reg)),
                      scaffold.address(reg));
    }
    else {
         builder.store(buildConstNil(), scaffold.address(reg));
    }
}

function buildFunctionDecl(Scaffold scaffold, bir:ExternalSymbol symbol, bir:FunctionSignature sig) returns llvm:FunctionDecl|BuildError {
    llvm:FunctionDecl? decl = scaffold.getImportedFunction(symbol);
    if !(decl is ()) {
        return decl;
    }
    else {
        llvm:FunctionType ty = check buildFunctionSignature(sig);
        llvm:Module mod = scaffold.getModule();
        llvm:FunctionDecl d = mod.addFunctionDecl(mangleExternalSymbol(symbol), ty);
        scaffold.addImportedFunction(symbol, d);
        return d;
    }
}

function buildRuntimeFunctionDecl(Scaffold scaffold, RuntimeFunction rf) returns llvm:FunctionDecl {
    bir:ExternalSymbol symbol =  { module: runtimeModule, identifier: rf.name };
    llvm:FunctionDecl? decl = scaffold.getImportedFunction(symbol);
    if !(decl is ()) {
        return decl;
    }
    else {
        llvm:Module mod = scaffold.getModule();
        llvm:FunctionDecl f = mod.addFunctionDecl(mangleRuntimeSymbol(rf.name), rf.ty);
        foreach var attr in rf.attrs {
            f.addEnumAttribute(attr);
        }
        scaffold.addImportedFunction(symbol, f);
        return f;
    } 
}

function buildArithmeticBinary(llvm:Builder builder, Scaffold scaffold, bir:IntArithmeticBinaryInsn insn) {
    llvm:IntrinsicFunctionName? intrinsicName = buildBinaryIntIntrinsic(insn.op);
    llvm:Value lhs = buildInt(builder, scaffold, insn.operands[0]);
    llvm:Value rhs = buildInt(builder, scaffold, insn.operands[1]);
    llvm:Value result;
    llvm:BasicBlock? joinBlock = ();
    if intrinsicName != () {
        llvm:FunctionDecl intrinsicFunction = scaffold.getIntrinsicFunction(intrinsicName);
        // XXX better to distinguish builder.call and builder.callVoid
        llvm:Value resultWithOverflow = <llvm:Value>builder.call(intrinsicFunction, [lhs, rhs]);
        llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
        llvm:BasicBlock overflowBlock = scaffold.addBasicBlock();
        builder.condBr(builder.extractValue(resultWithOverflow, 1), overflowBlock, continueBlock);
        builder.positionAtEnd(overflowBlock);
        builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_ARITHMETIC_OVERFLOW, insn.position), scaffold.panicAddress());
        builder.br(scaffold.getOnPanic());
        builder.positionAtEnd(continueBlock);
        result = builder.extractValue(resultWithOverflow, 0);
    }
    else {
        llvm:BasicBlock zeroDivisorBlock = scaffold.addBasicBlock();
        llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
        builder.condBr(builder.iCmp("eq", rhs, llvm:constInt(LLVM_INT, 0)), zeroDivisorBlock, continueBlock);
        builder.positionAtEnd(zeroDivisorBlock);
        builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_DIVIDE_BY_ZERO, insn.position), scaffold.panicAddress());
        builder.br(scaffold.getOnPanic());
        builder.positionAtEnd(continueBlock);
        continueBlock = scaffold.addBasicBlock();
        llvm:BasicBlock overflowBlock = scaffold.addBasicBlock();
        builder.condBr(builder.iBitwise("and",
                                        builder.iCmp("eq", lhs, llvm:constInt(LLVM_INT, int:MIN_VALUE)),
                                        builder.iCmp("eq", rhs, llvm:constInt(LLVM_INT, -1))),
                       overflowBlock,
                       continueBlock);
        builder.positionAtEnd(overflowBlock);
        llvm:IntArithmeticSignedOp op;
        if insn.op == "/" {
            op = "sdiv";
            builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_ARITHMETIC_OVERFLOW, insn.position), scaffold.panicAddress());
            builder.br(scaffold.getOnPanic());
        }
        else {
            builder.store(llvm:constInt(LLVM_INT, 0), scaffold.address(insn.result));
            llvm:BasicBlock b = scaffold.addBasicBlock();
            builder.br(b);
            joinBlock = b;
            op = "srem";
        }
        builder.positionAtEnd(continueBlock);
        result = builder.iArithmeticSigned(op, lhs, rhs);
    }
    buildStoreInt(builder, scaffold, result, insn.result);                                  
    if !(joinBlock is ()) {
        builder.br(joinBlock);
        builder.positionAtEnd(joinBlock);
    }                         
}

function buildNoPanicArithmeticBinary(llvm:Builder builder, Scaffold scaffold, bir:IntNoPanicArithmeticBinaryInsn insn) {
    llvm:Value lhs = buildInt(builder, scaffold, insn.operands[0]);
    llvm:Value rhs = buildInt(builder, scaffold, insn.operands[1]);
    llvm:IntArithmeticOp op = intArithmeticOps.get(insn.op);
    llvm:Value result = builder.iArithmeticNoWrap(op, lhs, rhs);
    buildStoreInt(builder, scaffold, result, insn.result);                                  
}

function buildFloatArithmeticBinary(llvm:Builder builder, Scaffold scaffold, bir:FloatArithmeticBinaryInsn insn) {
    llvm:Value lhs = buildFloat(builder, scaffold, insn.operands[0]);
    llvm:Value rhs = buildFloat(builder, scaffold, insn.operands[1]);
    llvm:FloatArithmeticOp op = floatArithmeticOps.get(insn.op);
    llvm:Value result = builder.fArithmetic(op, lhs, rhs);
    buildStoreFloat(builder, scaffold, result, insn.result);                                  
}

function buildFloatNegate(llvm:Builder builder, Scaffold scaffold, bir:FloatNegateInsn insn) {
    llvm:Value operand = buildFloat(builder, scaffold, insn.operand);
    llvm:Value result = builder.fNeg(operand);
    buildStoreFloat(builder, scaffold, result, insn.result);
}

final readonly & map<llvm:IntBitwiseOp> binaryBitwiseOp = {
    "&": "and",
    "^": "xor",
    "|": "or",
    "<<": "shl",
    ">>": "ashr",
    ">>>" : "lshr"
};

function buildBitwiseBinary(llvm:Builder builder, Scaffold scaffold, bir:IntBitwiseBinaryInsn insn) {
    llvm:Value lhs = buildInt(builder, scaffold, insn.operands[0]);
    llvm:Value rhs = buildInt(builder, scaffold, insn.operands[1]);
    if insn.op is bir:BitwiseShiftOp {
        rhs = builder.iBitwise("and", llvm:constInt(LLVM_INT, 0x3F), rhs);
    }
    llvm:IntBitwiseOp op = binaryBitwiseOp.get(insn.op);
    llvm:Value result = builder.iBitwise(op, lhs, rhs);
    buildStoreInt(builder, scaffold, result, insn.result);                                  
}

function buildCompare(llvm:Builder builder, Scaffold scaffold, bir:CompareInsn insn) returns BuildError? {
    var [lhsRepr, lhsValue] = check buildReprValue(builder, scaffold, insn.operands[0]);
    var [rhsRepr, rhsValue] = check buildReprValue(builder, scaffold, insn.operands[1]);
    bir:Register result = insn.result;

    match [lhsRepr.base, rhsRepr.base] {
        [BASE_REPR_TAGGED, BASE_REPR_INT] => {
            buildCompareTaggedInt(builder, scaffold, buildIntCompareOp(insn.op), lhsValue, rhsValue, result);
        }
        [BASE_REPR_INT, BASE_REPR_TAGGED] => {
            buildCompareTaggedInt(builder, scaffold, buildIntCompareOp(flippedOrderOps.get(insn.op)), rhsValue, lhsValue, result);
        }
        [BASE_REPR_TAGGED, BASE_REPR_FLOAT] => {
            buildCompareTaggedFloat(builder, scaffold, buildFloatCompareOp(insn.op), lhsValue, rhsValue, result);
        }
        [BASE_REPR_FLOAT, BASE_REPR_TAGGED] => {
            buildCompareTaggedFloat(builder, scaffold, buildFloatCompareOp(flippedOrderOps.get(insn.op)), rhsValue, lhsValue, result);
        }
        [BASE_REPR_TAGGED, BASE_REPR_BOOLEAN] => {
            buildCompareTaggedBoolean(builder, scaffold, buildBooleanCompareOp(insn.op), lhsValue, rhsValue, result);
        }
        [BASE_REPR_BOOLEAN, BASE_REPR_TAGGED] => {
            buildCompareTaggedBoolean(builder, scaffold, buildBooleanCompareOp(flippedOrderOps.get(insn.op)), rhsValue, lhsValue, result);
        }
        [BASE_REPR_TAGGED, BASE_REPR_TAGGED] => {
            if insn.orderType is t:UT_STRING {
                buildCompareString(builder, scaffold, buildIntCompareOp(insn.op), lhsValue, rhsValue, result);
            }
            else {
                buildCompareTagged(builder, scaffold, insn, lhsValue, rhsValue, result);
            }
        }
        [BASE_REPR_INT, BASE_REPR_INT] => {
            buildCompareInt(builder, scaffold, buildIntCompareOp(insn.op), lhsValue, rhsValue, result);
        }
        [BASE_REPR_BOOLEAN, BASE_REPR_BOOLEAN] => {
            buildCompareInt(builder, scaffold, buildBooleanCompareOp(insn.op), lhsValue, rhsValue, result);
        }
        [BASE_REPR_FLOAT, BASE_REPR_FLOAT] => {
            buildCompareFloat(builder, scaffold, buildFloatCompareOp(insn.op), lhsValue, rhsValue, result);
        }
    }
}
final readonly & map<bir:OrderOp> flippedOrderOps = {
    ">=": "<=",
    ">" : "<",
    "<=": ">=",
    "<" : ">"
};

function buildCompareTagged(llvm:Builder builder, Scaffold scaffold, bir:CompareInsn insn, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    llvm:Value lhsIsNil = builder.iCmp("eq", lhs, llvm:constNull(llvm:pointerType("i8", 1)));
    llvm:Value rhsIsNil = builder.iCmp("eq", rhs, llvm:constNull(llvm:pointerType("i8", 1)));
    llvm:Value eitherNil = builder.iBitwise("or", lhsIsNil, rhsIsNil);

    llvm:BasicBlock eitherNilBB = scaffold.addBasicBlock();
    llvm:BasicBlock neitherNilBB = scaffold.addBasicBlock();
    llvm:BasicBlock joinBB = scaffold.addBasicBlock();
    builder.condBr(eitherNil, eitherNilBB, neitherNilBB);

    builder.positionAtEnd(eitherNilBB);
    llvm:Value bothNil = builder.iBitwise("and", lhsIsNil, rhsIsNil);

    if insn.op is "<=" || insn.op is ">=" {
        buildStoreBoolean(builder, scaffold, bothNil, insn.result);
    }
    else {
        buildStoreBoolean(builder, scaffold, llvm:constInt(LLVM_BOOLEAN, 0), insn.result);
    }
    builder.br(joinBB);

    builder.positionAtEnd(neitherNilBB);
    bir:OptOrderType orderTy = <bir:OptOrderType> insn.orderType;
    match orderTy.opt {
        t:UT_INT => {
            llvm:Value lhsUntagged = buildUntagInt(builder, scaffold, <llvm:PointerValue>lhs);
            llvm:Value rhsUntagged = buildUntagInt(builder, scaffold, <llvm:PointerValue>rhs);
            buildCompareInt(builder, scaffold, buildIntCompareOp(insn.op), lhsUntagged, rhsUntagged, result);
        }
        t:UT_FLOAT => {
            llvm:Value lhsUntagged = buildUntagFloat(builder, scaffold, <llvm:PointerValue>lhs);
            llvm:Value rhsUntagged = buildUntagFloat(builder, scaffold, <llvm:PointerValue>rhs);
            buildCompareFloat(builder, scaffold, buildFloatCompareOp(insn.op), lhsUntagged, rhsUntagged, result);
        }
        t:UT_BOOLEAN => {
            buildCompareInt(builder, scaffold, buildBooleanCompareOp(insn.op), lhs, rhs, result);
        }
        t:UT_STRING => {
            buildCompareString(builder, scaffold, buildIntCompareOp(insn.op), lhs, rhs, result);
        }
    }
    builder.br(joinBB);
    builder.positionAtEnd(joinBB);
}

function buildCompareTaggedBasic(llvm:Builder builder, Scaffold scaffold, llvm:Value lhs, llvm:Value rhs, bir:Register result)
    returns [llvm:BasicBlock, llvm:BasicBlock] {
    llvm:BasicBlock bbNil = scaffold.addBasicBlock();
    llvm:BasicBlock bbNotNil = scaffold.addBasicBlock();
    llvm:BasicBlock bbJoin = scaffold.addBasicBlock();
    llvm:Value isNil = builder.iCmp("eq", lhs, llvm:constNull(llvm:pointerType("i8", 1)));
    builder.condBr(isNil, bbNil, bbNotNil);
    builder.positionAtEnd(bbNil);
    buildStoreBoolean(builder, scaffold, llvm:constInt(LLVM_BOOLEAN, 0), result);
    builder.br(bbJoin);
    builder.positionAtEnd(bbNotNil);
    return [bbNotNil, bbJoin];
}

function buildCompareTaggedInt(llvm:Builder builder, Scaffold scaffold, llvm:IntPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    var [bbNotNil, bbJoin] = buildCompareTaggedBasic(builder, scaffold, lhs, rhs, result);
    llvm:Value lhsUntagged = buildUntagInt(builder, scaffold, <llvm:PointerValue>lhs);
    buildCompareInt(builder, scaffold, op, lhsUntagged, rhs, result);
    builder.br(bbJoin);
    builder.positionAtEnd(bbJoin);
}

function buildCompareTaggedFloat(llvm:Builder builder, Scaffold scaffold, llvm:FloatPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    var [bbNotNil, bbJoin] = buildCompareTaggedBasic(builder, scaffold, lhs, rhs, result);
    llvm:Value lhsUntagged = buildUntagFloat(builder, scaffold, <llvm:PointerValue>lhs);
    buildCompareFloat(builder, scaffold, op, lhsUntagged, rhs, result);
    builder.br(bbJoin);
    builder.positionAtEnd(bbJoin);
}

function buildCompareTaggedBoolean(llvm:Builder builder, Scaffold scaffold, llvm:IntPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    var [bbNotNil, bbJoin] = buildCompareTaggedBasic(builder, scaffold, lhs, rhs, result);
    llvm:Value lhsUntagged = buildUntagBoolean(builder, <llvm:PointerValue>lhs);
    buildCompareInt(builder, scaffold, op, lhsUntagged, rhs, result);
    builder.br(bbJoin);
    builder.positionAtEnd(bbJoin);
}

function buildCompareInt(llvm:Builder builder, Scaffold scaffold, llvm:IntPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    buildStoreBoolean(builder, scaffold, builder.iCmp(op, lhs, rhs), result);
}

function buildCompareFloat(llvm:Builder builder, Scaffold scaffold, llvm:FloatPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    buildStoreBoolean(builder, scaffold, builder.fCmp(op, lhs, rhs), result);
}

function buildCompareString(llvm:Builder builder, Scaffold scaffold, llvm:IntPredicate op, llvm:Value lhs, llvm:Value rhs, bir:Register result) {
    buildStoreBoolean(builder, scaffold,
                      builder.iCmp(op, <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, stringCmpFunction), [lhs, rhs]),
                                   llvm:constInt(LLVM_INT, 0)),
                      result);
}

type CmpEqOp "ne"|"eq";

function buildEquality(llvm:Builder builder, Scaffold scaffold, bir:EqualityInsn insn) returns BuildError? {
    var [lhsRepr, lhsValue] = check buildReprValue(builder, scaffold, insn.operands[0]);
    var [rhsRepr, rhsValue] = check buildReprValue(builder, scaffold, insn.operands[1]);
    CmpEqOp op = insn.op[0] == "!" ?  "ne" : "eq"; 
    // JBUG cast
    boolean exact = (<string>insn.op).length() == 3; // either "===" or "!=="
    bir:Register result = insn.result;
    match [lhsRepr.base, rhsRepr.base] {
        [BASE_REPR_TAGGED, BASE_REPR_TAGGED] => {
            if reprIsImmediate(lhsRepr) || reprIsImmediate(rhsRepr)
               || (exact && (!reprExactNeedsHeap(lhsRepr) || !reprExactNeedsHeap(rhsRepr))) {
                return buildStoreBoolean(builder, scaffold, builder.iCmp(op, lhsValue, rhsValue), result);
            }
            else if reprIsString(lhsRepr) && reprIsString(rhsRepr) {
                return buildEqualStringString(builder, scaffold, op, <llvm:PointerValue>lhsValue, <llvm:PointerValue>rhsValue, result);
            }
            else {
                return buildEqualTaggedTagged(builder, scaffold, exact, op, <llvm:PointerValue>lhsValue, <llvm:PointerValue>rhsValue, result);
            }
        }
        [BASE_REPR_TAGGED, BASE_REPR_BOOLEAN] => {
            return buildEqualTaggedBoolean(builder, scaffold, op, <llvm:PointerValue>lhsValue, rhsValue, result);
        }
        [BASE_REPR_BOOLEAN, BASE_REPR_TAGGED] => {
            return buildEqualTaggedBoolean(builder, scaffold, op, <llvm:PointerValue>rhsValue, lhsValue, result);
        }
        [BASE_REPR_TAGGED, BASE_REPR_INT] => {
            return buildEqualTaggedInt(builder, scaffold, op, <llvm:PointerValue>lhsValue, rhsValue, result);
        }
        [BASE_REPR_INT, BASE_REPR_TAGGED] => {
            return buildEqualTaggedInt(builder, scaffold, op, <llvm:PointerValue>rhsValue, lhsValue, result);
        }
        [BASE_REPR_BOOLEAN, BASE_REPR_BOOLEAN]
        | [BASE_REPR_INT, BASE_REPR_INT] => {
             // no tags involved, same representation, boolean/int
            return buildStoreBoolean(builder, scaffold, builder.iCmp(op, lhsValue, rhsValue), result);
        }
        [BASE_REPR_TAGGED, BASE_REPR_FLOAT] => {
            return buildEqualTaggedFloat(builder, scaffold, exact, op, <llvm:PointerValue>lhsValue, rhsValue, result);
        }
        [BASE_REPR_FLOAT, BASE_REPR_TAGGED] => {
            return buildEqualTaggedFloat(builder, scaffold, exact, op, <llvm:PointerValue>rhsValue, lhsValue, result);
        }
        [BASE_REPR_FLOAT, BASE_REPR_FLOAT] => {
            return buildEqualFloat(builder, scaffold, exact, op, lhsValue, rhsValue, result);
        }
    }
    return err:unimplemented("equality with two different untagged representations");    
}

function buildEqualTaggedFloat(llvm:Builder builder, Scaffold scaffold, boolean exact, CmpEqOp op, llvm:PointerValue tagged, llvm:Value untagged, bir:Register result) {
    llvm:BasicBlock floatTagBlock = scaffold.addBasicBlock();
    llvm:BasicBlock otherTagBlock = scaffold.addBasicBlock();
    llvm:BasicBlock joinBlock = scaffold.addBasicBlock();
    builder.condBr(buildHasTag(builder, tagged, TAG_FLOAT), floatTagBlock, otherTagBlock);
    builder.positionAtEnd(otherTagBlock);
    buildStoreBoolean(builder, scaffold,
                      // result is false if op is "eq", true if op is "ne"
                      buildConstBoolean(op == "ne"),
                      result);
    builder.br(joinBlock);
    builder.positionAtEnd(floatTagBlock);
    buildEqualFloat(builder, scaffold, exact, op, buildUntagFloat(builder, scaffold, tagged), untagged, result);
    builder.br(joinBlock);
    builder.positionAtEnd(joinBlock);
}

function buildEqualFloat(llvm:Builder builder, Scaffold scaffold, boolean exact, CmpEqOp op, llvm:Value lhsValue, llvm:Value rhsValue, bir:Register reg) {
    RuntimeFunction eqFunc = exact ? floatExactEqFunction : floatEqFunction;
    llvm:Value b = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, eqFunc), [lhsValue, rhsValue]);
    if op == "ne" {
        b = builder.iBitwise("xor", b, llvm:constInt(LLVM_BOOLEAN, 1));
    }
    return buildStoreBoolean(builder, scaffold, b, reg);
}

function reprIsNil(Repr repr) returns boolean {
    return repr is TaggedRepr && repr.subtype == t:NIL;
}

function reprIsString(Repr repr) returns boolean {
    return repr is TaggedRepr && repr.subtype == t:STRING;
}

// May we need to look at the heap in order to tell whether something with this representation
// is exactly equal to something else?
function reprExactNeedsHeap(Repr repr) returns boolean {
    return repr is TaggedRepr && (repr.subtype & (t:FLOAT|t:INT|t:STRING)) != 0;
}

function reprIsImmediate(Repr repr) returns boolean {
    return !(repr is TaggedRepr) || (repr.subtype & ~(t:NIL|t:BOOLEAN)) == 0;
}

function buildEqualTaggedBoolean(llvm:Builder builder, Scaffold scaffold, CmpEqOp op, llvm:PointerValue tagged, llvm:Value untagged, bir:Register result)  {
    buildStoreBoolean(builder, scaffold,
                      builder.iCmp(op, tagged, buildTaggedBoolean(builder, untagged)),
                      result);
}

function buildEqualTaggedInt(llvm:Builder builder, Scaffold scaffold, CmpEqOp op, llvm:PointerValue tagged, llvm:Value untagged, bir:Register result) {
    llvm:BasicBlock intTagBlock = scaffold.addBasicBlock();
    llvm:BasicBlock otherTagBlock = scaffold.addBasicBlock();
    llvm:BasicBlock joinBlock = scaffold.addBasicBlock();
    builder.condBr(buildHasTag(builder, tagged, TAG_INT), intTagBlock, otherTagBlock);
    builder.positionAtEnd(otherTagBlock);
    buildStoreBoolean(builder, scaffold,
                      // result is false if op is "eq", true if op is "ne"
                      buildConstBoolean(op == "ne"),
                      result);
    builder.br(joinBlock);
    builder.positionAtEnd(intTagBlock);
    buildStoreBoolean(builder, scaffold, builder.iCmp(op, buildUntagInt(builder, scaffold, tagged), untagged), result);
    builder.br(joinBlock);
    builder.positionAtEnd(joinBlock);
}

function buildEqualTaggedTagged(llvm:Builder builder, Scaffold scaffold, boolean exact, CmpEqOp op, llvm:PointerValue tagged1, llvm:PointerValue tagged2, bir:Register result) {
    RuntimeFunction func = exact ? exactEqFunction : eqFunction;
    llvm:Value b = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, func), [tagged1, tagged2]);
    if op == "ne" {
        b = builder.iBitwise("xor", b, llvm:constInt(LLVM_BOOLEAN, 1));
    }
    buildStoreBoolean(builder, scaffold, b, result);
}

function buildEqualStringString(llvm:Builder builder, Scaffold scaffold, CmpEqOp op, llvm:PointerValue tagged1, llvm:PointerValue tagged2, bir:Register result) {
    llvm:Value b = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, stringEqFunction), [tagged1, tagged2]);
    if op == "ne" {
        b = builder.iBitwise("xor", b, llvm:constInt(LLVM_BOOLEAN, 1));
    }
    buildStoreBoolean(builder, scaffold, b, result);
}

function buildTypeTest(llvm:Builder builder, Scaffold scaffold, bir:TypeTestInsn insn) returns BuildError? {
    var [repr, val] = check buildReprValue(builder, scaffold, insn.operand);
    if repr.base != BASE_REPR_TAGGED {
         // in subset 5 should be const true/false
        return err:unimplemented("test of untagged value");
    }
    t:SemType semType = insn.semType;
    llvm:PointerValue tagged = <llvm:PointerValue>val;
    llvm:Value hasType;
    if semType === t:BOOLEAN {
        hasType = buildHasTag(builder, tagged, TAG_BOOLEAN);
    }
    else if semType === t:INT {
        hasType = buildHasTag(builder, tagged, TAG_INT);
    }
    else if semType === t:FLOAT {
        hasType = buildHasTag(builder, tagged, TAG_FLOAT);
    }
    else if semType === t:STRING {
        hasType = buildHasTag(builder, tagged, TAG_STRING);
    }
    else if semType === t:ERROR {
        hasType = buildHasTag(builder, tagged, TAG_ERROR);
    }
    else if t:isSubtypeSimple(semType, t:LIST) {
        hasType = buildHasListType(builder, scaffold, tagged, insn.operand.semType, semType);
    }
    else if t:isSubtypeSimple(semType, t:MAPPING) {
        hasType = buildHasMappingType(builder, scaffold, tagged, insn.operand.semType, semType);
    }
    else if semType is t:UniformTypeBitSet {
        hasType = buildHasTagInSet(builder, tagged, semType);
    }
    else {
        return err:unimplemented("unimplemented type test"); // should not happen in subset 6
    }
    if insn.negated {
        buildStoreBoolean(builder, scaffold, 
                    builder.iBitwise("xor", llvm:constInt(LLVM_BOOLEAN, 1), hasType), 
                    insn.result);
    }
    else {
        buildStoreBoolean(builder, scaffold, hasType, insn.result);
    }
}

function buildHasListType(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue tagged, t:SemType sourceType, t:SemType targetType) returns llvm:Value {
    if t:intersect(sourceType, t:LIST) == targetType {
        return buildHasBasicTypeTag(builder, tagged, TAG_BASIC_TYPE_LIST);
    }
    else {
        t:UniformTypeBitSet bitSet = <t:UniformTypeBitSet>t:simpleArrayMemberType(scaffold.typeCheckContext().env, targetType);
        return <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, listHasTypeFunction),
                                        [tagged, llvm:constInt(LLVM_INT, bitSet)]);      
    }
}

function buildHasMappingType(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue tagged, t:SemType sourceType, t:SemType targetType) returns llvm:Value {
    if t:intersect(sourceType, t:MAPPING) == targetType {
        return buildHasBasicTypeTag(builder, tagged, TAG_BASIC_TYPE_MAPPING);
    }
    else {
        t:UniformTypeBitSet bitSet = <t:UniformTypeBitSet>t:simpleMapMemberType(scaffold.typeCheckContext().env, targetType);
        return <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, mappingHasTypeFunction),
                                        [tagged, llvm:constInt(LLVM_INT, bitSet)]);      
    }
}

function buildTypeCast(llvm:Builder builder, Scaffold scaffold, bir:TypeCastInsn insn) returns BuildError? {
    var [repr, val] = check buildReprValue(builder, scaffold, insn.operand);
    if repr.base != BASE_REPR_TAGGED {
        return err:unimplemented("cast from untagged value"); // should not happen in subset 2
    }
    llvm:PointerValue tagged = <llvm:PointerValue>val;
    llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
    llvm:BasicBlock castFailBlock = scaffold.addBasicBlock();
    t:SemType semType = insn.semType;
    if semType === t:BOOLEAN {
        builder.condBr(buildHasTag(builder, tagged, TAG_BOOLEAN), continueBlock, castFailBlock);
        builder.positionAtEnd(continueBlock);
        buildStoreBoolean(builder, scaffold, buildUntagBoolean(builder, tagged), insn.result);
    }
    else if semType === t:INT {
        builder.condBr(buildHasTag(builder, tagged, TAG_INT), continueBlock, castFailBlock);
        builder.positionAtEnd(continueBlock);
        buildStoreInt(builder, scaffold, buildUntagInt(builder, scaffold, tagged), insn.result);
    }
    else if semType === t:FLOAT {
        builder.condBr(buildHasTag(builder, tagged, TAG_FLOAT), continueBlock, castFailBlock);
        builder.positionAtEnd(continueBlock);
        buildStoreFloat(builder, scaffold, buildUntagFloat(builder, scaffold, tagged), insn.result);
    }
    else {
        llvm:Value hasTag;
        if semType === t:STRING {
            hasTag = buildHasTag(builder, tagged, TAG_STRING);
        }
        else if semType === t:ERROR {
            hasTag = buildHasTag(builder, tagged, TAG_ERROR);
        }
        else if t:isSubtypeSimple(semType, t:LIST) {
            hasTag = buildHasListType(builder, scaffold, tagged, insn.operand.semType, semType);
        }
        else if t:isSubtypeSimple(semType, t:MAPPING) {
            hasTag = buildHasMappingType(builder, scaffold, tagged, insn.operand.semType, semType);
        }
        else if semType is t:UniformTypeBitSet {
            hasTag = buildHasTagInSet(builder, tagged, semType);
        }
        else {
            return err:unimplemented("unimplemented type cast"); // should not happen in subset 6
        }
        builder.condBr(hasTag, continueBlock, castFailBlock);
        builder.positionAtEnd(continueBlock);
        builder.store(tagged, scaffold.address(insn.result));
    }
    builder.positionAtEnd(castFailBlock);
    builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_TYPE_CAST, insn.position), scaffold.panicAddress());
    builder.br(scaffold.getOnPanic());
    builder.positionAtEnd(continueBlock);
}

function buildConvertToInt(llvm:Builder builder, Scaffold scaffold, bir:ConvertToIntInsn insn) returns BuildError? {
    var [repr, val] = check buildReprValue(builder, scaffold, insn.operand);
    if repr.base == BASE_REPR_FLOAT {
        buildConvertFloatToInt(builder, scaffold, val, insn);
        return;
    }
    else if repr.base != BASE_REPR_TAGGED {
        return err:unimplemented("convert form decimal to int");
    }
    // convert to int form tagged pointer

    t:SemType semType = insn.operand.semType;
    llvm:PointerValue tagged = <llvm:PointerValue>val;
    llvm:BasicBlock joinBlock = scaffold.addBasicBlock();

    // semType must contain float or decimal. Since we don't have decimal yet in subset 6,
    // it must contain float. In the future, below section is only needed conditionally.
    llvm:Value hasType = buildHasTag(builder, tagged, TAG_FLOAT);
    llvm:BasicBlock hasFloatBlock = scaffold.addBasicBlock();
    llvm:BasicBlock noFloatBlock = scaffold.addBasicBlock();
    builder.condBr(hasType, hasFloatBlock, noFloatBlock);
    builder.positionAtEnd(hasFloatBlock);
    buildConvertFloatToInt(builder, scaffold, buildUntagFloat(builder, scaffold, tagged), insn);
    builder.br(joinBlock);

    builder.positionAtEnd(<llvm:BasicBlock>noFloatBlock);
    if !t:isSubtypeSimple(semType, t:FLOAT) {
        builder.store(tagged, scaffold.address(insn.result));
    }
    builder.br(joinBlock);
    builder.positionAtEnd(joinBlock);
}

function buildConvertFloatToInt(llvm:Builder builder, Scaffold scaffold, llvm:Value floatVal, bir:ConvertToIntInsn insn) {
    llvm:Value resultWithErr = <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, floatToIntFunction), [floatVal]);
    llvm:BasicBlock continueBlock = scaffold.addBasicBlock();
    llvm:BasicBlock errBlock = scaffold.addBasicBlock();
    builder.condBr(builder.extractValue(resultWithErr, 1), errBlock, continueBlock);
    builder.positionAtEnd(errBlock);
    builder.store(buildErrorForConstPanic(builder, scaffold, PANIC_TYPE_CAST, insn.position), scaffold.panicAddress());
    builder.br(scaffold.getOnPanic());
    builder.positionAtEnd(continueBlock);
    llvm:Value result = builder.extractValue(resultWithErr, 0);
    buildStoreInt(builder, scaffold, result, insn.result);
}

function buildConvertToFloat(llvm:Builder builder, Scaffold scaffold, bir:ConvertToFloatInsn insn) returns BuildError? {
    var [repr, val] = check buildReprValue(builder, scaffold, insn.operand);
    if repr.base == BASE_REPR_INT {
        buildConvertIntToFloat(builder, scaffold, val, insn);
        return;
    }
    else if repr.base != BASE_REPR_TAGGED {
        return err:unimplemented("convert form decimal to float");
    }
    // convert to float form tagged pointer

    // number part of semType must be some *non-empty* combination of
    // (some or all of) int, float and decimal
    t:SemType semType = insn.operand.semType;
    llvm:PointerValue tagged = <llvm:PointerValue>val;
    llvm:BasicBlock joinBlock = scaffold.addBasicBlock();

    // semType must contain int or decimal. Since we don't have decimal yet in subset 6,
    // it must contain int. In the future, below section is only needed conditionally.
    llvm:Value hasType = buildHasTag(builder, tagged, TAG_INT);
    llvm:BasicBlock hasIntBlock = scaffold.addBasicBlock();
    llvm:BasicBlock noIntBlock = scaffold.addBasicBlock();
    builder.condBr(hasType, hasIntBlock, noIntBlock);
    builder.positionAtEnd(hasIntBlock);
    buildConvertIntToFloat(builder, scaffold, buildUntagInt(builder, scaffold, tagged), insn);
    builder.br(joinBlock);

    builder.positionAtEnd(<llvm:BasicBlock>noIntBlock);
    if !t:isSubtypeSimple(semType, t:INT) {
        builder.store(tagged, scaffold.address(insn.result));
    }
    builder.br(joinBlock);
    builder.positionAtEnd(joinBlock);
}

function buildConvertIntToFloat(llvm:Builder builder, Scaffold scaffold, llvm:Value intVal, bir:ConvertToFloatInsn insn) {
    buildStoreFloat(builder, scaffold, builder.sIToFP(intVal, LLVM_DOUBLE), insn.result);
}

function buildCondNarrow(llvm:Builder builder, Scaffold scaffold, bir:CondNarrowInsn insn) returns BuildError? {
    var [sourceRepr, value] = check buildReprValue(builder, scaffold, insn.operand);
    llvm:Value narrowed = check buildNarrowRepr(builder, scaffold, sourceRepr, value, scaffold.getRepr(insn.result));
    builder.store(narrowed, scaffold.address(insn.result));
}

function buildNarrowRepr(llvm:Builder builder, Scaffold scaffold, Repr sourceRepr, llvm:Value value, Repr targetRepr) returns llvm:Value|BuildError {
    BaseRepr sourceBaseRepr = sourceRepr.base;
    BaseRepr targetBaseRepr = targetRepr.base;
    llvm:Value narrowed;
    if sourceBaseRepr == targetBaseRepr {
        return value;
    }
    if sourceBaseRepr == BASE_REPR_TAGGED {
        return buildUntagged(builder, scaffold, <llvm:PointerValue>value, targetRepr);
    }
    return err:unimplemented("unimplemented narrowing conversion required");
}

function buildErrorForConstPanic(llvm:Builder builder, Scaffold scaffold, PanicIndex panicIndex, bir:Position pos) returns llvm:PointerValue {
    // JBUG #31753 cast
    return buildErrorForPackedPanic(builder, scaffold, llvm:constInt(LLVM_INT, <int>panicIndex | (scaffold.lineNumber(pos) << 8)));
}

function buildErrorForPanic(llvm:Builder builder, Scaffold scaffold, llvm:Value panicIndex, bir:Position pos) returns llvm:PointerValue {
    return buildErrorForPackedPanic(builder, scaffold, builder.iBitwise("or", panicIndex, llvm:constInt(LLVM_INT, scaffold.lineNumber(pos) << 8)));
}

function buildErrorForPackedPanic(llvm:Builder builder, Scaffold scaffold, llvm:Value packedPanic) returns llvm:PointerValue {
    return <llvm:PointerValue>builder.call(buildRuntimeFunctionDecl(scaffold, panicConstructFunction), [packedPanic]);
}

function buildBooleanNot(llvm:Builder builder, Scaffold scaffold, bir:BooleanNotInsn insn) {
    buildStoreBoolean(builder, scaffold,
                      builder.iBitwise("xor", llvm:constInt(LLVM_BOOLEAN, 1), builder.load(scaffold.address(insn.operand))),
                      insn.result);
}

function buildStoreInt(llvm:Builder builder, Scaffold scaffold, llvm:Value value, bir:Register reg) {
    builder.store(scaffold.getRepr(reg).base == BASE_REPR_TAGGED ? buildTaggedInt(builder, scaffold, value) : value,
                  scaffold.address(reg));
}

function buildStoreFloat(llvm:Builder builder, Scaffold scaffold, llvm:Value value, bir:Register reg) {
    builder.store(scaffold.getRepr(reg).base == BASE_REPR_TAGGED ? buildTaggedFloat(builder, scaffold, value) : value,
                  scaffold.address(reg));
}

function buildStoreBoolean(llvm:Builder builder, Scaffold scaffold, llvm:Value value, bir:Register reg) {
    builder.store(scaffold.getRepr(reg).base == BASE_REPR_TAGGED ? buildTaggedBoolean(builder, value) : value,
                  scaffold.address(reg));
}

function buildStoreTagged(llvm:Builder builder, Scaffold scaffold, llvm:Value value, bir:Register reg) {
    return builder.store(buildUntagged(builder, scaffold, <llvm:PointerValue>value, scaffold.getRepr(reg)), scaffold.address(reg));
}

function buildUntagged(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue value, Repr targetRepr) returns llvm:Value {
    match targetRepr.base {
        BASE_REPR_INT => {
            return buildUntagInt(builder, scaffold, value);
        }
        BASE_REPR_FLOAT => {
            return buildUntagFloat(builder, scaffold, value);
        }
        BASE_REPR_BOOLEAN => {
            return buildUntagBoolean(builder, value);
        }
        BASE_REPR_TAGGED => {
            return value;
        }
    }
    panic err:impossible("unreached in buildUntagged");
}

function buildRepr(llvm:Builder builder, Scaffold scaffold, bir:Operand operand, Repr targetRepr) returns llvm:Value|BuildError {
    var [sourceRepr, value] = check buildReprValue(builder, scaffold, operand);
    return buildConvertRepr(builder, scaffold, sourceRepr, value, targetRepr);
}

function buildConvertRepr(llvm:Builder builder, Scaffold scaffold, Repr sourceRepr, llvm:Value value, Repr targetRepr) returns llvm:Value|BuildError {
    BaseRepr sourceBaseRepr = sourceRepr.base;
    BaseRepr targetBaseRepr = targetRepr.base;
    if sourceBaseRepr == targetBaseRepr {
        return value;
    }
    if targetBaseRepr == BASE_REPR_TAGGED {
        if sourceBaseRepr == BASE_REPR_INT {
            return buildTaggedInt(builder, scaffold, value);
        }
        else if sourceBaseRepr == BASE_REPR_FLOAT {
            return buildTaggedFloat(builder, scaffold, value);
        }
        else if sourceBaseRepr == BASE_REPR_BOOLEAN {
            return buildTaggedBoolean(builder, value);
        }
    }
    // this shouldn't ever happen I think
    return err:unimplemented("unimplemented conversion required");
}

function buildTaggedBoolean(llvm:Builder builder, llvm:Value value) returns llvm:Value {
    return builder.getElementPtr(llvm:constNull(LLVM_TAGGED_PTR),
                                     [builder.iBitwise("or",
                                                       builder.zExt(value, LLVM_INT),
                                                       llvm:constInt(LLVM_INT, TAG_BOOLEAN))]);
}

function buildTaggedInt(llvm:Builder builder, Scaffold scaffold, llvm:Value value) returns llvm:PointerValue {
    return <llvm:PointerValue>builder.call(buildRuntimeFunctionDecl(scaffold, intToTaggedFunction), [value]);
}

function buildTaggedFloat(llvm:Builder builder, Scaffold scaffold, llvm:Value value) returns llvm:PointerValue {
    return <llvm:PointerValue>builder.call(buildRuntimeFunctionDecl(scaffold, floatToTaggedFunction), [value]);
}

function buildTaggedPtr(llvm:Builder builder, llvm:PointerValue mem, int tag) returns llvm:PointerValue {
    return builder.getElementPtr(mem, [llvm:constInt(LLVM_INT, tag)]);
}

function buildTypedAlloc(llvm:Builder builder, Scaffold scaffold, llvm:Type ty) returns llvm:PointerValue {
    return builder.bitCast(buildUntypedAlloc(builder, scaffold, ty), heapPointerType(ty));
}

function buildUntypedAlloc(llvm:Builder builder, Scaffold scaffold, llvm:Type ty) returns llvm:PointerValue {
    return <llvm:PointerValue>builder.call(buildRuntimeFunctionDecl(scaffold, allocFunction),
                                           [llvm:constInt(LLVM_INT, typeSize(ty))]);
}

// XXX this should go in llvm module, because it needs to know about alignment
function typeSize(llvm:Type ty) returns int {
    if ty is llvm:PointerType || ty == "i64" {
        return 8;
    }
    else if ty is llvm:StructType {
        int size = 0;
        foreach var elemTy in ty.elementTypes {
            size += typeSize(elemTy);
        }
        return size;
    }
    else if ty is llvm:ArrayType {
        if ty.elementCount == 0 {
            panic error("cannot take size of 0-length array");
        }
        return ty.elementCount * typeSize(ty.elementType);
    }
    panic error("size of unsized type");
}

function buildHasTag(llvm:Builder builder, llvm:PointerValue tagged, int tag) returns llvm:Value {
    return buildTestTag(builder, tagged, tag, TAG_MASK);    
}

function buildHasBasicTypeTag(llvm:Builder builder, llvm:PointerValue tagged, int basicTypeTag) returns llvm:Value {
    return buildTestTag(builder, tagged, basicTypeTag, TAG_BASIC_TYPE_MASK);    
}

function buildTestTag(llvm:Builder builder, llvm:PointerValue tagged, int tag, int mask) returns llvm:Value {
    return builder.iCmp("eq", builder.iBitwise("and", buildTaggedPtrToInt(builder, tagged),
                                                       llvm:constInt(LLVM_INT, mask)),
                              llvm:constInt(LLVM_INT, tag));

}

function buildHasTagInSet(llvm:Builder builder, llvm:PointerValue tagged, t:UniformTypeBitSet bitSet) returns llvm:Value {
    return builder.iCmp("ne",
                        builder.iBitwise("and",
                                         builder.iBitwise("shl",
                                                          llvm:constInt(LLVM_INT, 1),
                                                          builder.iBitwise("lshr",
                                                                           // need to mask out the 0x20 bit
                                                                           builder.iBitwise("and",
                                                                                            buildTaggedPtrToInt(builder, tagged),
                                                                                            llvm:constInt(LLVM_INT, TAG_MASK)),
                                                                           llvm:constInt(LLVM_INT, TAG_SHIFT))),
                                         llvm:constInt(LLVM_INT, bitSet)),
                        llvm:constInt(LLVM_INT, 0));
}

function buildUntagInt(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue tagged) returns llvm:Value {
    return <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, taggedToIntFunction), [tagged]);
}

function buildUntagFloat(llvm:Builder builder, Scaffold scaffold, llvm:PointerValue tagged) returns llvm:Value {
    return <llvm:Value>builder.call(buildRuntimeFunctionDecl(scaffold, taggedToFloatFunction), [tagged]);
}

function buildUntagBoolean(llvm:Builder builder, llvm:PointerValue tagged) returns llvm:Value {
    return builder.trunc(buildTaggedPtrToInt(builder, tagged), LLVM_BOOLEAN);
}

function buildTaggedPtrToInt(llvm:Builder builder, llvm:PointerValue tagged) returns llvm:Value {
    return builder.ptrToInt(builder.addrSpaceCast(tagged, LLVM_TAGGED_PTR_WITHOUT_ADDR_SPACE), LLVM_INT);
}

function buildReprValue(llvm:Builder builder, Scaffold scaffold, bir:Operand operand) returns [Repr, llvm:Value]|BuildError {
    if operand is bir:Register {
        return buildLoad(builder, scaffold, operand);
    }
    else if operand is string {
        return [REPR_STRING, check buildConstString(builder, scaffold, operand)];
    }
    else {
        return buildSimpleConst(operand);
    }
}

function buildConstString(llvm:Builder builder, Scaffold scaffold, string str) returns llvm:ConstPointerValue|BuildError {   
    return check scaffold.getString(str);
}

function addStringDefn(llvm:Context context, llvm:Module mod, int defnIndex, string str) returns llvm:ConstPointerValue|BuildError {
    int nCodePoints = str.length();
    byte[] bytes = str.toBytes();
    int nBytes = bytes.length();

    llvm:Type ty;
    llvm:ConstValue val;
    StringVariant variant;
    if nCodePoints == 1 || (nBytes == nCodePoints && nBytes <= 7) {
        int encoded = 0;
        foreach int i in 0 ..< 7 {
            // JBUG cast needed #31867
            encoded |= <int>(i < nBytes ? bytes[i] : 0xFF) << i*8;
        }
        encoded |= FLAG_IMMEDIATE|TAG_STRING;
        return context.constGetElementPtr(llvm:constNull(LLVM_TAGGED_PTR), [llvm:constInt(LLVM_INT, encoded)]);
    }
    // if nBytes == nCodePoints && nBytes <= 0xFF {
    //     // We want the total size including the header to be a multiple of 8
    //     int nBytesPadded = padBytes(bytes, 1);
    //     val = context.constStruct([llvm:constInt("i8", nBytes), context.constString(bytes)]);
    //     ty = llvm:structType(["i8", llvm:arrayType("i8", nBytesPadded)]);
    //     variant = STRING_VARIANT_SMALL;
    // }
    else if nBytes <= 0xFFFF {
        int nBytesPadded = padBytes(bytes, 4);
        val = context.constStruct([llvm:constInt("i16", nBytes), llvm:constInt("i16", nCodePoints), context.constString(bytes)]);
        ty = llvm:structType(["i16", "i16", llvm:arrayType("i8", nBytesPadded)]);
        variant = STRING_VARIANT_MEDIUM;
    }
    else {
        int nBytesPadded = padBytes(bytes, 16);
        val = context.constStruct([llvm:constInt("i64", nBytes), llvm:constInt("i64", nCodePoints), context.constString(bytes)]);
        ty = llvm:structType(["i64", "i64", llvm:arrayType("i8", nBytesPadded)]);
        variant = STRING_VARIANT_LARGE;
    }
    llvm:ConstPointerValue ptr = mod.addGlobal(ty,
                                               stringDefnSymbol(defnIndex),
                                               initializer = val,
                                               align = 8,
                                               isConstant = true,
                                               unnamedAddr = true,
                                               linkage = "internal");
    return context.constGetElementPtr(context.constAddrSpaceCast(context.constBitCast(ptr, LLVM_TAGGED_PTR_WITHOUT_ADDR_SPACE), LLVM_TAGGED_PTR),
                                      [llvm:constInt(LLVM_INT, TAG_STRING | <int>variant)]);
}

// Returns the new, padded length
function padBytes(byte[] bytes, int headerSize) returns int {
    int nBytes = bytes.length();
    int nBytesPadded = (((nBytes + headerSize + 7) >> 3) << 3) - headerSize;
    foreach int i in 0 ..< nBytesPadded - nBytes {
        bytes.push(0);
    }
    return nBytesPadded;
}

function buildLoad(llvm:Builder builder, Scaffold scaffold, bir:Register reg) returns [Repr, llvm:Value] {
    return [scaffold.getRepr(reg), builder.load(scaffold.address(reg))];
}

function buildSimpleConst(bir:SimpleConstOperand operand) returns [Repr, llvm:Value] {
    if operand is int {
        return [REPR_INT, llvm:constInt(LLVM_INT, operand)];
    }
    else if operand is float {
        return [REPR_FLOAT, llvm:constFloat(LLVM_DOUBLE, operand)];
    }
    else if operand is () {
        return [REPR_NIL, buildConstNil()];
    }
    else {
        // operand is boolean
        return [REPR_BOOLEAN, llvm:constInt(LLVM_BOOLEAN, operand ? 1 : 0)];
    }
}

function buildString(llvm:Builder builder, Scaffold scaffold, bir:StringOperand operand) returns llvm:Value|BuildError {
    if operand is string {
        return buildConstString(builder, scaffold, operand);
    }
    else {
        return builder.load(scaffold.address(operand));
    }
}

// Build a value as REPR_INT
function buildInt(llvm:Builder builder, Scaffold scaffold, bir:IntOperand operand) returns llvm:Value {
    if operand is int {
        return llvm:constInt(LLVM_INT, operand);
    }
    else {
        return builder.load(scaffold.address(operand));
    }
}

// Build a value as REPR_FLOAT
function buildFloat(llvm:Builder builder, Scaffold scaffold, bir:FloatOperand operand) returns llvm:Value {
    if operand is float {
        return llvm:constFloat(LLVM_DOUBLE, operand);
    }
    else {
        return builder.load(scaffold.address(operand));
    }
}

// Build a value as REPR_BOOLEAN
function buildBoolean(llvm:Builder builder, Scaffold scaffold, bir:BooleanOperand operand) returns llvm:Value {
    if operand is boolean {
        return llvm:constInt(LLVM_BOOLEAN, operand ? 1 : 0);
    }
    else {
        return builder.load(scaffold.address(operand));
    }
}

final readonly & map<llvm:IntrinsicFunctionName> binaryIntIntrinsics = {
    "+": "sadd.with.overflow.i64",
    "-": "ssub.with.overflow.i64",
    "*": "smul.with.overflow.i64"
};

final readonly & map<llvm:IntArithmeticOp> intArithmeticOps = {
    "+": "add",
    "-": "sub",
    "*": "mul"
};

final readonly & map<llvm:FloatArithmeticOp> floatArithmeticOps = {
    "+": "fadd",
    "-": "fsub",
    "*": "fmul",
    "/": "fdiv",
    "%": "frem"
};

// final readonly & map<llvm:BinaryIntOp> binaryIntOps = {
//     "+": "add",
//     "-": "sub",
//     "*": "mul",
//     "/": "sdiv",
//     "%": "srem"
// };

// function buildBinaryIntOp(bir:ArithmeticBinaryOp op) returns llvm:BinaryIntOp {
//     return <llvm:BinaryIntOp>binaryIntOps[op];
// }

function buildBinaryIntIntrinsic(bir:ArithmeticBinaryOp op) returns llvm:IntrinsicFunctionName? {
    return binaryIntIntrinsics[op];
}

final readonly & map<llvm:IntPredicate> signedIntPredicateOps = {
    "<": "slt",
    "<=": "sle",
    ">": "sgt",
    ">=": "sge"
};

final readonly & map<llvm:IntPredicate> unsignedIntPredicateOps = {
    "<": "ult",
    "<=": "ule",
    ">": "ugt",
    ">=": "uge"
};

final readonly & map<llvm:FloatPredicate> floatPredicateOps = {
    "<": "olt",
    "<=": "ole",
    ">": "ogt",
    ">=": "oge"
};

function buildIntCompareOp(bir:OrderOp op) returns llvm:IntPredicate {
    return <llvm:IntPredicate>signedIntPredicateOps[op];
}

function buildFloatCompareOp(bir:OrderOp op) returns llvm:FloatPredicate {
    return <llvm:FloatPredicate>floatPredicateOps[op];
}

function buildBooleanCompareOp(bir:OrderOp op) returns llvm:IntPredicate {
    return <llvm:IntPredicate>unsignedIntPredicateOps[op];
}

function buildFunctionSignature(bir:FunctionSignature signature) returns llvm:FunctionType|BuildError {
    llvm:Type[] paramTypes = from var ty in signature.paramTypes select (check semTypeRepr(ty)).llvm;
    RetRepr repr = check semTypeRetRepr(signature.returnType);
    llvm:FunctionType ty = {
        returnType: repr.llvm,
        paramTypes: paramTypes.cloneReadOnly()
    };
    return ty;
}

function buildConstNil() returns llvm:Value {
    return llvm:constNull(LLVM_NIL_TYPE);
}

function buildConstBoolean(boolean b) returns llvm:Value {
    return llvm:constInt(LLVM_BOOLEAN, b ? 1 : 0);
}

// Maps int to i64
final Repr REPR_INT = { base: BASE_REPR_INT, llvm: LLVM_INT };
// Maps float to llvm double
final Repr REPR_FLOAT = { base: BASE_REPR_FLOAT, llvm: LLVM_DOUBLE };
// Maps int to i1
final Repr REPR_BOOLEAN = { base: BASE_REPR_BOOLEAN, llvm: LLVM_BOOLEAN };

final TaggedRepr REPR_NIL = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:NIL };
final TaggedRepr REPR_STRING = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:STRING };
final TaggedRepr REPR_LIST_RW = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:LIST_RW };
final TaggedRepr REPR_LIST = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:LIST };
final TaggedRepr REPR_MAPPING_RW = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:MAPPING_RW };
final TaggedRepr REPR_MAPPING = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:MAPPING };
final TaggedRepr REPR_ERROR = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:ERROR };

final TaggedRepr REPR_TOP = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:TOP };
final TaggedRepr REPR_ANY = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: t:ANY };
// JBUG this goes wrong when you use REPR_VOID as a type as in buildRet
// const int REPR_VOID = REPR_TAGGED + 1;
final VoidRepr REPR_VOID = { base: BASE_REPR_VOID, llvm: LLVM_VOID };

final readonly & record {|
    t:UniformTypeBitSet domain;
    Repr repr;
|}[] typeReprs = [
    // These are ordered from most to least specific
    { domain: t:INT, repr: REPR_INT },
    { domain: t:FLOAT, repr: REPR_FLOAT },
    { domain: t:BOOLEAN, repr: REPR_BOOLEAN },
    { domain: t:NIL, repr: REPR_NIL },
    { domain: t:STRING, repr: REPR_STRING },
    { domain: t:LIST_RW, repr: REPR_LIST_RW },
    { domain: t:LIST, repr: REPR_LIST },
    { domain: t:MAPPING_RW, repr: REPR_MAPPING_RW },
    { domain: t:MAPPING, repr: REPR_MAPPING },
    { domain: t:ERROR, repr: REPR_ERROR },
    { domain: t:ANY, repr: REPR_ANY },
    { domain: t:TOP, repr: REPR_TOP }
];

function semTypeRetRepr(t:SemType ty) returns RetRepr|BuildError {
    if ty === t:NIL {
        return REPR_VOID;
    }
    return semTypeRepr(ty);
}

// Return the representation for a SemType.
function semTypeRepr(t:SemType ty) returns Repr|BuildError {
    t:UniformTypeBitSet w = t:widenToUniformTypes(ty);    
    foreach var tr in typeReprs {
        if w == tr.domain {
            return tr.repr;
        }
    }
    if w == t:NEVER {
        panic err:impossible("allocate register with never type");
    }
    // subset07 does not allow unions of list/mapppings with other things
    // apart from `any`
    int supported = t:NIL|t:BOOLEAN|t:INT|t:FLOAT|t:STRING|t:ERROR;
    // DECIMAL is here for ConvertToInt or ConvertToFloat 
    if (w | supported | t:DECIMAL) == t:TOP || (w & supported) == w {
        TaggedRepr repr = { base: BASE_REPR_TAGGED, llvm: LLVM_TAGGED_PTR, subtype: w };
        return repr;
    }
    return err:unimplemented("unimplemented type (" + w.toHexString() + ")");
}

function heapPointerType(llvm:Type ty) returns llvm:PointerType {
    return llvm:pointerType(ty, HEAP_ADDR_SPACE);
}

function mangleRuntimeSymbol(string name) returns string {
    return "_bal_" + name;
}

// This is just enough to get us started.
// C++ starts mangled names with `_Z` (why `Z`?),
// so I'm starting Ballerina names with `_B`.
function mangleExternalSymbol(bir:ExternalSymbol symbol) returns string {
    string[] names = symbol.module.names;
    // use the last segment of the module name to distinguish between lang.* modules
    return "_B" + names[names.length() - 1] + "__" + symbol.identifier;
}

function mangleInternalSymbol(bir:ModuleId modId, bir:InternalSymbol symbol) returns string {
    return "_B_" + symbol.identifier;
}

function stringDefnSymbol(int n) returns string {
    return ".str" + n.toString();
}

