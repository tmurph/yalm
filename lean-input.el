;;; lean-input.el --- lean-mode input method  -*- lexical-binding: t; -*-

;; Copyright (c) 2005-2012 Ulf Norell, Nils Anders Danielsson,
;; Catarina Coquand, Makoto Takeyama, Andreas Abel, Karl Mehltretter,
;; Marcin Benke, Darin Morrison.
;; Copyright © 2026 Trevor Murphy

;; This file is not part of GNU Emacs.

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; A highly customisable input method which can inherit from other
;; Quail input methods.  By default the input method is geared towards
;; the input of mathematical and other symbols in Lean programs.

;; Use M-x customize-group lean-input to customise this input method.
;; Note that the functions defined under "Functions used to tweak
;; translation pairs" below can be used to tweak both the key
;; translations inherited from other input methods as well as the
;; ones added specifically for this one.

;; Use lean-input-show-translations to see all the characters which
;; can be typed using this input method (except for those
;; corresponding to ASCII characters).

;;; Code:

(require 'quail)

;;;; Customization

(defgroup lean-input nil
  "The Lean input method.
After tweaking these settings you may want to inspect the resulting
translations using `lean-input-show-translations'."
  :group 'lean
  :group 'leim)

(defcustom lean-input-data-directory
  (expand-file-name "data/" (file-name-directory (or load-file-name (buffer-file-name))))
  "Directory in which abbreviations.json resides."
  :group 'lean-input
  :type 'directory)

(defcustom lean-input-user-translations nil
  "A list of translations specific to the Lean input method.
Each element is a pair (KEY-SEQUENCE-STRING . LIST-OF-TRANSLATION-STRINGS).
All the translation strings are possible translations
of the given key sequence; if there is more than one you can choose
between them using the arrow keys.

These translation pairs are included first, before thoseinherited
from other input methods."
  :group 'lean-input
  :type '(repeat (cons (string :tag "Key sequence")
                       (repeat :tag "Translations" string))))

;;;; Package Def

;; We define the quail package at the toplevel so that it is evaluated
;; at load time.

(let ((guidance t)
      (maximum-shortest t))
  (quail-define-package
   "Lean" "UTF-8" "∏" guidance
   "Lean input method.
These characters are drawn largely from the TeX input method, with
modifications to better support editing Lean programs."
   nil nil nil nil nil nil maximum-shortest))

;;;; Utility Functions

(defun lean-input--user-translations ()
  "Process `lean-input-user-translations' to quail rules."
  (cl-loop for (key . trans) in lean-input-user-translations
           collect (cons key (vconcat trans))))

(defun lean-input--abbreviations ())

(defun lean-input--parents ())

(defun lean-input--define-rules (rules)
  (let ((newrules ()))
    (dolist (rule rules)
      (pcase rule
        (`(,_ ,(pred characterp)) (push rule newrules)) ; Normal quail rule
        ))

    ;; (quail-define-rules (nreverse newrules))
    ))

;;;; Rule Definitions

(lean-input--define-rules (lean-input--user-translations))
(lean-input--define-rules (lean-input--abbreviations))
(lean-input--define-rules (lean-input--parents))


;; Inspecting and modifying translation maps

;; Setting up the input method

;;; Do not use `provide' here, because we don't want this file loaded by
;;; the user (it would activate the input method).  Instead add this
;;; library as a prereq to the appropriate `register-input-method'.

;;; lean-input.el ends here
