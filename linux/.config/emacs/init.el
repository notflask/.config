;;; init.el --- Emacs für C/C++, Farben von matugen  -*- lexical-binding: t; -*-

;; Läuft als Daemon (systemd: emacs.service, mit der grafischen Sitzung);
;; Fenster öffnen mit `emacsclient -c` bzw. Super+N.

;; Pakete kommen beim ersten Start von MELPA/GNU ELPA (dauert einmal etwas).
;; Sprachserver: clangd (llvm-core/clang). Farben: themes/matugen-theme.el,
;; erzeugt von matugen (templates/emacs-theme.el), lädt sich selbst neu.

(setq gc-cons-threshold (* 64 1024 1024)
      read-process-output-max (* 4 1024 1024)) ; clangd schickt große Antworten
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;; ========= packages =======
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(setq use-package-always-ensure t)

;; ========= theme ==========
;; matugen schreibt die Datei bei jedem Wechsel von Wallpaper oder hell/dunkel
;; neu; dann wird sie hier sofort wieder geladen.
(defconst my/theme-dir
  (expand-file-name "themes/" (file-name-directory (file-truename user-init-file))))
(add-to-list 'custom-theme-load-path my/theme-dir)

(defun my/load-matugen-theme (&rest _)
  (when (file-exists-p (expand-file-name "matugen-theme.el" my/theme-dir))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme 'matugen t)))
(my/load-matugen-theme)

(require 'filenotify)
(file-notify-add-watch my/theme-dir '(change)
                       (lambda (event)
                         (when (string-suffix-p "matugen-theme.el" (format "%s" (nth 2 event)))
                           (run-with-idle-timer 0.2 nil #'my/load-matugen-theme))))

;; ========= editor =========

;; jedes neue Fenster maximiert (auch die von emacsclient beim Daemon)
(add-to-list 'default-frame-alist '(fullscreen . maximized))

;; disable backup files creation
(setq make-backup-files nil
      auto-save-default nil
      create-lockfiles nil)

;; enable line numbers
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;; basic user interface configuration
(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(global-auto-revert-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(setq-default indent-tabs-mode nil
              fill-column 100)
(setq scroll-margin 4
      scroll-conservatively 101
      ring-bell-function #'ignore
      use-short-answers t)

;; Modeline wie die Leiste: nur Text mit „·“ dazwischen, keine Nebenmodi
;;   ● benchmark.cpp · 5:0 · c++ · master · 2 Fehler
(defun my/ml-sep () (propertize " · " 'face 'shadow))
(defun my/ml-errors ()
  (when (bound-and-true-p flymake-mode)
    (let ((n (length (seq-filter (lambda (d) (eq (flymake-diagnostic-type d) :error))
                                 (flymake-diagnostics)))))
      (when (> n 0)
        (concat (my/ml-sep) (propertize (format "%d Fehler" n) 'face 'error))))))
(setq-default mode-line-format
              '(" "
                (:eval (propertize (if (buffer-modified-p) "● " "  ") 'face 'mode-line-emphasis))
                (:eval (propertize (buffer-name) 'face 'mode-line-buffer-id))
                (:eval (my/ml-sep)) "%l:%c"
                (:eval (my/ml-sep))
                (:eval (downcase (string-remove-suffix "-mode" (symbol-name major-mode))))
                (:eval (when vc-mode   ; " Git:master" -> "master"
                         (concat (my/ml-sep)
                                 (propertize (replace-regexp-in-string "^ ?[A-Za-z]+[:-]" "" vc-mode)
                                             'face 'shadow))))
                (:eval (my/ml-errors))))

;; which-key (eingebaut ab Emacs 30): zeigt mögliche Tasten nach einem Präfix
(which-key-mode 1)

;; use 'evil' for vi like navigation
(use-package evil
  :init
  (setq evil-want-keybinding nil   ; evil-collection übernimmt das
        evil-want-C-u-scroll t
        evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

;; vim-Tasten auch in magit, dired, xref, compilation …
(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; use 'magit' to interact with git
(use-package magit)

;; ========= completion =====
;; use 'vertico' for M-x completion
(use-package vertico
  :init
  (vertico-mode))

;; Suchen mit Leerzeichen-getrennten Teilen in beliebiger Reihenfolge
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion)))))

;; Beschreibungen neben den Kandidaten
(use-package marginalia
  :init
  (marginalia-mode))

;; Suchen/Springen: Zeilen, ripgrep im Projekt, Symbole, Fehler
(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("M-s l" . consult-line)
         ("M-s r" . consult-ripgrep)
         ("M-s i" . consult-imenu)
         ("M-g e" . consult-flymake)
         ("M-g g" . consult-goto-line))
  :config
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

;; Vervollständigung im Text als Popup (Daten kommen von clangd über eglot)
(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  :init
  (global-corfu-mode)
  (corfu-popupinfo-mode))

(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file))

;; ========= C/C++ ==========
;; cc-mode + eglot mit clangd: Vervollständigung, Fehler beim Tippen
;; (flymake), Springen zu Definition/Verwendungen, Umbenennen,
;; Code-Actions, Formatieren mit clang-format.
(setq c-default-style '((java-mode . "java") (awk-mode . "awk") (other . "k&r"))
      c-basic-offset 4)

(use-package eglot
  :ensure nil
  :hook ((c-mode c++-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-config '(:size 0))  ; kein Protokoll, schneller
  (eglot-ignored-server-capabilities '(:inlayHintProvider))
  :config
  (add-to-list 'eglot-server-programs
               '((c-mode c++-mode)
                 . ("clangd" "--background-index" "--clang-tidy"
                    "--completion-style=detailed" "--header-insertion=never"
                    "--pch-storage=memory" "-j=8"))))

;; Mit .clang-format im Projekt beim Speichern formatieren
(defun my/clang-format-on-save ()
  (when (and (eglot-managed-p)
             (locate-dominating-file default-directory ".clang-format"))
    (eglot-format-buffer)))
(defun my/c-setup ()
  (add-hook 'before-save-hook #'my/clang-format-on-save nil t))
(add-hook 'c-mode-common-hook #'my/c-setup)

;; Header <-> Quelldatei (foo.h <-> foo.cpp)
(setq ff-search-directories '("." "../include" "../src" "../inc" "include" "src"))

;; CMake-Dateien
(use-package cmake-mode)

;; Bauen: compile/recompile im Projekt, Farben und Mitlaufen im Puffer
(setq compilation-scroll-output 'first-error
      compilation-ask-about-save nil)
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

;; Debuggen: M-x gdb mit allen Fenstern (Quellcode, Variablen, Stack …)
(setq gdb-many-windows t
      gdb-show-main t)

;; Leader-Tasten (Leertaste im Normal-Modus), wie in Neovim
(with-eval-after-load 'evil
  (evil-set-leader '(normal visual motion) (kbd "SPC"))
  (dolist (b '(("ff" . project-find-file)
               ("fg" . consult-ripgrep)
               ("fb" . consult-buffer)
               ("fr" . recentf-open)
               ("gg" . magit-status)
               ("ca" . eglot-code-actions)
               ("cr" . eglot-rename)
               ("cf" . eglot-format-buffer)
               ("ce" . consult-flymake)
               ("ch" . ff-find-other-file)
               ("cc" . project-compile)
               ("cR" . recompile)
               ("cd" . gdb)))
    (evil-define-key '(normal visual motion) 'global
      (kbd (concat "<leader>" (car b))) (cdr b)))
  ;; K = Doku unter dem Cursor, ]d/[d = nächster/voriger Fehler
  (evil-define-key 'normal 'eglot-mode-map
    (kbd "K") #'eldoc-box-help-at-point
    (kbd "]d") #'flymake-goto-next-error
    (kbd "[d") #'flymake-goto-prev-error))

(recentf-mode 1)

;; Doku im kleinen Fenster am Cursor statt unten im Echo-Bereich
(use-package eldoc-box)
