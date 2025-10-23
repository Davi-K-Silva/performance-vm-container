# Makefile for STREAM (Fortran)
# Usage:
#   make            # build without OpenMP
#   make USE_OMP=1  # build with OpenMP enabled

FC      ?= gfortran
FFLAGS  := -O3 -march=native
LDFLAGS :=

# If your stream.f uses very large static arrays, the medium code model can help on x86_64.
# Uncomment if needed:
# FFLAGS += -mcmodel=medium

# Enable OpenMP if requested
ifeq ($(USE_OMP),1)
  FFLAGS  += -fopenmp
  LDFLAGS += -fopenmp
endif

SRC     := stream.f
TARGET  := streamf

all: $(TARGET)

$(TARGET): $(SRC)
	$(FC) $(FFLAGS) -o $@ $^ $(LDFLAGS) mysecond.c

clean:
	rm -f $(TARGET) *.o *.mod

