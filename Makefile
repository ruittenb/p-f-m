
install: pfm pfm.1 listwhite
	mkdir -p -m 755 /usr/local/bin/ /usr/local/man/man1/
	install -o root -g root -m 755 pfm   /usr/local/bin/
	install -o root -g root -m 644 pfm.1 /usr/local/man/man1/
	@echo
	@echo If you are upgrading from a previous version, please read the README file.
	@echo It contains important information about the configuration file.
	@echo

listwhite:
	make -C listwhite all
