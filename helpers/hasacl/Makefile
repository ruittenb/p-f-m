CC       = gcc
CFLAGS   = -g -O2
PROG     = hasacl
VERSION  = 0.07
LDFLAGS  = 
LIBS     =  -lacl
SECTION  = 1
PODOPTS  = --release=' ' --center=' ' --date=`date +%Y-%m-%d` \
           --section=$(SECTION) --name=$(PROG)
INSTALL  = /usr/local/bin/ginstall -c
PREFIX   = /usr/local
WHEEL    = `awk -F: '$$3 == 0 {print $$1}' /etc/group`

all: $(PROG) $(PROG).$(SECTION)

$(PROG): $(PROG).c
	$(CC) $(CFLAGS) $(LIBS) -DVERSION=\"$(VERSION)\" $(PROG).c -o $(PROG)

$(PROG).$(SECTION): $(PROG)
	pod2man $(PODOPTS) $(PROG).c > $(PROG).$(SECTION)

test: $(PROG)
	./test.sh

install: all
	$(INSTALL) -o root -g $(WHEEL) -m 755 $(PROG) $(PREFIX)/bin/
	$(INSTALL) -o root -g $(WHEEL) -m 644 $(PROG).$(SECTION) $(PREFIX)/man/man$(SECTION)/

clean:
	rm -f $(PROG) $(PROG).$(SECTION)

distclean:
	rm -f $(PROG) $(PROG).$(SECTION) config.* Makefile acl_no acl_yes

