// Use the types module to type-check the BIR

import wso2/nballerina.types as t;
import wso2/nballerina.err;

class VerifyContext {
    private final Module mod;
    private final t:TypeCheckContext tc;
    private final FunctionDefn defn;
    private final t:SemType anydataType;

    function init(Module mod, FunctionDefn defn) {
        self.mod = mod;
        t:TypeCheckContext tc  = mod.getTypeCheckContext();
        self.tc = tc;
        self.defn = defn;
        self.anydataType = createAnydata(tc.env);
    }

    function isSubtype(t:SemType s, t:SemType t) returns boolean {
        return t:isSubtype(self.tc, s, t);
    }

    function isEmpty(t:SemType t) returns boolean {
        return t:isEmpty(self.tc, t);
    }

    function isAnydata(t:SemType t) returns boolean {
        return t:isSubtype(self.tc, t, self.anydataType);
    }

    function typeEnv() returns t:Env {
        return self.tc.env;
    }

    function err(err:Message msg, Position? pos = ()) returns err:Semantic {
        return err:semantic(msg, loc=err:location(self.mod.getPartFile(self.defn.partIndex), pos), functionName=self.defn.symbol.identifier);
    }

    function returnType() returns t:SemType => self.defn.signature.returnType;

    function symbolToString(Symbol sym) returns string {
        return symbolToString(self.mod, self.defn.partIndex, sym);
    }
}

// approximation for subset07
function createAnydata(t:Env env) returns t:SemType {
    t:ListDefinition listDef = new;
    t:SemType arrayType = listDef.define(env, [], t:SIMPLE_OR_STRING);
    t:MappingDefinition mapDef = new;
    t:SemType mapType = mapDef.define(env, [], t:SIMPLE_OR_STRING);
    return t:union(t:SIMPLE_OR_STRING, t:union(arrayType, mapType));
}

public function verifyFunctionCode(Module mod, FunctionDefn defn, FunctionCode code) returns err:Semantic? {
    VerifyContext cx = new(mod, defn);
    foreach BasicBlock b in code.blocks {
        check verifyBasicBlock(cx, b);
    }
}

type IntBinaryInsn IntArithmeticBinaryInsn|IntBitwiseBinaryInsn;

function verifyBasicBlock(VerifyContext vc, BasicBlock bb) returns err:Semantic? {
    foreach Insn insn in bb.insns {
        check verifyInsn(vc, insn);
    }
}

function verifyInsn(VerifyContext vc, Insn insn) returns err:Semantic? {
    string name = insn.name;
    if insn is IntBinaryInsn {
        // XXX need to check result also
        // different rules for bitwise
        check verifyOperandInt(vc, name, insn.operands[0]);
        check verifyOperandInt(vc, name, insn.operands[1]);
    }
    if insn is FloatArithmeticBinaryInsn {
        check verifyOperandFloat(vc, name, insn.operands[0]);
        check verifyOperandFloat(vc, name, insn.operands[1]);
    }
    if insn is FloatNegateInsn {
        check verifyOperandFloat(vc, name, insn.operand);
    }
    else if insn is BooleanNotInsn {
        check verifyOperandBoolean(vc, name, insn.operand);
    }
    else if insn is CompareInsn {
        check verifyCompare(vc, insn);
    }
    else if insn is EqualityInsn {
        check verifyEquality(vc, insn);
    }
    else if insn is AssignInsn {
        check verifyOperandType(vc, insn.operand, insn.result.semType, "value is not a subtype of the LHS");
    }
    else if insn is CondBranchInsn {
        check verifyOperandBoolean(vc, name, insn.operand);
    }
    else if insn is RetInsn {
        check verifyOperandType(vc, insn.operand, vc.returnType(), "value is not a subtype of the return type");
    }
    else if insn is PanicInsn {
        check verifyOperandError(vc, name, insn.operand);
    }
    else if insn is CallInsn {
        check verifyCall(vc, insn);
    }
    else if insn is TypeCastInsn {
        check verifyTypeCast(vc, insn);
    }
    else if insn is ConvertToIntInsn {
        check verifyConvertToIntInsn(vc, insn);
    }
    else if insn is ConvertToFloatInsn {
        check verifyConvertToFloatInsn(vc, insn);
    }
    else if insn is ListConstructInsn {
        check verifyListConstruct(vc, insn);
    }
    else if insn is MappingConstructInsn {
        check verifyMappingConstruct(vc, insn);
    }
    else if insn is ListGetInsn {
        check verifyListGet(vc, insn);
    }
    else if insn is ListSetInsn {
        check verifyListSet(vc, insn);
    }
     else if insn is MappingGetInsn {
        check verifyMappingGet(vc, insn);
    }
    else if insn is MappingSetInsn {
        check verifyMappingSet(vc, insn);
    }
    else if insn is ErrorConstructInsn {
        check verifyOperandString(vc, name, insn.operand);
    }
}

