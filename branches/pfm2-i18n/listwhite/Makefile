CC=gcc
PROG=listwhite
SECTION=1
PODOPTS=--release=' ' --center=' ' --date=`date +%Y-%m-%d` --section=$(SECTION)
PREFIX=/usr/local
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`
                                                       

all: $(PROG) $(PROG).$(SECTION)

$(PROG).$(SECTION): $(PROG)
	pod2man $(PODOPTS) $(PROG).c > $(PROG).$(SECTION)

test:	$(PROG)
	./$(PROG)

install: all
	install -o root -g $(WHEEL) -m 755 $(PROG) $(PREFIX)/bin/
	install -o root -g $(WHEEL) -m 644 $(PROG).$(SECTION) $(PREFIX)/man/man$(SECTION)/

clean:
	rm $(PROG) $(PROG).$(SECTION)
