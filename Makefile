# Makefile for latex-tempo
#
# Targets:
#   make            byte-compile and run the tests
#   make compile    byte-compile with warnings treated as errors
#   make test       run the ERT test suite
#   make checkdoc   check documentation strings
#   make lint       run package-lint (MELPA style checks)
#   make doc        build doc/latex-tempo.texi and doc/latex-tempo.info
#   make pdf        build doc/latex-tempo.pdf through LaTeX
#   make check      compile, test, checkdoc and lint
#   make clean      remove generated files

EMACS ?= emacs
BATCH  = $(EMACS) -Q --batch -L .
EL     = latex-tempo.el
TESTS  = test/latex-tempo-test.el

# package-lint is fetched from GitHub into a local folder on first use.
PKGLINT_DIR ?= .package-lint
PKGLINT_URL ?= https://github.com/purcell/package-lint.git

.PHONY: all compile test checkdoc lint doc pdf check clean

all: compile test

compile:
	$(BATCH) --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(EL)

test:
	$(BATCH) -L test -l latex-tempo -l $(TESTS) \
	  -f ert-run-tests-batch-and-exit

checkdoc:
	$(BATCH) --eval "(let ((failed nil)) \
	  (advice-add 'display-warning :before (lambda (&rest _) (setq failed t))) \
	  (checkdoc-file \"$(EL)\") \
	  (kill-emacs (if failed 1 0)))"

$(PKGLINT_DIR):
	git clone --depth 1 $(PKGLINT_URL) $(PKGLINT_DIR)

lint: $(PKGLINT_DIR)
	$(BATCH) -L $(PKGLINT_DIR) --eval "(require 'package-lint)" \
	  -f package-lint-batch-and-exit $(EL)

doc: doc/latex-tempo.info

doc/latex-tempo.texi: doc/latex-tempo.org
	cd doc && $(EMACS) -Q --batch latex-tempo.org \
	  --eval "(progn (require 'ox-texinfo) (org-texinfo-export-to-texinfo))"

doc/latex-tempo.info: doc/latex-tempo.texi
	cd doc && makeinfo --no-split latex-tempo.texi -o latex-tempo.info

pdf: doc/latex-tempo.org
	cd doc && $(EMACS) -Q --batch latex-tempo.org \
	  --eval "(progn (require 'ox-latex) (org-latex-export-to-pdf))"

check: compile test checkdoc lint

clean:
	rm -f *.elc test/*.elc
	rm -f doc/latex-tempo.info doc/*.tex doc/*.pdf doc/*.aux doc/*.log \
	  doc/*.out doc/*.toc doc/*.idx doc/*.ind doc/*.ilg
