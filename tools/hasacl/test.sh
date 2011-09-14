#!/bin/sh

if [ ! -x ./hasacl ]; then
	echo "Error: hasacl executable was not found, aborting"
	exit 1
fi

printf "Testing file without ACL... "
if touch acl_no; then
	./hasacl acl_no && echo "false positive" || echo "OK"
	rm acl_no
else
	echo
	echo "Error: could not create test file, aborting"
	exit 1
fi

printf "Testing file with    ACL... "
if	touch acl_yes && \
	setfacl -m "user:root:rwx" -m "user:bin:rx" -m "user:mail:x" acl_yes
then
	./hasacl acl_yes && echo "OK" || echo "false negative"
	rm acl_yes
else
	echo
	echo "Error: could not create test file, aborting"
	exit 1
fi

