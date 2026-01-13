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

(defcustom lean-input-translations-file
  (expand-file-name "data/translations.json"
                    (file-name-directory (or load-file-name (buffer-file-name))))
  "A file containing translations specific to the Lean input method.
The file must parse as a valid JSON object, which will be interpreted as
a hashtable of KEY-SEQUENCE-STRING: TRANSLATION pairs.

TRANSLATION can be:
- a number (interpreted as a unicode code point)
- a string of length 1 (interpreted as a char)
- a string of length >1 (interpreted as a translation string)
- an array of any of the previous"
  :group 'lean-input
  :type 'file)

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

;;; TODO: error handling, anyone?
(defun lean-input--user-translations ()
  "Process `lean-input-user-translations' to quail rules."
  (cl-loop for (key . trans) in lean-input-user-translations
           collect (cons key (vconcat trans))))

(defun lean-input--translations ()
  "Process `lean-input-translations-file' to quail rules."
  (let ((ht (with-temp-buffer
              (insert-file-contents lean-input-translations-file)
              (if (fboundp 'json-parse-buffer)
                  (json-parse-buffer :object-type 'hash-table)
                (require 'json)
                (let ((json-object-type 'hash-table))
                  (json-read))))))
    (cl-loop for k being the hash-keys of ht
             using (hash-values v)
             when (characterp v)
             collect (list k v)
             when (and (stringp v) (length= v 1))
             collect (list k (string-to-char v))
             when (and (stringp v) (length> v 1))
             collect (list k (vector v))
             when (vectorp v)
             collect (list k v))))

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
;; (lean-input--define-rules (lean-input--translations))
(lean-input--define-rules (lean-input--parents))


;; Inspecting and modifying translation maps

;; Setting up the input method

;;; Do not use `provide' here, because we don't want this file loaded by
;;; the user (it would activate the input method).  Instead add this
;;; library as a prereq to the appropriate `register-input-method'.

;;; lean-input.el ends here
