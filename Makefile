OBJECTS =  smartcard.o misc.o bytestring.o asn1.o cardtree.o gui.o config.o lua_ext.o \
	   main.o dot_cardpeek.o
LUA_OBJS = 	dot_cardpeek_dir/scripts/atr.lua dot_cardpeek_dir/scripts/emv.lua \
		dot_cardpeek_dir/scripts/moneo.lua dot_cardpeek_dir/scripts/banlieue.lua \
		dot_cardpeek_dir/scripts/metro.lua dot_cardpeek_dir/scripts/navigo.lua \
		dot_cardpeek_dir/scripts/lib/apdu.lua dot_cardpeek_dir/scripts/lib/tlv.lua

CC = gcc
CFLAGS = -Wall -pedantic `pkg-config --exists lua5.1 && pkg-config lua5.1 --cflags || pkg-config lua --cflags` `pkg-config libpcsclite gtk+-2.0 --cflags` -c
LFLAGS = -Wall `pkg-config --exists lua5.1 && pkg-config lua5.1 --libs || pkg-config lua --libs` `pkg-config libpcsclite gtk+-2.0 --libs`

all:			cardpeek

smartcard.o:	smartcard.c drivers/null_driver.c drivers/pcsc_driver.c

cardpeek:		$(OBJECTS)
			$(CC) $(LFLAGS) $(OBJECTS) -o $@

%.o:			%.c %.h
			$(CC) $(CFLAGS) $<

gui.o:			gui.c gui.h
			$(CC) $(CFLAGS) -Wno-write-strings $<

dot_cardpeek.o:		$(LUA_OBJS)
			cp -R dot_cardpeek_dir .cardpeek
			tar cvzf dot_cardpeek.tar.gz .cardpeek
			rm -rf .cardpeek
			$(CC) $(CFLAGS) script.S -o $@
			rm -f dot_cardpeek.tar.gz

clean:
			rm -f *.o cardpeek dot_cardpeek.tar.gz