function verifyCall(VerifyContext vc, CallInsn insn) returns err:Semantic? {
    FunctionRef func = <FunctionRef>insn.func;
    FunctionSignature sig = func.signature;
    int nSuppliedArgs = insn.args.length();
    int nExpectedArgs = sig.paramTypes.length();
    if nSuppliedArgs != nExpectedArgs {
        string name = vc.symbolToString(func.symbol);
        if nSuppliedArgs < nExpectedArgs {
            return vc.err(`too few arguments for call to function ${name}`);
        }
        else {
            return vc.err(`too many arguments for call to function ${name}`);
        }
    }
    foreach int i in 0 ..< nSuppliedArgs {
        check verifyOperandType(vc, insn.args[i], sig.paramTypes[i], `wrong argument type for parameter ${i + 1} in call to function ${vc.symbolToString(func.symbol)}`);
    }
}

function verifyListConstruct(VerifyContext vc, ListConstructInsn insn) returns err:Semantic? {
    t:SemType ty = insn.result.semType;
    if !vc.isSubtype(ty, t:LIST_RW) {
        return vc.err("bad BIR: inherent type of list construct is not a mutable list");
    }
    t:UniformTypeBitSet? memberType = t:simpleArrayMemberType(vc.typeEnv(), ty);
    if memberType == () {
        return vc.err("bad BIR: inherent type of list is of an unsupported type");
    }
    else {
        foreach var operand in insn.operands {
            check verifyOperandType(vc, operand, memberType, "list constructor member of not a subtype of array member type");
        }
    }
}

function verifyMappingConstruct(VerifyContext vc, MappingConstructInsn insn) returns err:Semantic? {
    t:SemType ty = insn.result.semType;
    if !vc.isSubtype(ty, t:MAPPING_RW) {
        return vc.err("bad BIR: inherent type of mapping construct is not a mutable mapping");
    }
    t:UniformTypeBitSet? memberType = t:simpleMapMemberType(vc.typeEnv(), ty);
    if memberType == () {
        return vc.err("bad BIR: inherent type of map is of an unsupported type");
    }
    else {
        foreach var operand in insn.operands {
            check verifyOperandType(vc, operand, memberType, "mapping constructor member of not a subtype of map member type");
        }
    }
}

function verifyListGet(VerifyContext vc, ListGetInsn insn) returns err:Semantic? {
    check verifyOperandInt(vc, insn.name, insn.operand);
    if !vc.isSubtype(insn.list.semType, t:LIST) {
        return vc.err("list get applied to non-list");
    }
    t:UniformTypeBitSet? memberType = t:simpleArrayMemberType(vc.typeEnv(), insn.list.semType);
    if memberType == () || !vc.isSubtype(memberType, insn.result.semType) {
        return vc.err("bad BIR: unsafe type for result ListGet", pos=insn.position);
    }
}

