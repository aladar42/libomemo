SDIR = src
BDIR = build
TDIR = test
LDIR = lib

# according to https://sourceware.org/bugzilla/show_bug.cgi?id=17879
# -fno-builtin-memset is enough to make gcc not optimize it away
FILES =

PKGCFG_C=$(shell pkg-config --cflags glib-2.0 sqlite3 mxml) $(shell libgcrypt-config --cflags)
PKGCFG_L=$(shell pkg-config --libs glib-2.0 sqlite3 mxml) $(shell libgcrypt-config --libs)

CFLAGS =-std=c11 -Wall -Wextra -Wpedantic -Wstrict-overflow -fno-strict-aliasing -funsigned-char -D_XOPEN_SOURCE=700 -D_BSD_SOURCE -fno-builtin-memset $(PKGCFG_C)
CFLAGS_CONVERSATIONS=$(CFLAGS) -DOMEMO_XMLNS='"eu.siacs.conversations.axolotl"' -DOMEMO_NS_SEPARATOR='"."' -DOMEMO_NS_NOVERSION
COVFLAGS = --coverage -O0 -g $(CFLAGS)
LFLAGS =-pthread -ldl -lm $(PKGCFG_L)
TESTFLAGS = -lcmocka $(LFLAGS)

all: libomemo-conversations

$(BDIR):
	mkdir -p $@
	
libomemo: $(SDIR)/libomemo.c libomemo_crypto libomemo_storage $(BDIR) 
	libtool --mode=compile gcc -c $(SDIR)/$@.c $(CFLAGS) -o $(BDIR)/$@.lo
	libtool --mode=link gcc -o $(BDIR)/$@.la $(BDIR)/$@.lo $(BDIR)/$@_crypto.lo $(BDIR)/$@_storage.lo
	
libomemo-conversations: $(SDIR)/libomemo.c libomemo_crypto libomemo_storage $(BDIR)
	libtool --mode=compile gcc -c $(SDIR)/libomemo.c $(CFLAGS_CONVERSATIONS) -o $(BDIR)/libomemo.lo
	libtool --mode=link gcc -o $(BDIR)/libomemo.la $(BDIR)/libomemo.lo $(BDIR)/libomemo_crypto.lo $(BDIR)/libomemo_storage.lo

libomemo_crypto: $(SDIR)/libomemo_crypto.c build
	libtool --mode=compile gcc -c $(SDIR)/$@.c $(CFLAGS) -o $(BDIR)/$@.lo

libomemo_storage: $(SDIR)/libomemo_storage.c build
	libtool --mode=compile gcc -c $(SDIR)/$@.c $(CFLAGS) -o $(BDIR)/$@.lo

$(BDIR)/libomemo.o: $(BDIR) $(SDIR)/libomemo.c $(SDIR)/libomemo.h
	gcc -c $(CFLAGS) $(SDIR)/libomemo.c -o $@
	
libomemo-conversations.o: $(SDIR)/libomemo.c $(BDIR)
	gcc -c $(SDIR)/libomemo.c $(CFLAGS_CONVERSATIONS) -fPIC -o $(BDIR)/libomemo.o
	
libomemo_crypto.o: $(SDIR)/libomemo_crypto.c build
	gcc -c $(SDIR)/libomemo_crypto.c $(CFLAGS) -fPIC -o $(BDIR)/$@

libomemo_storage.o: $(SDIR)/libomemo_storage.c build
	gcc -c $(SDIR)/libomemo_storage.c $(CFLAGS) -fPIC -o $(BDIR)/$@
	
libomemo-conversations-pic: libomemo-conversations.o libomemo_crypto.o libomemo_storage.o
	
.PHONY = test_libomemo.o
test_libomemo: $(TDIR)/test_libomemo.c $(SDIR)/libomemo.c
	gcc $(COVFLAGS) $<  $(FILES) -o $(TDIR)/$@.o $(TESTFLAGS)
	-$(TDIR)/$@.o
	mv *.g* $(TDIR)
	
.PHONY: test_crypto
test_crypto: $(TDIR)/test_crypto.c $(SDIR)/libomemo_crypto.c
	gcc $(COVFLAGS) $<  $(FILES) -o $(TDIR)/$@.o $(TESTFLAGS)
	-$(TDIR)/$@.o
	mv *.g* $(TDIR)	
	
.PHONY: test_storage
test_storage: $(TDIR)/test_storage.c $(SDIR)/libomemo_storage.c
	gcc $(COVFLAGS) $< $(FILES) -o $(TDIR)/$@.o $(TESTFLAGS)
	-$(TDIR)/$@.o
	mv *.g* $(TDIR) 

.PHONY: test
test : test_libomemo test_crypto test_storage

.PHONY: coverage
coverage: test
	gcovr -r . --html --html-details -o $@.html
	gcovr -r . -s
	mkdir -p $@
	mv $@.* $@

.PHONY: clean
clean:
	rm -rf build coverage
	rm -f $(TDIR)/*.sqlite $(TDIR)/*.o $(TDIR)/*.gcno $(TDIR)/*.gcda
