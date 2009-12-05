OBJECTS =  smartcard.o misc.o bytestring.o asn1.o cardtree.o gui.o config.o lua_ext.o \
	   main.o dot_cardpeek.o
CC = gcc
CFLAGS = -Wall -pedantic `pkg-config lua libpcsclite gtk+-2.0 --cflags` -c
LFLAGS = -Wall `pkg-config lua libpcsclite gtk+-2.0 --libs`

all:			$(OBJECTS)
			$(CC) $(LFLAGS) $(OBJECTS) -o cardpeek

%.o:			%.c %.h
			$(CC) $(CFLAGS) $<

gui.o:			gui.c gui.h
			$(CC) $(CFLAGS) -Wno-write-strings $<

dot_cardpeek.o:		dot_cardpeek_dir
			cp -R dot_cardpeek_dir .cardpeek
			tar cvzf dot_cardpeek.tar.gz .cardpeek
			rm -rf .cardpeek
			$(CC) $(CFLAGS) script.S -o dot_cardpeek.o
			rm -f dot_cardpeek.tar.gz

clean:
			rm -f *.o cardpeek dot_cardpeek.tar.gz