function verifyListSet(VerifyContext vc, ListSetInsn insn) returns err:Semantic? {
    check verifyOperandInt(vc, insn.name, insn.index);
    if !vc.isSubtype(insn.list.semType, t:LIST) {
        return vc.err("list set applied to non-list");
    }
    t:UniformTypeBitSet? memberType = t:simpleArrayMemberType(vc.typeEnv(), insn.list.semType);
    if memberType == () {
        return vc.err("ListSet on unsupported list type");
    }
    else {
        return verifyOperandType(vc, insn.operand, memberType, "value assigned to member of list is not a subtype of array member type");
    }
}

function verifyMappingGet(VerifyContext vc, MappingGetInsn insn) returns err:Semantic? {
    check verifyOperandString(vc, insn.name, insn.operands[1]);
    if !vc.isSubtype(insn.operands[0].semType, t:MAPPING) {
        return vc.err("mapping get applied to non-mapping");
    }
    t:UniformTypeBitSet? memberType = t:simpleMapMemberType(vc.typeEnv(), insn.operands[0].semType);
    if memberType == () || !vc.isSubtype(t:union(memberType, t:NIL), insn.result.semType) {
        return vc.err("bad BIR: unsafe type for result MappingGet");
    }
}

function verifyMappingSet(VerifyContext vc, MappingSetInsn insn) returns err:Semantic? {
    check verifyOperandString(vc, insn.name, insn.operands[1]);
    if !vc.isSubtype(insn.operands[0].semType, t:MAPPING) {
        return vc.err("mapping set applied to non-mapping");
    }
    t:UniformTypeBitSet? memberType = t:simpleMapMemberType(vc.typeEnv(), insn.operands[0].semType);
    if memberType == () {
        return vc.err("MappingSet on unsupported mapping type");
    }
    else {
        return verifyOperandType(vc, insn.operands[2], memberType, "value assigned to member of mapping is not a subtype of map member type");
    }
}

function verifyTypeCast(VerifyContext vc, TypeCastInsn insn) returns err:Semantic? {
    if vc.isEmpty(insn.result.semType) {
        return vc.err("type cast cannot succeed");
    }
    // These should not happen with the nballerina front-end
    if !vc.isSubtype(insn.result.semType, insn.operand.semType) {
        return vc.err("bad BIR: result of type cast is not subtype of operand");
    }
    if !vc.isSubtype(insn.result.semType, insn.semType) {
        return vc.err("bad BIR: result of type cast is not subtype of cast to type");
    }
}

function verifyConvertToIntInsn(VerifyContext vc, ConvertToIntInsn insn) returns err:Semantic? {
    if vc.isEmpty(t:intersect(t:diff(insn.operand.semType, t:INT), t:NUMBER)) {
        return vc.err("bad BIR: operand type of ConvertToInt has no non-integral numeric component");
    }
    if !vc.isSubtype(t:union(t:diff(insn.operand.semType, t:NUMBER), t:INT), insn.result.semType) {
        return vc.err("bad BIR: result type of ConvertToInt does not contain everything it should");
    }
    if !vc.isEmpty(t:intersect(t:diff(insn.result.semType, t:INT), t:NUMBER)) {
        return vc.err("bad BIR: result type of ConvertToInt contains non-integral numeric type");
    }
}

function verifyConvertToFloatInsn(VerifyContext vc, ConvertToFloatInsn insn) returns err:Semantic? {
    if vc.isEmpty(t:intersect(t:diff(insn.operand.semType, t:FLOAT), t:NUMBER)) {
        return vc.err("bad BIR: operand type of ConvertToFloat has no non-float numeric component");
    }
    if !vc.isSubtype(t:union(t:diff(insn.operand.semType, t:NUMBER), t:FLOAT), insn.result.semType) {
        return vc.err("bad BIR: result type of ConvertToFloat does not contain everything it should");
    }
    if !vc.isEmpty(t:intersect(t:diff(insn.result.semType, t:FLOAT), t:NUMBER)) {
        return vc.err("bad BIR: result type of ConvertToFloat contains non-float numeric type");
    }
}

