;;; latex-tempo.el --- Org-tempo style <key TAB templates for LaTeX buffers  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; Author: Blaine Mooers <blaine-mooers@ou.edu>
;; Maintainer: Blaine Mooers <blaine-mooers@ou.edu>
;; Version: 0.5.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: tex, wp, convenience
;; URL: https://github.com/MooersLab/latex-tempo
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Org mode expands short keys typed at the start of a line, such as
;; "<s" followed by TAB, into structure blocks.  This feature comes from
;; the org-tempo library.  The present package brings the same style of
;; keys to LaTeX buffers.  Typing "<q" and then TAB in a LaTeX buffer
;; inserts
;;
;;   \begin{quote}
;;   _
;;   \end{quote}
;;
;; with point on the empty line.
;;
;; Key    LaTeX result
;; ---    ------------
;; <a     verbatim environment
;; <c     center environment
;; <C     comment environment (comment package)
;; <E     comment environment with a note line
;; <h     comment environment with a note line
;; <l     pair of marker comments for raw LaTeX
;; <q     quote environment
;; <v     verbatim environment
;; <m     minted environment (prompts for language, minted package)
;; <e     enumerate list with five items
;; <i     itemize list with five items
;; <k     checklist with five boxed items (amssymb package)
;; <I     new \item
;; <f     figure with \includegraphics (prompts for width, graphicx)
;; <t     booktabs table, prompts for rows and columns (booktabs package)
;; <u     \subsection{}
;; <y     \subsubsection{}
;; <p     \paragraph{}
;; <x     \index{}
;;
;; Keys are case sensitive, so <i and <I differ.  Every built-in key is
;; a single character, but templates that you add may use longer keys.
;;
;; The command `latex-tempo-insert-structure', bound to C-c C-, as in
;; Org, shows the templates in a menu and inserts one with a single
;; keypress.  Pressing TAB or SPC in the menu switches to choosing by
;; name with completion, which is also available directly as
;; `latex-tempo-insert-structure-by-name'.  Both commands wrap the
;; active region for environment templates such as <q.
;;
;; When a template needs a package and the buffer holds \begin{document}
;; but no matching \usepackage line, the package can add the line to the
;; preamble.  See `latex-tempo-add-usepackage'.
;;
;; Setup:
;;
;;   (add-to-list 'load-path "~/path/to/latex-tempo/")
;;   (require 'latex-tempo)
;;   (add-hook 'LaTeX-mode-hook #'latex-tempo-mode)   ; AUCTeX
;;   (add-hook 'latex-mode-hook #'latex-tempo-mode)   ; built-in tex-mode
;;
;; Edit `latex-tempo-templates' to add keys or change the results.

;;; Code:

(require 'subr-x)

(defvar latex-tempo-mode)               ; Declared special for the fallback.

(defgroup latex-tempo nil
  "Org-tempo style templates for LaTeX."
  :group 'tex
  :prefix "latex-tempo-")

(defcustom latex-tempo-templates
  '(;; Environments that wrap a body (and the region from C-c C-,).
    ("a" :env "verbatim"
     :desc "ASCII export block (verbatim)")
    ("c" :env "center"
     :desc "Center block")
    ("C" :env "comment" :package "comment"
     :desc "Comment block")
    ("E" :env "comment" :package "comment"
     :first-line "% Export block for another backend.  LaTeX ignores it."
     :desc "Export block (hidden from LaTeX)")
    ("h" :env "comment" :package "comment"
     :first-line "% HTML-only content.  LaTeX ignores it."
     :desc "HTML export block (hidden from LaTeX)")
    ("l" :open "% begin raw LaTeX" :close "% end raw LaTeX"
     :desc "Raw LaTeX block (marker comments)")
    ("q" :env "quote"
     :desc "Quote block")
    ("v" :env "verbatim"
     :desc "Verbatim block")
    ("m" :env "minted" :arg language :package "minted"
     :desc "Minted source block")
    ;; Multi-line templates.  "@@" marks where point goes; any later
    ;; "@@" is removed.  "<<arg>>" is replaced by the prompted argument.
    ("e"
     :template ("\\begin{enumerate}"
                "  \\item @@"
                "  \\item "
                "  \\item "
                "  \\item "
                "  \\item "
                "\\end{enumerate}")
     :desc "Enumerated list, five items")
    ("i"
     :template ("\\begin{itemize}"
                "  \\item @@"
                "  \\item "
                "  \\item "
                "  \\item "
                "  \\item "
                "\\end{itemize}")
     :desc "Itemized list, five items")
    ("k" :package "amssymb"
     :template ("\\begin{itemize}"
                "  \\item[$\\square$] @@"
                "  \\item[$\\square$] "
                "  \\item[$\\square$] "
                "  \\item[$\\square$] "
                "  \\item[$\\square$] "
                "\\end{itemize}")
     :desc "Checklist, five boxed items")
    ("f" :arg width :package "graphicx"
     :template ("\\begin{figure}[htbp]"
                "  \\centering"
                "  \\includegraphics[width=<<arg>>\\textwidth]{@@}"
                "  \\caption{}"
                "  \\label{fig:}"
                "\\end{figure}")
     :desc "Figure with includegraphics")
    ("t" :arg table-size :package "booktabs"
     :template latex-tempo--table-lines
     :desc "Booktabs table, prompts for rows and columns")
    ;; One-line commands.
    ("I" :inline "\\item " :close ""
     :desc "New item")
    ("u" :inline "\\subsection{" :close "}"
     :desc "Subsection")
    ("y" :inline "\\subsubsection{" :close "}"
     :desc "Subsubsection")
    ("p" :inline "\\paragraph{" :close "}"
     :desc "Paragraph")
    ("x" :inline "\\index{" :close "}"
     :desc "Index key"))
  "Templates keyed by the letters typed after \"<\".
Each entry is (KEY . PLIST).  Keys are case sensitive and may have
more than one letter.  PLIST holds

  :env         Name of a LaTeX environment to wrap in \\begin and \\end.
  :open :close Literal opening and closing lines, used when :env is absent.
  :template    List of lines.  \"@@\" marks point and \"<<arg>>\" the argument.
               It may instead be a function that takes the argument and
               returns such a list.
  :inline      Opening string of a one-line command; :close ends it.
  :arg         The symbol `language', `width', `table-size' or `file'
               to prompt for.
  :first-line  Optional line placed just after an :env opening line.
  :package     LaTeX package that the template needs.
  :desc        Short description shown in the menu."
  :type '(alist :key-type string :value-type plist))

(defcustom latex-tempo-default-language "python"
  "Default language for the minted environment."
  :type 'string)

(defcustom latex-tempo-languages
  '("python" "r" "latex" "bash" "elisp" "clojure" "org" "text"
    "c" "cpp" "fortran" "julia" "sql" "json" "yaml")
  "Languages offered for completion by the <m template."
  :type '(repeat string))

(defcustom latex-tempo-default-figure-width "0.8"
  "Default figure width as a fraction of \\textwidth."
  :type 'string)

(defcustom latex-tempo-default-table-rows 2
  "Default number of body rows for the <t table template.
The header row is added to this number."
  :type 'natnum)

(defcustom latex-tempo-default-table-columns 5
  "Default number of columns for the <t table template."
  :type 'natnum)

(defcustom latex-tempo-high-priority t
  "When non-nil, TAB looks for a template before other minor modes.
Packages such as yasnippet and `outline-minor-mode' also bind TAB,
and a minor mode loaded later normally wins.  With this option on,
latex-tempo checks for a <key first and passes TAB on to the other
binding when no key is before point.  The option takes effect the
next time `latex-tempo-mode' is turned on."
  :type 'boolean)

(defcustom latex-tempo-add-usepackage 'ask
  "Whether to add a missing \\usepackage line to the preamble.
nil means only show a message, `ask' means ask first, and t means
add the line without asking.  The line is added only when the
buffer contains \\begin{document}."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "Ask" ask)
                 (const :tag "Always" t)))

