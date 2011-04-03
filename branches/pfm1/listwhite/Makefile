CC=gcc
PROG=listwhite
SECTION=1
PODOPTS=--release=' ' --center=' ' --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`
                                                       

all: $(PROG) $(PROG).$(SECTION)

ps: $(PROG).$(SECTION)
	groff -man $(PROG).$(SECTION) > $(PROG).ps

$(PROG).$(SECTION): $(PROG)
	pod2man $(PODOPTS) $(PROG).c > $(PROG).$(SECTION)

install: $(PROG)
	install -o root -g $(WHEEL) -m 755 $(PROG) /usr/local/bin/
	install -o root -g $(WHEEL) -m 644 $(PROG).$(SECTION) /usr/local/man/man$(SECTION)/
