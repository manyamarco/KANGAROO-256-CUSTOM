ifdef gpu
SRC = SECPK1/IntGroup.cpp main.cpp SECPK1/Random.cpp \
	Timer.cpp SECPK1/Int.cpp SECPK1/IntMod.cpp \
	SECPK1/Point.cpp SECPK1/SECP256K1.cpp \
	GPU/GPUEngine.o Kangaroo.cpp HashTable.cpp \
	Backup.cpp Thread.cpp Check.cpp Merge.cpp PartMerge.cpp
OBJDIR = obj
OBJET = $(addprefix $(OBJDIR)/, \
	SECPK1/IntGroup.o main.o SECPK1/Random.o \
	Timer.o SECPK1/Int.o SECPK1/IntMod.o \
	SECPK1/Point.o SECPK1/SECP256K1.o \
	GPU/GPUEngine.o Kangaroo.o HashTable.o Thread.o \
	Backup.o Check.o Merge.o PartMerge.o)
else
SRC = SECPK1/IntGroup.cpp main.cpp SECPK1/Random.cpp \
	Timer.cpp SECPK1/Int.cpp SECPK1/IntMod.cpp \
	SECPK1/Point.cpp SECPK1/SECP256K1.cpp \
	Kangaroo.cpp HashTable.cpp Thread.cpp Check.cpp \
	Backup.cpp Merge.cpp PartMerge.cpp
OBJDIR = obj
OBJET = $(addprefix $(OBJDIR)/, \
	SECPK1/IntGroup.o main.o SECPK1/Random.o \
	Timer.o SECPK1/Int.o SECPK1/IntMod.o \
	SECPK1/Point.o SECPK1/SECP256K1.o \
	Kangaroo.o HashTable.o Thread.o Check.o Backup.o \
	Merge.o PartMerge.o)
endif

CXX = g++
CUDA = /usr/local/cuda
CXXCUDA = /usr/bin/g++
NVCC = $(CUDA)/bin/nvcc

all: driverquery bsgs

ifdef gpu
ifndef ccap
driverquery:
	. ./detect_cuda.sh
	ccap=$(shell cat cuda_version.txt)
else
driverquery:
	@echo "Compiling against manually selected CUDA version ${ccap}"
endif
else
driverquery:
endif

ifdef gpu
ifdef debug
CXXFLAGS = -DWITHGPU -m64 -mssse3 -Wno-unused-result -Wno-write-strings -g -I. -I$(CUDA)/include
else
CXXFLAGS = -DWITHGPU -m64 -mssse3 -Wno-unused-result -Wno-write-strings -O2 -I. -I$(CUDA)/include
endif
LFLAGS = -lpthread -L$(CUDA)/lib64 -lcudart
else
ifdef cpu
CXXFLAGS = -m64 -march=native -mtune=native -mssse3 -Wno-unused-result -Wno-write-strings -pthread -ftree-vectorize -O3 -funroll-loops -finline-functions -I.
LFLAGS = -lpthread
else
ifdef debug
CXXFLAGS = -m64 -mssse3 -Wno-unused-result -Wno-write-strings -g -I. -I$(CUDA)/include
else
CXXFLAGS = -m64 -mssse3 -Wno-unused-result -Wno-write-strings -O2 -I. -I$(CUDA)/include
endif
LFLAGS = -lpthread
endif
endif

ifdef gpu
# Multi-arch build: covers Turing→Hopper + PTX for forward JIT compatibility
ifdef multi
GENCODE_FLAGS = \
	-gencode=arch=compute_75,code=sm_75 \
	-gencode=arch=compute_80,code=sm_80 \
	-gencode=arch=compute_86,code=sm_86 \
	-gencode=arch=compute_89,code=sm_89 \
	-gencode=arch=compute_90,code=sm_90 \
	-gencode=arch=compute_90,code=compute_90
else
GENCODE_FLAGS = -gencode=arch=compute_$(ccap),code=sm_$(ccap)
endif

ifdef debug
$(OBJDIR)/GPU/GPUEngine.o: GPU/GPUEngine.cu
	$(NVCC) -G -maxrregcount=0 --ptxas-options=-v --compile --compiler-options -fPIC -ccbin $(CXXCUDA) -m64 -g -I$(CUDA)/include $(GENCODE_FLAGS) -o $(OBJDIR)/GPU/GPUEngine.o -c GPU/GPUEngine.cu
else
$(OBJDIR)/GPU/GPUEngine.o: GPU/GPUEngine.cu
	$(NVCC) -maxrregcount=0 --ptxas-options=-v --compile --compiler-options -fPIC -ccbin $(CXXCUDA) -m64 -O2 -I$(CUDA)/include $(GENCODE_FLAGS) -o $(OBJDIR)/GPU/GPUEngine.o -c GPU/GPUEngine.cu
endif
endif

$(OBJDIR)/%.o : %.cpp
	$(CXX) $(CXXFLAGS) -o $@ -c $<

bsgs: $(OBJET)
	@echo Making Kangaroo-256...
	$(CXX) $(OBJET) $(LFLAGS) -o kangaroo-256

$(OBJET): | $(OBJDIR) $(OBJDIR)/SECPK1 $(OBJDIR)/GPU

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/GPU: $(OBJDIR)
	cd $(OBJDIR) && mkdir -p GPU

$(OBJDIR)/SECPK1: $(OBJDIR)
	cd $(OBJDIR) && mkdir -p SECPK1

clean:
	@echo Cleaning...
	@rm -f kangaroo-256
	@rm -f obj/*.o
	@rm -f obj/GPU/*.o
	@rm -f obj/SECPK1/*.o
	@rm -f cuda_version.txt
	@rm -f deviceQuery/cuda_build_log.txt
