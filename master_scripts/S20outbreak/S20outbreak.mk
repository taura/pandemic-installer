#
# S20outbreak.mk
#
# prepare to run outbreak
#

CFLAGS = -Wall -O3 -g -static
LDFLAGS = -lpthread

all: sonic
	chmod +x outbreak
	apt-get -y install realpath

sonic: sonic.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

