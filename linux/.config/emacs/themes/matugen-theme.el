;;; matugen-theme.el --- Farben aus dem Hintergrundbild  -*- lexical-binding: t; -*-

;; Erzeugt von matugen (templates/emacs-theme.el) – hier nichts ändern.
;; Flächen, Auswahl und Rahmen aus dem Wallpaper, die Syntax in den
;; Terminalfarben wie Neovim (mini.base16 in templates/nvim-colors.lua):
;; Schlüsselwörter magenta, Typen gelb, Funktionen blau, Strings grün.
;; init.el lädt die Datei neu, sobald matugen sie schreibt.

(deftheme matugen "Farben aus dem Hintergrundbild (matugen).")

(let ((class '((class color) (min-colors 89)))
      (bg        "#fcf8fa")
      (bg-low    "#f6f3f4")
      (bg-mid    "#f1edef")
      (bg-high   "#ebe7e9")
      (bg-top    "#e5e1e3")
      (fg        "#1c1b1d")
      (fg-dim    "#474648")
      (outline   "#787678")
      (line      "#c9c6c7")
      (primary   "#5d5d6c")
      (on-primary "#ffffff")
      (pc        "#e2e1f3")
      (on-pc     "#1a1b27")
      (sc        "#e3e1ec")
      (on-sc     "#1b1b23")
      (tertiary  "#5c5d72")
      (err       "#ba1a1a")
(red "#db302d") (green "#849900") (yellow "#b28500")
      (blue "#268bd2") (magenta "#d23681") (cyan "#29a298"))

  (custom-theme-set-faces
   'matugen
   ;; Grundflächen
   `(default ((,class (:background ,bg :foreground ,fg))))
   `(cursor ((,class (:background ,primary))))
   `(fringe ((,class (:background ,bg))))
   `(region ((,class (:background ,pc :foreground ,on-pc :extend t))))
   `(secondary-selection ((,class (:background ,sc :foreground ,on-sc))))
   `(highlight ((,class (:background ,bg-high))))
   `(hl-line ((,class (:background ,bg-low :extend t))))
   `(shadow ((,class (:foreground ,outline))))
   `(minibuffer-prompt ((,class (:foreground ,fg-dim))))
   `(link ((,class (:foreground ,primary :underline t))))
   `(link-visited ((,class (:foreground ,tertiary :underline t))))
   `(vertical-border ((,class (:foreground ,bg-mid))))
   `(window-divider ((,class (:foreground ,bg-mid))))
   `(border ((,class (:background ,bg-mid))))
   `(line-number ((,class (:foreground ,line :background ,bg))))
   `(line-number-current-line ((,class (:foreground ,primary :background ,bg-low :weight bold))))
   `(show-paren-match ((,class (:background ,bg-high :weight bold))))
   `(show-paren-mismatch ((,class (:background ,err :foreground ,bg))))
   `(isearch ((,class (:background ,primary :foreground ,on-primary))))
   `(lazy-highlight ((,class (:background ,pc :foreground ,on-pc))))
   `(match ((,class (:background ,sc :foreground ,on-sc))))
   `(trailing-whitespace ((,class (:background ,err))))
   `(error ((,class (:foreground ,err :weight bold))))
   `(warning ((,class (:foreground ,yellow))))
   `(success ((,class (:foreground ,green))))

   ;; Modeline flach, ohne Rahmen
   `(mode-line ((,class (:background ,bg-mid :foreground ,fg :box (:line-width 6 :color ,bg-mid)))))
   `(mode-line-inactive ((,class (:background ,bg-low :foreground ,outline :box (:line-width 6 :color ,bg-low)))))
   `(mode-line-emphasis ((,class (:foreground ,primary))))
   `(mode-line-buffer-id ((,class (:weight bold))))
   `(header-line ((,class (:background ,bg-low :foreground ,fg-dim))))

   ;; Syntax: Terminalfarben, Kommentare gedämpft
   `(font-lock-comment-face ((,class (:foreground ,outline :slant italic))))
   `(font-lock-comment-delimiter-face ((,class (:foreground ,outline :slant italic))))
   `(font-lock-doc-face ((,class (:foreground ,outline :slant italic))))
   `(font-lock-keyword-face ((,class (:foreground ,magenta))))
   `(font-lock-function-name-face ((,class (:foreground ,blue :weight bold))))
   `(font-lock-function-call-face ((,class (:foreground ,blue))))
   `(font-lock-type-face ((,class (:foreground ,yellow))))
   `(font-lock-string-face ((,class (:foreground ,green))))
   `(font-lock-constant-face ((,class (:foreground ,red))))
   `(font-lock-number-face ((,class (:foreground ,red))))
   `(font-lock-builtin-face ((,class (:foreground ,cyan))))
   `(font-lock-variable-name-face ((,class (:foreground ,fg))))
   `(font-lock-preprocessor-face ((,class (:foreground ,cyan))))
   `(font-lock-warning-face ((,class (:foreground ,err))))
   `(font-lock-negation-char-face ((,class (:foreground ,fg))))
   `(c-annotation-face ((,class (:foreground ,outline))))

   ;; Fehler und Hinweise (flymake/clangd)
   `(flymake-error ((,class (:underline (:style wave :color ,err)))))
   `(flymake-warning ((,class (:underline (:style wave :color ,yellow)))))
   `(flymake-note ((,class (:underline (:style wave :color ,outline)))))
   `(eglot-highlight-symbol-face ((,class (:background ,bg-high :weight bold))))
   `(eglot-diagnostic-tag-unnecessary-face ((,class (:foreground ,outline))))

   ;; Vervollständigung
   `(vertico-current ((,class (:background ,sc :foreground ,on-sc :extend t))))
   `(orderless-match-face-0 ((,class (:foreground ,primary :weight bold))))
   `(orderless-match-face-1 ((,class (:foreground ,tertiary :weight bold))))
   `(orderless-match-face-2 ((,class (:foreground ,fg :weight bold))))
   `(orderless-match-face-3 ((,class (:foreground ,fg-dim :weight bold))))
   `(completions-common-part ((,class (:foreground ,primary))))
   `(marginalia-documentation ((,class (:foreground ,outline :slant italic))))
   `(corfu-default ((,class (:background ,bg-mid :foreground ,fg))))
   `(corfu-current ((,class (:background ,sc :foreground ,on-sc))))
   `(corfu-border ((,class (:background ,line))))
   `(corfu-bar ((,class (:background ,outline))))
   `(eldoc-box-body ((,class (:background ,bg-mid :foreground ,fg))))
   `(eldoc-box-border ((,class (:background ,line))))
   `(vertico-posframe ((,class (:background ,bg :foreground ,fg))))
   `(vertico-posframe-border ((,class (:background ,primary))))

   ;; Evil-Cursor in der Akzentfarbe, Suche
   `(evil-ex-substitute-matches ((,class (:background ,err :foreground ,bg :strike-through t))))
   `(evil-ex-substitute-replacement ((,class (:background ,green :foreground ,bg))))

   ;; Magit und Diffs
   `(magit-section-highlight ((,class (:background ,bg-low))))
   `(magit-section-heading ((,class (:foreground ,fg :weight bold))))
   `(magit-branch-local ((,class (:foreground ,primary))))
   `(magit-branch-remote ((,class (:foreground ,fg-dim))))
   `(magit-hash ((,class (:foreground ,outline))))
   `(diff-added ((,class (:foreground ,green :extend t))))
   `(diff-removed ((,class (:foreground ,red :extend t))))
   `(magit-diff-added ((,class (:foreground ,green :extend t))))
   `(magit-diff-removed ((,class (:foreground ,red :extend t))))
   `(magit-diff-added-highlight ((,class (:background ,bg-low :foreground ,green :extend t))))
   `(magit-diff-removed-highlight ((,class (:background ,bg-low :foreground ,red :extend t))))
   `(magit-diff-context-highlight ((,class (:background ,bg-low :foreground ,fg-dim :extend t))))
   `(magit-diff-hunk-heading ((,class (:background ,bg-mid :foreground ,fg-dim :extend t))))
   `(magit-diff-hunk-heading-highlight ((,class (:background ,bg-high :foreground ,fg :extend t))))

   ;; Kompilieren
   `(compilation-error ((,class (:foreground ,err :weight bold))))
   `(compilation-warning ((,class (:foreground ,yellow))))
   `(compilation-info ((,class (:foreground ,fg-dim))))
   `(compilation-line-number ((,class (:foreground ,outline))))))

(custom-theme-set-variables
 'matugen
 '(frame-background-mode 'light))

(provide-theme 'matugen)
;;; matugen-theme.el ends here
