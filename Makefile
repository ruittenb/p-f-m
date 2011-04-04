SECTION=1
PODOPTS=--release=' ' --center=' ' --quotes=none --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

default:
	@echo "use 'make install' to install"

install: pfm pfm.1 listwhite
	./install.sh

listwhite:
	make -C listwhite

man: pfm
	/usr/bin/pod2man $(PODOPTS) pfm > pfm.1

doc: man

test: pfm.pl
	perl -cw pfm.pl