(defvar latex-tempo--language-history nil
  "Minibuffer history for minted languages.")

(defvar latex-tempo--width-history nil
  "Minibuffer history for figure widths.")

;;;; Reading arguments

(defun latex-tempo--read-language ()
  "Read a minted language name."
  (let ((lang (completing-read
               (format "Language (default %s): " latex-tempo-default-language)
               latex-tempo-languages nil nil nil
               'latex-tempo--language-history latex-tempo-default-language)))
    (if (string-empty-p lang) latex-tempo-default-language lang)))

(defun latex-tempo--read-width ()
  "Read a figure width as a fraction of \\textwidth."
  (let ((w (read-string
            (format "Width as fraction of \\textwidth (default %s): "
                    latex-tempo-default-figure-width)
            nil 'latex-tempo--width-history latex-tempo-default-figure-width)))
    (if (string-empty-p w) latex-tempo-default-figure-width w)))

(defun latex-tempo--read-positive-integer (prompt default)
  "Read a positive integer with PROMPT, offering DEFAULT.
Ask again until the answer is a whole number of at least 1."
  (let (n)
    (while (not (and (integerp n) (> n 0)))
      (setq n (read-number (if n
                               (format "Please enter a whole number of at least 1. %s"
                                       prompt)
                             prompt)
                           default)))
    n))

(defun latex-tempo--read-table-size ()
  "Read the number of body rows and columns for a table.
Return a cons cell (ROWS . COLUMNS)."
  (let* ((rows (latex-tempo--read-positive-integer
                "Number of body rows (header row not counted): "
                latex-tempo-default-table-rows))
         (cols (latex-tempo--read-positive-integer
                "Number of columns: "
                latex-tempo-default-table-columns)))
    (cons rows cols)))

(defun latex-tempo--table-row (cols)
  "Return one empty tabular row with COLS columns."
  (concat "    " (mapconcat #'identity (make-list cols " ") "&") "\\\\"))

(defun latex-tempo--table-lines (size)
  "Return the lines of a booktabs table of SIZE.
SIZE is a cons cell (ROWS . COLUMNS).  ROWS counts the body rows;
a header row sits above the \\midrule.  Point goes in the caption."
  (let* ((rows (car size))
         (cols (cdr size))
         (row (latex-tempo--table-row cols)))
    (append (list "\\begin{table}[htbp]"
                  "  \\centering"
                  "  \\caption{@@}"
                  "  \\label{tab:}"
                  (concat "  \\begin{tabular}{" (make-string cols ?l) "}")
                  "    \\toprule"
                  row
                  "    \\midrule")
            (make-list rows row)
            (list "    \\bottomrule"
                  "  \\end{tabular}"
                  "\\end{table}"))))

(defun latex-tempo--read-file ()
  "Read a file name and return it relative to the current file.
A trailing .tex extension is dropped, as \\input expects."
  (let* ((file (read-file-name "Input file: "))
         (dir (if buffer-file-name
                  (file-name-directory buffer-file-name)
                default-directory))
         (rel (file-relative-name file dir)))
    (if (string-suffix-p ".tex" rel) (file-name-sans-extension rel) rel)))

(defun latex-tempo--read-arg (spec)
  "Prompt for the argument that SPEC needs, or return nil."
  (pcase (plist-get spec :arg)
    ('language (latex-tempo--read-language))
    ('width (latex-tempo--read-width))
    ('table-size (latex-tempo--read-table-size))
    ('file (latex-tempo--read-file))
    (_ nil)))

;;;; Package check

(defun latex-tempo--package-loaded-p (pkg)
  "Return non-nil if a \\usepackage line in the buffer names PKG."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward
     (concat "^[^%\n]*\\\\\\(?:usepackage\\|RequirePackage\\)"
             "\\(?:\\[[^]]*\\]\\)?{\\(?:[^}]*[,[:space:]]\\)?"
             (regexp-quote pkg) "[},[:space:]]")
     nil t)))

(defun latex-tempo--check-package (pkg)
  "Make sure PKG is loaded, following `latex-tempo-add-usepackage'."
  (unless (latex-tempo--package-loaded-p pkg)
    (let ((docpos (save-excursion
                    (goto-char (point-min))
                    (re-search-forward "^[ \t]*\\\\begin{document}" nil t))))
      (cond
       ((not docpos)
        (message "latex-tempo: the main file needs \\usepackage{%s}" pkg))
       ((or (eq latex-tempo-add-usepackage t)
            (and (eq latex-tempo-add-usepackage 'ask)
                 (y-or-n-p (format "Add \\usepackage{%s} to the preamble? "
                                   pkg))))
        (save-excursion
          (goto-char docpos)
          (beginning-of-line)
          (insert "\\usepackage{" pkg "}\n")))
       (t
        (message "latex-tempo: remember to add \\usepackage{%s}" pkg))))))

;;;; Insertion

(defun latex-tempo--open-close (spec arg)
  "Return (OPEN . CLOSE) strings for SPEC with optional ARG."
  (let ((env (plist-get spec :env)))
    (if env
        (cons (concat "\\begin{" env "}" (if arg (concat "{" arg "}") ""))
              (concat "\\end{" env "}"))
      (cons (plist-get spec :open) (plist-get spec :close)))))

(defun latex-tempo--line-prefix ()
  "Start a fresh line if needed and return its leading whitespace."
  (unless (string-blank-p (buffer-substring (line-beginning-position) (point)))
    (newline))
  (buffer-substring (line-beginning-position) (point)))

(defun latex-tempo--insert-at-point (open close first-line)
  "Insert OPEN, FIRST-LINE, an empty body line and CLOSE at point.
Point ends on the body line."
  (let ((ind (latex-tempo--line-prefix))
        body)
    (insert open "\n")
    (when first-line (insert ind first-line "\n"))
    (insert ind)
    (setq body (point))
    (insert "\n" ind close)
    (unless (eolp) (insert "\n"))
    (goto-char body)))

(defun latex-tempo--insert-template (lines arg)
  "Insert the template LINES at point, filling in ARG.
LINES is a list of strings, or a function that takes ARG and returns
one.  In a list of strings, \"<<arg>>\" is replaced by ARG.  Point goes
to the first \"@@\" marker; later markers are removed."
  (when (functionp lines)
    (setq lines (funcall lines arg)
          arg nil))
  (let* ((ind (latex-tempo--line-prefix))
         (start (point))
         (text (mapconcat
                (lambda (l)
                  (if (stringp arg)
                      (replace-regexp-in-string "<<arg>>" arg l t t)
                    (replace-regexp-in-string "<<arg>>" "" l t t)))
                lines (concat "\n" ind)))
         (end nil)
         (pos nil))
    (insert text)
    (unless (eolp) (insert "\n"))
    (setq end (point-marker))
    (goto-char start)
    (when (search-forward "@@" end t)
      (replace-match "" t t)
      (setq pos (point))
      (while (search-forward "@@" end t)
        (replace-match "" t t)))
    (goto-char (or pos end))
    (set-marker end nil)))

(defun latex-tempo--wrap-lines (open close first-line beg end)
  "Wrap the whole lines from BEG to END between OPEN and CLOSE.
FIRST-LINE, when non-nil, goes just after OPEN."
  (let* ((start (save-excursion (goto-char beg) (line-beginning-position)))
         (stop (copy-marker
                (save-excursion
                  (goto-char end)
                  (if (and (bolp) (> end start)) (point) (line-end-position)))))
         ind)
    (goto-char start)
    (setq ind (make-string (current-indentation) ?\s))
    (insert ind open "\n")
    (when first-line (insert ind first-line "\n"))
    (goto-char stop)
    ;; STOP is either the start of the line after the region or the
    ;; end of the last region line.  Keep the line break in both cases.
    (if (bolp)
        (insert ind close "\n")
      (insert "\n" ind close))
    (set-marker stop nil)))

(defun latex-tempo--insert-inline (open close arg beg end)
  "Insert OPEN, ARG or the region from BEG to END, and CLOSE."
  (if beg
      (let ((text (buffer-substring beg end)))
        (delete-region beg end)
        (goto-char beg)
        (insert open text close))
    (insert open (or arg ""))
    (if arg
        (insert close)
      (save-excursion (insert close)))))

(defun latex-tempo--insert (spec arg &optional beg end)
  "Insert template SPEC with argument ARG.
With BEG and END, wrap that region when SPEC is an environment or a
one-line command.  Multi-line templates are inserted at point."
  (cond
   ((plist-get spec :template)
    (latex-tempo--insert-template (plist-get spec :template) arg))
   ((plist-get spec :inline)
    (latex-tempo--insert-inline (plist-get spec :inline)
                                (plist-get spec :close) arg beg end))
   (t
    (let ((oc (latex-tempo--open-close spec arg))
          (first-line (plist-get spec :first-line)))
      (if beg
          (latex-tempo--wrap-lines (car oc) (cdr oc) first-line beg end)
        (latex-tempo--insert-at-point (car oc) (cdr oc) first-line)))))
  (let ((pkg (plist-get spec :package)))
    (when pkg (latex-tempo--check-package pkg))))

;;;; Commands

(defun latex-tempo--trigger ()
  "Return (SPEC . START) when a known <key sits before point.
The <key must be the only text on the line before point, as in Org."
  (when (looking-back "^[ \t]*\\(<\\([[:alpha:]]+\\)\\)"
                      (line-beginning-position))
    (let ((spec (cdr (assoc (match-string-no-properties 2)
                            latex-tempo-templates)))
          (start (match-beginning 1)))
      (when spec (cons spec start)))))

(defun latex-tempo--fallback ()
  "Run whatever TAB would do without `latex-tempo-mode'."
  (let* ((latex-tempo-mode nil)
         (keys (this-command-keys-vector))
         (cmd (or (and (> (length keys) 0) (key-binding keys))
                  (key-binding (kbd "TAB")))))
    (unless (commandp cmd) (setq cmd #'indent-for-tab-command))
    (setq this-command cmd)
    (call-interactively cmd)))

(defun latex-tempo-expand-or-tab ()
  "Expand a <key template before point, or else do the usual TAB."
  (interactive)
  (let ((hit (latex-tempo--trigger)))
    (if (not hit)
        (latex-tempo--fallback)
      ;; Read the argument before deleting <key, so that C-g at the
      ;; prompt leaves the buffer unchanged.
      (let ((arg (latex-tempo--read-arg (car hit))))
        (delete-region (cdr hit) (point))
        (latex-tempo--insert (car hit) arg)))))

(defun latex-tempo--complete-key ()
  "Read a template key by name with completion and return it."
  (let* ((cands (mapcar (lambda (e)
                          (cons (format "%-4s %s" (car e) (plist-get (cdr e) :desc))
                                (car e)))
                        latex-tempo-templates))
         (completion-ignore-case nil)
         (choice (completing-read "LaTeX template: " cands nil t)))
    (cdr (assoc choice cands))))

(defconst latex-tempo--menu-buffer "*LaTeX tempo menu*"
  "Name of the buffer that shows the template menu.")

(defun latex-tempo--menu-text ()
  "Return the text of the template menu."
  (concat
   (mapconcat (lambda (e)
                (format "[%s]%s %s" (car e)
                        (make-string (max 1 (- 4 (length (car e)))) ?\s)
                        (plist-get (cdr e) :desc)))
              latex-tempo-templates "\n")
   "\n\n[TAB] or [SPC]  choose by name with completion"))

(defun latex-tempo--choose-key ()
  "Show the template menu and return the key the user picks.
A single keypress picks a one-character key.  TAB or SPC switches
to choosing by name with completion, which also reaches keys that
are longer than one character."
  (let ((buf (get-buffer-create latex-tempo--menu-buffer)))
    (unwind-protect
        (save-window-excursion
          (with-current-buffer buf
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (latex-tempo--menu-text))
              (goto-char (point-min))))
          (display-buffer buf '((display-buffer-below-selected
                                 display-buffer-at-bottom)
                                (window-height . fit-window-to-buffer)))
          (let ((ch (read-char-exclusive
                     "Template key (TAB or SPC to choose by name): ")))
            (if (memq ch '(?\t ?\s))
                (latex-tempo--complete-key)
              (char-to-string ch))))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(defun latex-tempo-insert-structure (key)
  "Insert the template for KEY, wrapping the region when active.
This is the LaTeX analog of `org-insert-structure-template'.
Interactively, show a menu and read KEY with a single keypress.
Press TAB or SPC in the menu to choose by name instead."
  (interactive (list (latex-tempo--choose-key)))
  (let ((spec (cdr (assoc key latex-tempo-templates))))
    (unless spec (user-error "No LaTeX template for key %s" key))
    (let* ((region (and (use-region-p)
                        (not (plist-get spec :template))))
           (beg (and region (region-beginning)))
           (end (and region (region-end)))
           (arg (latex-tempo--read-arg spec)))
      (when (use-region-p) (deactivate-mark))
      (latex-tempo--insert spec arg beg end))))

(defun latex-tempo-insert-structure-by-name (key)
  "Insert the template for KEY, chosen by name with completion.
This does the same as `latex-tempo-insert-structure' and wraps the
active region in the same way."
  (interactive (list (latex-tempo--complete-key)))
  (latex-tempo-insert-structure key))

(defun latex-tempo-list-templates ()
  "Show the available templates in a help buffer."
  (interactive)
  (with-help-window "*LaTeX tempo templates*"
    (princ "Type <KEY then TAB at the start of a line.\n\n")
    (dolist (e latex-tempo-templates)
      (let* ((spec (cdr e))
             (tpl (plist-get spec :template))
             (shown (cond
                     ((functionp tpl) "(built from prompts)")
                     (tpl (car tpl))
                     ((plist-get spec :inline)
                      (concat (plist-get spec :inline) (plist-get spec :close)))
                     (t (car (latex-tempo--open-close spec nil))))))
        (princ (format "<%-4s %-48s %s\n"
                       (car e) (plist-get spec :desc) shown))))))

(defvar latex-tempo-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'latex-tempo-expand-or-tab)
    (define-key map (kbd "<tab>") #'latex-tempo-expand-or-tab)
    (define-key map (kbd "C-c C-,") #'latex-tempo-insert-structure)
    map)
  "Keymap for `latex-tempo-mode'.")

(defvar latex-tempo--emulation-alist nil
  "Keymap alist placed in `emulation-mode-map-alists'.
It holds the mode keymap when `latex-tempo-high-priority' is non-nil,
so that TAB reaches latex-tempo before other minor mode keymaps.")

(add-to-list 'emulation-mode-map-alists 'latex-tempo--emulation-alist)

;;;###autoload
(define-minor-mode latex-tempo-mode
  "Expand Org-style <key templates into LaTeX environments.
Type a key such as <q or <f at the start of a line and press TAB.
\\[latex-tempo-insert-structure] shows a menu, inserts a template with a
single keypress, and wraps the active region.  Press TAB or SPC in
the menu to choose by name.
\\[latex-tempo-list-templates] lists them.

\\{latex-tempo-mode-map}"
  :lighter " <s"
  :keymap latex-tempo-mode-map
  (setq latex-tempo--emulation-alist
        (and latex-tempo-high-priority
             (list (cons 'latex-tempo-mode latex-tempo-mode-map)))))

(provide 'latex-tempo)
;;; latex-tempo.el ends here
