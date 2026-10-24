;;; early-init.el --- vor dem ersten Frame  -*- lexical-binding: t; -*-

;; Die Konfiguration liegt in ~/dotfiles (verlinkt nach ~/.config/emacs).
;; Alles, was Emacs selbst schreibt (Pakete, Verlauf, custom.el, Auto-Saves),
;; landet in ~/.local/share/emacs statt im Repo.
(setq user-emacs-directory
      (expand-file-name "emacs/" (or (getenv "XDG_DATA_HOME") "~/.local/share")))
(make-directory user-emacs-directory t)
;; Diese beiden stehen schon vorher fest und folgen dem nicht von selbst
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory)
      auto-save-list-file-prefix (expand-file-name "auto-save-list/.saves-" user-emacs-directory))

;; macOS: native Kompilierung scheitert unter
;; macOS 27 (clang: invalid version number in '-mmacosx-version-min=18.0').
;; Auch die Trampoline aus, sonst brechen evil, magit … beim Laden ab.
;; Pakete laufen als Bytecode.
(when (eq system-type 'darwin)
  (setq native-comp-jit-compilation nil
        native-comp-enable-subr-trampolines nil
        native-comp-async-report-warnings-errors 'silent))

;; Schneller Start: GC erst danach wieder normal (init.el setzt das zurück)
(setq gc-cons-threshold most-positive-fixnum)

;; Leisten gar nicht erst zeichnen (kein Flackern beim Start)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
;; macOS: JetBrains Mono wie in Ghostty (Brewfile), Iosevka gibt es dort nicht
(push `(font . ,(if (eq system-type 'darwin) "JetBrains Mono-18" "Iosevka-14"))
      default-frame-alist)
(setq inhibit-startup-message t
      initial-scratch-message nil)
