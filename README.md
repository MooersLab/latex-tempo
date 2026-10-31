# latex-tempo

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Org-tempo style `<key TAB` templates for LaTeX buffers in Emacs.

In Org mode you can type `<s` at the start of a line and press TAB to get a source block. latex-tempo brings that habit to LaTeX. Type `<q` and press TAB in a LaTeX buffer, and you get

```latex
\begin{quote}
_
\end{quote}
```

with point on the empty line. The package works with the built-in `latex-mode` and with AUCTeX.

## Features

- Nineteen short keys for environments, lists, figures, tables, sectioning commands and index entries.
- Leading indentation is kept.
- TAB falls back to its usual job when the text before point is not a key.
- `C-c C-,` offers the same templates through completion and wraps the active region, like `org-insert-structure-template`.
- Templates that need a package (minted, booktabs, graphicx, amssymb, comment) check the preamble and can add the missing `\usepackage` line.
- The template table is a customizable variable, so you can add your own keys.

## Keys

| Key    | Result                                                  | Package  |
|--------|---------------------------------------------------------|----------|
| `<a`   | verbatim environment                                    |          |
| `<c`   | center environment                                      |          |
| `<C`   | comment environment                                     | comment  |
| `<E`   | comment environment with a note line                    | comment  |
| `<h`   | comment environment with a note line                    | comment  |
| `<l`   | pair of marker comments for raw LaTeX                   |          |
| `<q`   | quote environment                                       |          |
| `<v`   | verbatim environment                                    |          |
| `<m`   | minted environment, prompts for the language            | minted   |
| `<e`   | enumerate list with five items                          |          |
| `<i`   | itemize list with five items                            |          |
| `<k`   | checklist with five boxed items                         | amssymb  |
| `<I`   | new `\item`                                             |          |
| `<f`   | figure with `\includegraphics`, prompts for the width   | graphicx |
| `<t`   | table with five columns, a header row and two data rows | booktabs |
| `<su`  | `\subsection{}`                                         |          |
| `<ssu` | `\subsubsection{}`                                      |          |
| `<p`   | `\paragraph{}`                                          |          |
| `<x`   | `\index{}`                                              |          |

Keys are case sensitive, so `<i` and `<I` differ.

## Installation

### From MELPA

When the package is available on MELPA:

```elisp
(use-package latex-tempo
  :ensure t
  :hook ((LaTeX-mode . latex-tempo-mode)
         (latex-mode . latex-tempo-mode)))
```

### From source

```bash
git clone https://github.com/MooersLab/latex-tempo.git ~/path/to/latex-tempo
```

```elisp
(add-to-list 'load-path "~/path/to/latex-tempo/")
(require 'latex-tempo)
(add-hook 'LaTeX-mode-hook #'latex-tempo-mode)   ; AUCTeX
(add-hook 'latex-mode-hook #'latex-tempo-mode)   ; built-in tex-mode
```

### With straight.el

```elisp
(use-package latex-tempo
  :straight (:host github :repo "MooersLab/latex-tempo")
  :hook ((LaTeX-mode . latex-tempo-mode)
         (latex-mode . latex-tempo-mode)))
```

## Usage

- Type a key such as `<f` at the start of a line and press TAB.
- Press `C-c C-,` to pick a template by name. Select text first to wrap it.
- Run `M-x latex-tempo-list-templates` to see every key.

## Customization

Run `M-x customize-group RET latex-tempo RET`. The main options are

| Option                             | Default   | Purpose                                     |
|------------------------------------|-----------|---------------------------------------------|
| `latex-tempo-templates`            | see above | the template table                          |
| `latex-tempo-default-language`     | `"python"`| default language for `<m`                   |
| `latex-tempo-languages`            | list      | languages offered for completion            |
| `latex-tempo-default-figure-width` | `"0.8"`   | default fraction of `\textwidth` for `<f`   |
| `latex-tempo-add-usepackage`       | `ask`     | `nil`, `ask` or `t` for missing packages    |

### Adding a template

```elisp
(with-eval-after-load 'latex-tempo
  (add-to-list 'latex-tempo-templates
               '("eq" :env "equation" :desc "Equation"))
  (add-to-list 'latex-tempo-templates
               '("al" :package "amsmath"
                 :template ("\\begin{align}"
                            "  @@ &=  \\\\"
                            "     &= "
                            "\\end{align}")
                 :desc "Align, two lines")))
```

In a `:template`, `@@` marks where point goes and `<<arg>>` is replaced by a prompted argument. The manual describes every property.

## Documentation

The manual source is [doc/latex-tempo.org](doc/latex-tempo.org). Build the Info and Texinfo versions with `make doc`, or a PDF with `make pdf`.

## Development

| Command         | Action                                              |
|-----------------|-----------------------------------------------------|
| `make`          | byte-compile and run the tests                      |
| `make test`     | run the ERT test suite in `test/`                   |
| `make checkdoc` | check documentation strings                         |
| `make lint`     | run package-lint (fetched from GitHub on first use) |
| `make check`    | compile, test, checkdoc and lint                    |
| `make doc`      | build `doc/latex-tempo.texi` and `doc/latex-tempo.info` |
| `make clean`    | remove generated files                              |

Use another Emacs with `make test EMACS=/path/to/emacs`.

### Suggested MELPA recipe

```elisp
(latex-tempo :fetcher github
             :repo "MooersLab/latex-tempo"
             :files (:defaults "doc/latex-tempo.texi"))
```

## License

Copyright (C) 2026 Blaine Mooers.

latex-tempo is free software released under the GNU General Public License, version 3 or (at your option) any later version. See [LICENSE](LICENSE). This license is accepted by MELPA.

## Author

Blaine Mooers, Department of Biochemistry and Physiology, University of Oklahoma Health Campus. blaine-mooers@ou.edu
