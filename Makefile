export

PHP ?= 7.2
JOBS ?= 2
PHP_MIRROR ?= http://us2.php.net/distributions/
TMPDIR ?= /tmp

makdir := $(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

ifdef TRAVIS
prefix ?= $(HOME)/cache/php-$(PHP)-$(shell env |grep -E '^with_|^enable_' | tr -c '[a-zA-Z_]' -)
else
prefix ?= $(TMPDIR)/php-$(PHP)-$(shell env |grep -E '^with_|^enable_' | tr -c '[a-zA-Z_]' -)
endif
exec_prefix ?= $(prefix)
bindir = $(exec_prefix)/bin
srcdir := $(prefix)/src
ifdef TRAVIS_BUILD_DIR
curdir ?= $(TRAVIS_BUILD_DIR)
else
# CURDIR is a make builtin
curdir ?= $(CURDIR)
endif

enable_maintainer_zts ?= no
enable_debug ?= no
enable_all ?= no
with_config_file_scan_dir ?= $(prefix)/etc/php.d

with_php_config ?= $(bindir)/php-config
extdir = $(shell test -x $(with_php_config) && $(with_php_config) --extension-dir)

PECL_MIRROR ?= http://pecl.php.net/get/
PECL_WORDS := $(subst :, ,$(PECL))
PECL_EXTENSION ?= $(word 1,$(PECL_WORDS))
PECL_SONAME ?= $(if $(word 2,$(PECL_WORDS)),$(word 2,$(PECL_WORDS)),$(PECL_EXTENSION))
PECL_VERSION ?= $(word 3,$(PECL_WORDS))
PECL_INI = $(with_config_file_scan_dir)/pecl.ini
PECL_DIR := $(if $(filter ext ext%, $(MAKECMDGOALS)), $(curdir), $(srcdir)/pecl-$(PECL_EXTENSION)-$(PECL_VERSION))

#PHP_VERSION_MAJOR = $(firstword $(subst ., ,$(PHP)))

PHP_RELEASES = $(srcdir)/releases.tsv
PHP_VERSION ?= $(shell test -e $(PHP_RELEASES) && cat $(PHP_RELEASES) | awk -F "\t" '/^$(PHP)\t/{print $$2; exit}')

CPPCHECK_STD ?= c89
CPPCHECK_ENABLE ?= portability,style
CPPCHECK_EXITCODE ?= 42
CPPCHECK_SUPPRESSIONS ?= $(makdir)/cppcheck.suppressions
CPPCHECK_INCLUDES ?= -I. $(shell test -f Makefile && awk -F= '/^CPPFLAGS|^INCLUDES/{print $$2}' <Makefile)
CPPCHECK_VERSION ?= 1.82
CPPCHECK_ARGS ?= -v -j $(JOBS) --std=$(CPPCHECK_STD) --enable=$(CPPCHECK_ENABLE) --error-exitcode=$(CPPCHECK_EXITCODE) --suppressions-list=$(CPPCHECK_SUPPRESSIONS) $(CPPCHECK_INCLUDES)

.SUFFIXES:

.PHONY: all
all: php

.PHONY: versions
versions: $(PHP_RELEASES)
	grep "^$(PHP)" $< | cut -f1-2

$(PHP_RELEASES): $(makdir)/php-version-url-dist.php $(makdir)/php-version-url-qa.php | $(srcdir)
	cd $(makdir) && printf "master\tmaster\t%s/fetch-master.sh\n" $$(pwd) >$@
	curl -Ss "http://php.net/releases/index.php?json&version=7&max=-1" | $(makdir)/php-version-url-dist.php >>$@
	curl -Ss "http://php.net/releases/index.php?json&version=5&max=-1" | $(makdir)/php-version-url-dist.php >>$@
	curl -Ss "http://qa.php.net/api.php?type=qa-releases&format=json"  | $(makdir)/php-version-url-qa.php   >>$@

## -- PHP

.PHONY: clean
clean:
	@if test -d $(srcdir)/php-$(PHP_VERSION); then cd $(srcdir)/php-$(PHP_VERSION); make distclean || true; fi

.PHONY: check
check: $(PHP_RELEASES)
	@if test -z "$(PHP)"; then echo "No php version specified, e.g. PHP=5.6"; exit 1; fi
	if test -d $(srcdir)/php-$(PHP_VERSION)/.git; then cd $(srcdir)/php-$(PHP_VERSION)/; git pull; fi

.PHONY: reconf
reconf: check $(srcdir)/php-$(PHP_VERSION)/configure
	cd $(srcdir)/php-$(PHP_VERSION) && ./configure --cache-file=config.cache --prefix=$(prefix)

.PHONY: php
php: check $(bindir)/php | $(PECL_INI)
	-for EXT_SONAME in $(extdir)/*.so; do \
		EXT_SONAME=$$(basename $$EXT_SONAME); \
		if test "$$EXT_SONAME" != "*.so" && ! grep -q extension=$$EXT_SONAME $(PECL_INI); then \
			echo extension=$$EXT_SONAME >> $(PECL_INI); \
		fi \
	done

$(srcdir)/php-$(PHP_VERSION)/configure: | $(PHP_RELEASES)
	cd $(srcdir) && awk -F "\t" '/^$(PHP)\t/{exit system($$3)}' <$|

$(srcdir)/php-$(PHP_VERSION)/Makefile: $(srcdir)/php-$(PHP_VERSION)/configure | $(PHP_RELEASES)
	cd $(srcdir)/php-$(PHP_VERSION) && ./configure --cache-file=config.cache --prefix=$(prefix)

$(srcdir)/php-$(PHP_VERSION)/sapi/cli/php: $(srcdir)/php-$(PHP_VERSION)/Makefile | $(PHP_RELEASES)
	cd $(srcdir)/php-$(PHP_VERSION) && make -j $(JOBS) || make

$(bindir)/php: $(srcdir)/php-$(PHP_VERSION)/sapi/cli/php | $(PHP_RELEASES)
	cd $(srcdir)/php-$(PHP_VERSION) && make -j $(JOBS) install INSTALL=install

$(srcdir) $(extdir) $(with_config_file_scan_dir):
	mkdir -p $@

## -- PECL

.PHONY: pecl-check
pecl-check:
	@if test -z "$(PECL)"; then echo "No pecl extension specified, e.g. PECL=pecl_http:http"; exit 1; fi
	if test -d $(PECL_DIR)/.git; then cd $(PECL_DIR)/; git pull; fi

.PHONY: pecl-clean
pecl-clean:
	@if test -d $(PECL_DIR); then cd $(PECL_DIR); make distclean || true; fi

.PHONY: pecl-rm
pecl-rm:
	rm -f $(extdir)/$(PECL_SONAME).so

$(PECL_INI): | $(with_config_file_scan_dir)
	touch $@

$(PECL_DIR)/config.m4:
	if test "$(PECL_VERSION)" = "master"; then \
		if test -d $(PECL_DIR); then \
			cd $(PECL_DIR); \
			git pull; \
		else \
			git clone -b $(PECL_VERSION) \
				$$(dirname $$(git remote get-url $$(git remote)))/$(PECL_EXTENSION) $(PECL_DIR); \
		fi; \
	else \
		mkdir -p $(PECL_DIR); \
		curl -Ss $(PECL_MIRROR)/$(PECL_EXTENSION)$(if $(PECL_VERSION),/$(PECL_VERSION)) \
			| tar xz --strip-components 1 -C $(PECL_DIR); \
	fi

$(PECL_DIR)/configure: $(PECL_DIR)/config.m4
	cd $(PECL_DIR) && $(bindir)/phpize

$(PECL_DIR)/Makefile: $(PECL_DIR)/configure
	cd $(PECL_DIR) && ./configure --cache-file=config.cache

$(PECL_DIR)/.libs/$(PECL_SONAME).so: $(PECL_DIR)/Makefile
	cd $(PECL_DIR) && make -j $(JOBS) || make

$(extdir)/$(PECL_SONAME).so: $(PECL_DIR)/.libs/$(PECL_SONAME).so $(extdir)
	cd $(PECL_DIR) && make -j $(JOBS) install INSTALL=install

.PHONY: pecl
pecl: pecl-check php $(extdir)/$(PECL_SONAME).so | $(PECL_INI)
	grep -q extension=$(PECL_SONAME).so $(PECL_INI) || echo extension=$(PECL_SONAME).so >> $(PECL_INI)

.PHONY: ext-clean
ext-clean: pecl-clean

.PHONY: ext-rm
ext-rm: pecl-rm

.PHONY: ext
ext: pecl-check pecl
	$(makdir)/check-packagexml.php package.xml

.PHONY: test
test: php
	REPORT_EXIT_STATUS=1 $(bindir)/php run-tests.php -q -p $(bindir)/php --set-timeout 300 --show-diff tests

pharext/%: $(PECL_INI) php | $(srcdir)/../%.ext.phar
	for phar in $|; do $(bindir)/php $$phar --prefix=$(prefix) --ini=$(PECL_INI); done

## -- CPPCHECK

$(srcdir)/cppcheck-$(CPPCHECK_VERSION):
	git clone https://github.com/danmar/cppcheck.git $@ && cd $@ && git checkout $(CPPCHECK_VERSION)

$(srcdir)/cppcheck-$(CPPCHECK_VERSION)/cppcheck: | $(srcdir)/cppcheck-$(CPPCHECK_VERSION)
	cd $| && make -j $(JOBS) cppcheck

.PHONY: cppcheck
cppcheck: | $(srcdir)/cppcheck-$(CPPCHECK_VERSION)/cppcheck
	$| $(CPPCHECK_ARGS) .
