spammenot
=========

SpamMeNot mail server and management console.

This software runs on a Linux operating system, and depends on /dev/shm

You need to create a user named "spammenot" who belongs to a group
of the same name.  The daemon and backend will run as that uid/gid.

You need to create a directory for the mail server to store its incoming
emails, and make it writable by the spammenot user account.

you also need to make a directory for the logs kept by the spammenot
daemon and backend server, and that directory needs to be writable by
the spammenot user as well.  For now this directory is hard-coded in the
application to be in /var/log/spammenot/

The hard-coded log directory will become a configuration option in the
near future.

The SpamMenNot application is configured in in the spammenot.conf file.
It comes out of the box with the recommended settings.
