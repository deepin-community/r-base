#!/usr/bin/perl -w
#
# Under Debian, R add-on packages (i.e. any of the r-cran-* packages) 
# used to call 'build-help.pl' in postinst and postrm:
#	    /usr/bin/R CMD perl /usr/lib/R/share/perl/build-help.pl --htmllists
#
# However, R changed upstream and html help indices are created on the fly
# when the user calls help.start() from within R. With that, the call above
# is no longer needed and has been phased out in most but not yet all of
# the postinst and postrm scripts.
#
# Moreover, starting with R 2.2.1-3, architecture-independent files are placed
# below /usr/share/R/ --- breaking the call above. 2.2.1-4 introduced a 
# symbolic link from /usr/share/R/share to /usr/lib/R/share which works
# on fresh installs but fails on upgrades from older versions of the R
# package as dpkg cannot replace an existing directory with a softlink.
#
# Hence the need for this empty script to provide a place holder until 
# all r-cran-*, r-omegahat-*, r-other-*, ... packages have been updated.
#
# Dirk Eddelbuettel <edd@debian.org>  06 Feb 2005  
#

use strict;

print STDERR "Ignoring deprecated call to build-help.pl from postinst or postrm script.\n";
exit 0;
