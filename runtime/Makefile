LLVM_SUFFIX?=-11
export CLANG ?= clang$(LLVM_SUFFIX)
LLVM_AS ?= llvm-as$(LLVM_SUFFIX)
OPT ?= opt$(LLVM_SUFFIX)
LLC ?= llc$(LLVM_SUFFIX)
export LLVM_LINK ?= llvm-link$(LLVM_SUFFIX)
VALGRIND ?= valgrind
OBJS=gc_cheney.o gc_none.o main.o mapping.o panic.o print.o string.o int.o third-party/dtoa/emyg_dtoa.o
LIST_OBJ=list.o
BCS=eq_inline.bc int_inline.bc list_inline.bc mapping_inline.bc string_inline.bc float_ir_inline.bc float_inline.bc

INCLUDES=tag.h balrt.h balrt_inline.h
AR=ar
export LIB=balrt.a
export BCLIB=balrt_inline.bc

all: $(LIB) $(BCLIB)
	$(MAKE) -C tests all

test: all
	$(MAKE) -C tests test

testCoverage: $(LIB) $(BCLIB)
	$(MAKE) -C tests testCoverage

$(LIB): $(OBJS) $(LIST_OBJ)
	$(MAKE) -C gc-roots all
	$(AR) r $@ $^

$(BCLIB): $(BCS)
	$(LLVM_LINK) -o - -S $^ | sed -e '/define .*@_[Bb][a-zA-Z]/s/^define /define linkonce_odr /' -e '/target datalayout/ s/"$$/-ni:1"/' | $(LLVM_AS) >$@

$(LIST_OBJ): list.c
	$(CLANG) -O0 -S -emit-llvm -o list.ll $<
	sed -i -e 's/noinline//' -e 's/optnone//' \
	-e '/define internal i8 addrspace(1)\* @taggedToPtr/ s/ {/ noinline {/' \
	-e '/define dso_local i64 @_bal_list_set/s/ {/ gc "statepoint-example" {/' \
	-e '/define dso_local void @_bal_array_grow/s/ {/ gc "statepoint-example" {/' \
	-e '/define internal i8 addrspace(1)\* @taggedToPtr/s/ {/ "gc-leaf-function" {/' \
	-e '/define internal i64 @taggedPtrBits/s/ {/ "gc-leaf-function" {/' \
	-e '/target datalayout/ s/"$$/-ni:1"/' list.ll
	$(OPT) -S -O2 --rewrite-statepoints-for-gc -o list_opt.ll list.ll
	$(LLC) -O2 --filetype=obj -o $@ list_opt.ll

%.o: %.c
	$(CLANG) $(CFLAGS) -c -o $@ $<

# we have to use -O2 here, otherwise the function will get a noinline attribute
%.bc: %.c
	$(CLANG) $(CFLAGS) -c -O2 -emit-llvm -o $@ $<

%.bc: %.ll
	$(LLVM_AS) --data-layout=$(shell $(CLANG) -x c /dev/null -emit-llvm -S -o - | sed -n 's/target datalayout = \(".*"\)/\1/p') -o=$@ $<

$(OBJS) $(BCS): $(INCLUDES)

clean:
	-rm -f $(OBJS) $(BCS) $(LIB) $(BCLIB) $(LIST_OBJ) list.ll list_opt.ll
	$(MAKE) -C tests clean
	$(MAKE) -C gc-roots clean

.PHONY: test all
