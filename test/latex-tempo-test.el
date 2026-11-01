;;; latex-tempo-test.el --- ERT tests for latex-tempo  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; Author: Blaine Mooers <blaine-mooers@ou.edu>
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Run with "make test" from the repository root.  Each test inserts
;; text into a temporary LaTeX buffer, runs a command, and compares the
;; resulting buffer text and point.  The string "|" in an expected
;; result marks where point should be.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'latex-tempo)

;;;; Helpers

(defmacro latex-tempo-test--with-buffer (text &rest body)
  "Run BODY in a LaTeX buffer holding TEXT.
The first \"|\" in TEXT marks point and is removed."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (latex-mode)
     (latex-tempo-mode 1)
     (setq-local indent-tabs-mode nil)
     (insert ,text)
     (goto-char (point-min))
     (if (search-forward "|" nil t)
         (delete-char -1)
       (goto-char (point-max)))
     (cl-letf (((symbol-function 'latex-tempo--read-language)
                (lambda () "python"))
               ((symbol-function 'latex-tempo--read-width)
                (lambda () "0.5"))
               ((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
       (let ((latex-tempo-add-usepackage nil)
             (inhibit-message t))
         ,@body))))

(defun latex-tempo-test--state ()
  "Return the buffer text with \"|\" inserted at point."
  (concat (buffer-substring-no-properties (point-min) (point))
          "|"
          (buffer-substring-no-properties (point) (point-max))))

(defun latex-tempo-test--expand (text)
  "Expand TEXT with `latex-tempo-expand-or-tab' and return the state."
  (latex-tempo-test--with-buffer text
    (latex-tempo-expand-or-tab)
    (latex-tempo-test--state)))

;;;; Template table

(ert-deftest latex-tempo-test-every-template-has-description ()
  (dolist (e latex-tempo-templates)
    (should (stringp (plist-get (cdr e) :desc)))))

(ert-deftest latex-tempo-test-keys-are-unique ()
  (let ((keys (mapcar #'car latex-tempo-templates)))
    (should (equal keys (delete-dups (copy-sequence keys))))))

(ert-deftest latex-tempo-test-expected-keys-present ()
  (dolist (k '("a" "c" "C" "E" "h" "l" "q" "v" "m" "e" "i" "k"
               "I" "f" "t" "u" "y" "p" "x"))
    (should (assoc k latex-tempo-templates))))

(ert-deftest latex-tempo-test-old-keys-removed ()
  (dolist (k '("s" "su" "ssu"))
    (should-not (assoc k latex-tempo-templates))))

(ert-deftest latex-tempo-test-built-in-keys-are-single-characters ()
  (dolist (e latex-tempo-templates)
    (should (= 1 (length (car e))))))

;;;; Trigger detection

(ert-deftest latex-tempo-test-trigger-at-line-start ()
  (latex-tempo-test--with-buffer "<q|"
    (should (latex-tempo--trigger))))

(ert-deftest latex-tempo-test-trigger-after-indent ()
  (latex-tempo-test--with-buffer "   <q|"
    (should (latex-tempo--trigger))))

(ert-deftest latex-tempo-test-no-trigger-after-text ()
  (latex-tempo-test--with-buffer "Some text <q|"
    (should-not (latex-tempo--trigger))))

(ert-deftest latex-tempo-test-no-trigger-for-unknown-key ()
  (latex-tempo-test--with-buffer "<zzz|"
    (should-not (latex-tempo--trigger))))

(ert-deftest latex-tempo-test-keys-are-case-sensitive ()
  (should (string-match-p "itemize" (latex-tempo-test--expand "<i")))
  (should (equal (latex-tempo-test--expand "<I") "\\item |")))

;;;; Environments

(ert-deftest latex-tempo-test-quote ()
  (should (equal (latex-tempo-test--expand "<q")
                 "\\begin{quote}\n|\n\\end{quote}")))

(ert-deftest latex-tempo-test-center ()
  (should (equal (latex-tempo-test--expand "<c")
                 "\\begin{center}\n|\n\\end{center}")))

(ert-deftest latex-tempo-test-verbatim-v ()
  (should (equal (latex-tempo-test--expand "<v")
                 "\\begin{verbatim}\n|\n\\end{verbatim}")))

(ert-deftest latex-tempo-test-verbatim-a ()
  (should (equal (latex-tempo-test--expand "<a")
                 "\\begin{verbatim}\n|\n\\end{verbatim}")))

(ert-deftest latex-tempo-test-comment-with-note ()
  (should (equal (latex-tempo-test--expand "<h")
                 (concat "\\begin{comment}\n"
                         "% HTML-only content.  LaTeX ignores it.\n"
                         "|\n\\end{comment}"))))

(ert-deftest latex-tempo-test-raw-latex-markers ()
  (should (equal (latex-tempo-test--expand "<l")
                 "% begin raw LaTeX\n|\n% end raw LaTeX")))

(ert-deftest latex-tempo-test-minted ()
  (should (equal (latex-tempo-test--expand "<m")
                 "\\begin{minted}{python}\n|\n\\end{minted}")))

(ert-deftest latex-tempo-test-indentation-kept ()
  (should (equal (latex-tempo-test--expand "  <q")
                 "  \\begin{quote}\n  |\n  \\end{quote}")))

(ert-deftest latex-tempo-test-text-after-is-kept ()
  (should (equal (latex-tempo-test--expand "<q|\nNext line")
                 "\\begin{quote}\n|\n\\end{quote}\nNext line")))

;;;; Multi-line templates

(ert-deftest latex-tempo-test-enumerate-five-items ()
  (let ((out (latex-tempo-test--expand "<e")))
    (should (string-prefix-p "\\begin{enumerate}\n  \\item |\n" out))
    (should (string-suffix-p "\\end{enumerate}" out))
    (should (= 5 (cl-count-if (lambda (l) (string-match-p "\\\\item" l))
                              (split-string out "\n"))))))

(ert-deftest latex-tempo-test-itemize-five-items ()
  (let ((out (latex-tempo-test--expand "<i")))
    (should (string-prefix-p "\\begin{itemize}\n  \\item |\n" out))
    (should (= 5 (cl-count-if (lambda (l) (string-match-p "\\\\item" l))
                              (split-string out "\n"))))))

(ert-deftest latex-tempo-test-checklist ()
  (let ((out (latex-tempo-test--expand "<k")))
    (should (string-prefix-p "\\begin{itemize}\n  \\item[$\\square$] |" out))
    (should (= 5 (cl-count-if (lambda (l) (string-match-p "square" l))
                              (split-string out "\n"))))))

(ert-deftest latex-tempo-test-figure-width ()
  (let ((out (latex-tempo-test--expand "<f")))
    (should (string-match-p
             (regexp-quote "\\includegraphics[width=0.5\\textwidth]{|}")
             out))
    (should (string-match-p (regexp-quote "\\caption{}") out))
    (should (string-match-p (regexp-quote "\\label{fig:}") out))
    (should (string-suffix-p "\\end{figure}" out))))

(ert-deftest latex-tempo-test-table-five-columns ()
  (let* ((out (latex-tempo-test--expand "<t"))
         (rows (cl-remove-if-not (lambda (l) (string-match-p "\\\\\\\\" l))
                                 (split-string out "\n"))))
    (should (string-match-p (regexp-quote "\\caption{|}") out))
    (should (string-match-p (regexp-quote "{lllll}") out))
    (dolist (rule '("\\toprule" "\\midrule" "\\bottomrule"))
      (should (string-match-p (regexp-quote rule) out)))
    ;; One header row and two data rows, each with four ampersands.
    (should (= 3 (length rows)))
    (dolist (r rows)
      (should (= 4 (cl-count ?& r))))))

(ert-deftest latex-tempo-test-template-markers-removed ()
  (dolist (k '("e" "i" "k" "f" "t"))
    (let ((out (latex-tempo-test--expand (concat "<" k))))
      (should-not (string-match-p "@@" out))
      (should-not (string-match-p "<<arg>>" out)))))

(ert-deftest latex-tempo-test-template-indentation ()
  (let ((out (latex-tempo-test--expand "    <i")))
    (dolist (l (split-string out "\n"))
      (should (string-prefix-p "    " l)))))

;;;; One-line commands

(ert-deftest latex-tempo-test-subsection ()
  (should (equal (latex-tempo-test--expand "<u") "\\subsection{|}")))

(ert-deftest latex-tempo-test-subsubsection ()
  (should (equal (latex-tempo-test--expand "<y") "\\subsubsection{|}")))

(ert-deftest latex-tempo-test-paragraph ()
  (should (equal (latex-tempo-test--expand "<p") "\\paragraph{|}")))

(ert-deftest latex-tempo-test-index ()
  (should (equal (latex-tempo-test--expand "<x") "\\index{|}")))

(ert-deftest latex-tempo-test-item ()
  (should (equal (latex-tempo-test--expand "  <I") "  \\item |")))

;;;; Fallback to the usual TAB

(ert-deftest latex-tempo-test-fallback-leaves-text ()
  (latex-tempo-test--with-buffer "Some text <q|"
    (latex-tempo-expand-or-tab)
    (should (string-match-p "Some text <q"
                            (buffer-substring-no-properties
                             (point-min) (point-max))))))

;;;; Region wrapping with C-c C-,

(ert-deftest latex-tempo-test-wrap-region-in-quote ()
  (latex-tempo-test--with-buffer "Line one\nLine two\n"
    (goto-char (point-min))
    (set-mark (point))
    (goto-char (point-max))
    (activate-mark)
    (let ((transient-mark-mode t))
      (latex-tempo-insert-structure "q"))
    (should (equal (buffer-string)
                   "\\begin{quote}\nLine one\nLine two\n\\end{quote}\n"))))

(ert-deftest latex-tempo-test-wrap-partial-line ()
  (latex-tempo-test--with-buffer "A\nBravo\nC"
    (goto-char (point-min))
    (forward-line 1)
    (forward-char 1)
    (set-mark (point))
    (forward-char 2)
    (activate-mark)
    (let ((transient-mark-mode t))
      (latex-tempo-insert-structure "c"))
    (should (equal (buffer-string)
                   "A\n\\begin{center}\nBravo\n\\end{center}\nC"))))

(ert-deftest latex-tempo-test-wrap-word-in-index ()
  (latex-tempo-test--with-buffer "minted"
    (goto-char (point-min))
    (set-mark (point))
    (goto-char (point-max))
    (activate-mark)
    (let ((transient-mark-mode t))
      (latex-tempo-insert-structure "x"))
    (should (equal (buffer-string) "\\index{minted}"))))

(ert-deftest latex-tempo-test-menu-without-region ()
  (should (equal (latex-tempo-test--with-buffer ""
                   (latex-tempo-insert-structure "u")
                   (latex-tempo-test--state))
                 "\\subsection{|}")))

(ert-deftest latex-tempo-test-menu-unknown-key ()
  (latex-tempo-test--with-buffer ""
    (should-error (latex-tempo-insert-structure "zzz") :type 'user-error)))

;;;; Single-keypress menu

(ert-deftest latex-tempo-test-menu-lists-every-key ()
  (let ((text (latex-tempo--menu-text)))
    (dolist (e latex-tempo-templates)
      (should (string-match-p (regexp-quote (format "[%s]" (car e))) text)))
    (should (string-match-p (regexp-quote "[TAB]") text))))

(ert-deftest latex-tempo-test-menu-single-keypress ()
  (cl-letf (((symbol-function 'read-char-exclusive) (lambda (&rest _) ?u)))
    (should (equal (latex-tempo--choose-key) "u"))))

(ert-deftest latex-tempo-test-menu-keypress-is-case-sensitive ()
  (cl-letf (((symbol-function 'read-char-exclusive) (lambda (&rest _) ?I)))
    (should (equal (latex-tempo--choose-key) "I"))))

(ert-deftest latex-tempo-test-menu-tab-switches-to-completion ()
  (dolist (ch '(?\t ?\s))
    (cl-letf (((symbol-function 'read-char-exclusive) (lambda (&rest _) ch))
              ((symbol-function 'latex-tempo--complete-key) (lambda () "y")))
      (should (equal (latex-tempo--choose-key) "y")))))

(ert-deftest latex-tempo-test-menu-buffer-removed ()
  (cl-letf (((symbol-function 'read-char-exclusive) (lambda (&rest _) ?q)))
    (latex-tempo--choose-key))
  (should-not (get-buffer latex-tempo--menu-buffer)))

(ert-deftest latex-tempo-test-menu-buffer-removed-after-quit ()
  (cl-letf (((symbol-function 'read-char-exclusive)
             (lambda (&rest _) (signal 'quit nil))))
    ;; `should-error' does not catch `quit', which is not an error.
    (should (eq 'quit (condition-case nil
                          (progn (latex-tempo--choose-key) 'no-quit)
                        (quit 'quit)))))
  (should-not (get-buffer latex-tempo--menu-buffer)))

(ert-deftest latex-tempo-test-complete-key-returns-key ()
  (cl-letf (((symbol-function 'completing-read)
             (lambda (_prompt cands &rest _)
               (car (rassoc "y" cands)))))
    (should (equal (latex-tempo--complete-key) "y"))))

(ert-deftest latex-tempo-test-insert-by-name ()
  (should (equal (latex-tempo-test--with-buffer ""
                   (latex-tempo-insert-structure-by-name "y")
                   (latex-tempo-test--state))
                 "\\subsubsection{|}")))

(ert-deftest latex-tempo-test-insert-by-name-wraps-region ()
  (latex-tempo-test--with-buffer "Text"
    (goto-char (point-min))
    (set-mark (point))
    (goto-char (point-max))
    (activate-mark)
    (let ((transient-mark-mode t))
      (latex-tempo-insert-structure-by-name "q"))
    (should (equal (buffer-string) "\\begin{quote}\nText\n\\end{quote}"))))

;;;; Package checks

(ert-deftest latex-tempo-test-package-detection ()
  (dolist (text '("\\usepackage{minted}"
                  "\\usepackage[cache=false]{minted}"
                  "\\usepackage{graphicx,minted}"
                  "\\usepackage{minted, booktabs}"
                  "\\RequirePackage{minted}"))
    (latex-tempo-test--with-buffer text
      (should (latex-tempo--package-loaded-p "minted")))))

(ert-deftest latex-tempo-test-package-not-detected ()
  (dolist (text '("% \\usepackage{minted}"
                  "\\usepackage{mintedx}"
                  "\\usepackage{xminted}"
                  "no packages here"))
    (latex-tempo-test--with-buffer text
      (should-not (latex-tempo--package-loaded-p "minted")))))

(ert-deftest latex-tempo-test-usepackage-added ()
  (latex-tempo-test--with-buffer
      "\\documentclass{article}\n\\begin{document}\n<m|\n\\end{document}\n"
    (let ((latex-tempo-add-usepackage t))
      (latex-tempo-expand-or-tab))
    (should (equal (latex-tempo-test--state)
                   (concat "\\documentclass{article}\n"
                           "\\usepackage{minted}\n"
                           "\\begin{document}\n"
                           "\\begin{minted}{python}\n|\n\\end{minted}\n"
                           "\\end{document}\n")))))

(ert-deftest latex-tempo-test-usepackage-not-added-when-nil ()
  (latex-tempo-test--with-buffer
      "\\documentclass{article}\n\\begin{document}\n<t|\n\\end{document}\n"
    (latex-tempo-expand-or-tab)
    (should-not (latex-tempo--package-loaded-p "booktabs"))))

(ert-deftest latex-tempo-test-usepackage-not-duplicated ()
  (latex-tempo-test--with-buffer
      (concat "\\documentclass{article}\n\\usepackage{graphicx}\n"
              "\\begin{document}\n<f|\n\\end{document}\n")
    (let ((latex-tempo-add-usepackage t))
      (latex-tempo-expand-or-tab))
    (goto-char (point-min))
    (should (= 1 (how-many (regexp-quote "\\usepackage{graphicx}"))))))

(ert-deftest latex-tempo-test-no-preamble-no-insert ()
  (latex-tempo-test--with-buffer "<k|"
    (let ((latex-tempo-add-usepackage t))
      (latex-tempo-expand-or-tab))
    (should-not (latex-tempo--package-loaded-p "amssymb"))))

;;;; Minor mode

(ert-deftest latex-tempo-test-mode-binds-tab ()
  (with-temp-buffer
    (latex-mode)
    (latex-tempo-mode 1)
    (should (eq (key-binding (kbd "TAB")) #'latex-tempo-expand-or-tab))
    (should (eq (key-binding (kbd "C-c C-,")) #'latex-tempo-insert-structure))
    (latex-tempo-mode -1)
    (should-not (eq (key-binding (kbd "TAB")) #'latex-tempo-expand-or-tab))))

(provide 'latex-tempo-test)
;;; latex-tempo-test.el ends here
