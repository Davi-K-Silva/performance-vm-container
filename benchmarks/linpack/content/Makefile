FC = gfortran
FFLAGS = -O3
TARGET = linpackd
SRC = linpackd.f

all: $(TARGET)

$(TARGET): $(SRC)
	$(FC) $(FFLAGS) -o $@ $^

clean:
	rm -f $(TARGET) *.o