function verifyCompare(VerifyContext vc, CompareInsn insn) returns err:Semantic? {
    t:UniformTypeBitSet expectType;
    OrderType ot = insn.orderType;
    if ot is OptOrderType {
        expectType = t:uniformTypeUnion((1 << t:UT_NIL) | (1 << ot.opt ));
    }
    else if ot is UniformOrderType {
        expectType  = t:uniformType(ot);
    }
    else {
        panic err:impossible("array order type");
    }
    foreach var operand in insn.operands {
        t:SemType operandType;
        if operand is Register {
            operandType = operand.semType;
        }
        else {
            operandType = t:constBasicType(operand);
        }
        if !t:isSubtypeSimple(operandType, expectType) {
            return vc.err(`operand of ${insn.op} does not match order type`);
        }
    }
}

function verifyEquality(VerifyContext vc, EqualityInsn insn) returns err:Semantic? {
    Operand lhs = insn.operands[0];
    Operand rhs = insn.operands[1];
    if lhs is Register {
        if rhs is Register {
            t:SemType intersectType = t:intersect(lhs.semType, rhs.semType);
            if !vc.isEmpty(intersectType) {
                // JBUG #31749 cast should not be needed
                if (<string>insn.op).length() == 2 && !vc.isAnydata(lhs.semType) && !vc.isAnydata(rhs.semType) {
                    return vc.err("at least one operand of an == or != expression must be a subtype of anydata");
                }
                return;
            }
        }
        else if t:containsConst(lhs.semType, rhs) {
            return;
        }
    }
    else if rhs is Register {
        if t:containsConst(rhs.semType, lhs) {
            return;
        }
    }
    else if isEqual(lhs, rhs) {
        return;
    }
    return vc.err(`intersection of operands of operator ${insn.op} is empty`);
}

// After JBUG #17977, #32245 is fixed, replace by ==
function isEqual(ConstOperand c1, ConstOperand c2) returns boolean {
    return c1 is float && c2 is float ? (c1 == c2 || (float:isNaN(c1) && float:isNaN(c2))) : c1 == c2;
}

function verifyOperandType(VerifyContext vc, Operand operand, t:SemType semType, err:Message msg) returns err:Semantic? {
    if operand is Register {
        if !vc.isSubtype(operand.semType, semType) {
            return vc.err(msg);
        }
    }
    else if !t:containsConst(semType, operand) {
        return vc.err(msg);
    }
}

function verifyOperandString(VerifyContext vc, string insnName, StringOperand operand) returns err:Semantic? {
    if operand is Register {
        return verifyRegisterSemType(vc, insnName, operand, t:STRING, "string");
    }
}

function verifyOperandInt(VerifyContext vc, string insnName, IntOperand operand) returns err:Semantic? {
    if operand is Register {
        return verifyRegisterSemType(vc, insnName, operand, t:INT, "int");
    }
}

function verifyOperandFloat(VerifyContext vc, string insnName, FloatOperand operand) returns err:Semantic? {
    if operand is Register {
        return verifyRegisterSemType(vc, insnName, operand, t:FLOAT, "float");
    }
}

function verifyOperandBoolean(VerifyContext vc, string insnName, BooleanOperand operand) returns err:Semantic? {
    if operand is Register {
        return verifyRegisterSemType(vc,insnName, operand, t:BOOLEAN, "boolean");
    }
}

function verifyOperandError(VerifyContext vc, string insnName, Register operand) returns err:Semantic? {
    return verifyRegisterSemType(vc, insnName, operand, t:ERROR, "error");
}

function verifyRegisterSemType(VerifyContext vc, string insnName, Register operand, t:SemType semType, string typeName) returns err:Semantic? {
    if !vc.isSubtype(operand.semType, semType) {
        return operandTypeErr(vc, insnName, typeName);
    }
}

function operandTypeErr(VerifyContext vc, string insnName, string typeName) returns err:Semantic {
    return vc.err(`operands of ${insnName} must be subtype of ${typeName}`);
}
