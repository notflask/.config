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

;; Schneller Start: GC erst danach wieder normal (init.el setzt das zurück)
(setq gc-cons-threshold most-positive-fixnum)

;; Leisten gar nicht erst zeichnen (kein Flackern beim Start)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(font . "Iosevka-14") default-frame-alist)
(setq inhibit-startup-message t
      initial-scratch-message nil)
