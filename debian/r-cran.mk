#!/usr/bin/make -f
# 							-*- makefile -*-
#
# Generic debian/rules file for the Debian/GNU Linux r-cran-* packages
#
# Should be sufficient for Debianization of CRAN (http://cran.r-project.org) 
# packages. Note that you still need to provide the other files in debian/*,
# in particular control, changelog and copyright. 
# 
# Copyright 2003 - 2023 by Dirk Eddelbuettel <edd@debian.org>

include /usr/share/cdbs/1/rules/debhelper.mk
include /usr/share/cdbs/1/class/langcore.mk
## include /usr/share/cdbs/1/rules/dpatch.mk
## include /usr/share/cdbs/1/rules/simple-patchsys.mk

# Check whether source format 3.0 (quilt) is used.  If yes, do not include the conflicting simple-patchsys.mk
formatfile 	:= $(CURDIR)/debian/source/format
format_3_quilt	= $(shell if [ -f $(formatfile) ] ; then if grep -q '3.0[[:space:]]*(quilt)' $(formatfile) ; then echo 1 ; else echo 0 ; fi else echo 0 ; fi )
ifeq ($(format_3_quilt),0)
  include /usr/share/cdbs/1/rules/simple-patchsys.mk
endif

# awk command to extract word after Package or Bundle, not lowercased
awkString	:= "'/^(Package|Bundle):/ {print $$2 }'"

# apply it to the upstream meta-info file DESCRIPTION, also generate a lc version
cranNameOrig    := $(shell awk "$(awkString)" DESCRIPTION)
#cranName        := $(shell echo "$(cranNameOrig)" | tr A-Z a-z | tr . -)
cranName        := $(shell echo "$(cranNameOrig)" | tr A-Z a-z)

## if no debRreposname is known, set default to cran -- thanks, Steffen!
ifeq ($(debRreposname),)
  debRreposname	:= cran
endif

## we can define additional flags for R's make, eg "CXXFLAGS=-g0" for 
## RQuantLib but the default is empty
##   makeFlags	:=
## if makeFlags are defined, then we'll use them in this variable
## which would otherwise be empty
ifneq ($(makeFlags),)
  makeFlagsCall	:= MAKEFLAGS=$(makeFlags)
endif

## xvfb-run with GL extension and default resolution
xvfbSrvArgs 	= -screen 0 1024x768x24 -ac +extension GLX +render -noreset

## and use the results to build the Debian'ized package name
package		:= r-$(debRreposname)-$(cranName)

## awk command to extract word after Priority
prioritystr	:= "'/^Priority:/ {print tolower($$2) }'"
priority        := $(shell awk "$(prioritystr)" DESCRIPTION)

ifeq ($(priority),recommended)
  debRdir	:= usr/lib/R/library
else
  debRdir	:= usr/lib/R/site-library
endif

## current R version in Debian, with thanks to Charles Plessy for the dpkg-query call
#rversion	:= $(shell zcat /usr/share/doc/r-base-dev/changelog.Debian.gz | \
#			dpkg-parsechangelog -l- --count 1  | \
#			awk '/^Version/ {print $$2}')
rversion	:= $(shell dpkg-query -W -f='$${Version}' r-base-dev)
rapiversion	:= $(shell dpkg-query -W -f='$${Provides}' r-base-core | grep -o 'r-api[^, ]*')
rgeversion      := $(shell dpkg-query -W -f='$${Provides}' r-base-core | grep -o 'r-graphics-engine[^, ]*')

## we use these results for the to-be-installed-in directory
debRlib		:= $(CURDIR)/debian/$(package)/$(debRdir)

## optional installation of a lintian silencer
lintiandir	:= $(CURDIR)/debian/$(package)/usr/share/lintian/overrides

## set built-time in DESCRIPTION time of created binary package based on stamp in changelog
## cf discussion in http://bugs.debian.org/774031 --- and uncomment two assignments here
##
## extract built-timestamp from entry changelog and use as argument 
#builttime       := $(shell dpkg-parsechangelog -l$(CURDIR)/debian/changelog | awk -F': ' '/Date/ {print $$2}')
##
#builttimeStamp  := "--built-timestamp=\"$(builttime)\""
##
## else
#builttimeStamp  := ""
#
## Bug report #782764 with patch by Philipp Rinn building on what we had above
## if no builttimeStamp is supplied, set built-time (to be set in DESCRIPTION) 
## to time of created source package based on stamp in changelog. 
## See discussion in http://bugs.debian.org/774031

ifeq ($(builttimeStamp),)
  builttime       := $(shell dpkg-parsechangelog -l$(CURDIR)/debian/changelog | awk -F': ' '/Date/ {print $$2}')
  builttimeStamp  := "--built-timestamp=\"$(builttime)\""
endif  

common-install-indep:: R_any_arch
common-install-arch:: R_any_arch

R_any_arch:
                ## create the target directory
		dh_installdirs		$(debRdir)
                ##
                ## support ${R:Depends} via debian/${package}.substvars
		echo "R:Depends=r-base-core (>= ${rversion}), ${rapiversion}, ${rgeversion}" >> debian/$(package).substvars
                ##
                ## call R to install the sources we're looking at
                ## use this inside xvfb-run if this wrapper is installed
		if test -f /usr/bin/xvfb-run; then 			\
			$(makeFlagsCall) xvfb-run -a -n 20              \
                                                  -s "${xvfbSrvArgs}"   \
				R CMD INSTALL -l $(debRlib) --clean     \
					$(extraInstallFlags) .   	\
					$(builttimeStamp)   	        \
					;                               \
		else							\
			$(makeFlagsCall) R CMD INSTALL -l $(debRlib) 	\
					--clean $(extraInstallFlags) .  \
					$(builttimeStamp)   	        \
					;                               \
		fi
                ## remove extra files which are present in some packages
		rm -vf $(debRlib)/R.css 			\
			$(debRlib)/$(cranNameOrig)/COPYING 	\
			$(debRlib)/$(cranNameOrig)/LICENSE.txt	\
			$(debRlib)/$(cranNameOrig)/LICENSE
                ## if we have an overrides file for lintian, install it
		if test -f debian/overrides; then 		\
			install -d $(lintiandir) ; 		\
			install -m 0644 debian/overrides 	\
				$(lintiandir)/$(package); 	\
		fi

## clean target from patch by Steffen Moeller on 16 May 2009
clean::
                ## the re-invocation of a build process should not
                ## leave a footprint in Debian's diff.gz.
		if test -d src; then				\
			find src -regex ".*\.o" |               \
                        xargs --no-run-if-empty -r rm;          \
		fi
		rm -f config.log config.status
                ## the configure file is provided by upstream but
                ## could be recreated by a call to 'autoconf'.
                #if [ -r configure.in ]; then \
                #	rm -f configure \
                #fi
                ##
                # if [ -r src/Makevars.in ]; then \
                # 	rm -f src/Makevars; \
                # fi

