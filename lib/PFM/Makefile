SECTION=3pm
PODOPTS=--release=' ' --center=' ' --quotes=none --date=`date +%Y-%m-%d` --section=$(SECTION)
WHEEL=`awk -F: '$$3 == 0 {print $$1}' /etc/group`

.SUFFIXES: .pm .3pm

.pm.3pm:
	pod2man $(PODOPTS) $<

install:
	@echo "Please use the script 'install.sh' to install pfm."

man: Abstract.3pm Application.3pm Browser.3pm CommandHandler.3pm Config.3pm Directory.3pm History.3pm Job.3pm Screen.3pm State.3pm Util.3pm

doc: man
