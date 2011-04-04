PODOPTS=--release=' ' --center=' ' --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

default:
	@echo "use 'make install' to install"

install: pfm pfm.1 listwhite
	./install.sh

listwhite:
	make -C listwhite

man:
	pod2man $(PODOPTS) pfm
