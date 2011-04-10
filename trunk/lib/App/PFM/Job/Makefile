SECTION=3pm
PODOPTS=--release=' ' --center=' ' --quotes=none --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

.SUFFIXES: .pm .3pm

.pm.3pm:
	pod2man $(PODOPTS) $<

install:
	@echo "Please use the script 'install.sh' to install pfm."

man: Abstract.3pm CheckUpdates.3pm Bazaar.3pm Cvs.3pm Subversion.3pm

doc: man

test:
	perl -I../../.. -cw Abstract.pm
	perl -I../../.. -cw CheckUpdates.pm
	perl -I../../.. -cw Bazaar.pm
	perl -I../../.. -cw Cvs.pm
	perl -I../../.. -cw Subversion.pm
