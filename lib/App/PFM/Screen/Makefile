SECTION=3pm
PODOPTS=--release=' ' --center=' ' --quotes=none --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

.SUFFIXES: .pm .3pm

.pm.3pm:
	pod2man $(PODOPTS) $<

install:
	@echo "Please use the script 'install.sh' to install pfm."

man: Diskinfo.3pm Frame.3pm Listing.3pm

doc: man

test:
	perl -I../../.. -cw Diskinfo.pm
	perl -I../../.. -cw Frame.pm
	perl -I../../.. -cw Listing.pm
