CC=clang
OUTPUT=DoomBridge.dll
SRC=DoomBridge.c

CFLAGS=-O0 -g -Wall -std=gnu99 -fno-strict-aliasing -fwrapv -D_WIN32 -D_WINDOWS -DWIN32 -DDOOM_WIN32 -D_CRT_SECURE_NO_WARNINGS
LDFLAGS=-shared -Wl,--gc-sections -Wl,-Map,$(OUTPUT).map
LIBS=-luser32 -lwinmm

all: $(OUTPUT)

$(OUTPUT): $(SRC) PureDOOM.h
	$(CC) $(CFLAGS) $(SRC) -o $(OUTPUT) $(LDFLAGS) $(LIBS)

clean:
	rm -f $(OUTPUT) $(OUTPUT).map *.o