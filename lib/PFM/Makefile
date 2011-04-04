SECTION=3pm
PODOPTS=--release=' ' --center=' ' --quotes=none --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

.SUFFIXES: .pm .3pm

.pm.3pm:
	pod2man $(PODOPTS) $< > PFM::$@

install:
	@echo "Please use the script 'install.sh' to install pfm."

man: Abstract.3pm Application.3pm Browser.3pm CommandHandler.3pm \
Config.3pm Directory.3pm History.3pm Job.3pm Screen.3pm State.3pm Util.3pm
	make -C Job man
	make -C Screen man

doc: man

test:
	perl -I.. -cw Abstract.pm
	perl -I.. -cw Application.pm
	perl -I.. -cw Browser.pm
	perl -I.. -cw CommandHandler.pm
	perl -I.. -cw Config.pm
	perl -I.. -cw Directory.pm
	perl -I.. -cw History.pm
	perl -I.. -cw Job.pm
	perl -I.. -cw Screen.pm
	perl -I.. -cw State.pm
	perl -I.. -cw Util.pm
	make -C Job test
	make -C Screen test

