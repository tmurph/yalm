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

;;; Internal variables and functions

(defvar lean-input--inhibit-make nil
  "For debugging.  If non-nil, loading the library will not automatically
create the input method.")

(defun lean-input--get-translations (qp)
  "Return all translations from the Quail package QP.
Result is a list of pairs (KEY-SEQUENCE . TRANSLATION) that contains all
translations from QP except for those corresponding to ASCII."
  (with-temp-buffer
    ;; ensure QP is loaded
    (activate-input-method qp)
    (unless (quail-package qp)
      (error "%s is not a Quail package" qp))
    (let ((decode-map (list 'decode-map)))
      (quail-build-decode-map (list (quail-map)) "" decode-map 0)
      (cdr decode-map))))

;;; TODO: error handling, anyone?
(defun lean-input--user-translations ()
  "Process `lean-input-user-translations' to quail rules."
  (cl-loop for (key . trans) in lean-input-user-translations
           collect (cons key (vconcat trans))))

(defun lean-input--lean-translations ()
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
             collect (cons k (vector v))
             when (vectorp v)
             collect (cons k v))))

(defun lean-input--tex-translations ()
  (let ((ignored-cmds '("\\geq" "\\leq" "\\bullet" "\\qed" "\\par")))
    (cl-loop for trans in (lean-input--get-translations "TeX")
             for key = (car trans)
             when (or (and (string-prefix-p "^" key)
                           (not (string= key "^o")))
                      (string-prefix-p "_" key)
                      (and (string-prefix-p "\\" key)
                           (not (member key ignored-cmds))))
             collect trans)))

(defun make-lean-input ()
  ;; do everything in a temp buffer so any auto-activation of the quail
  ;; package happens away from user activity
  (with-temp-buffer
    (let ((guidance t)
          (maximum-shortest t)
          (create-decode-map t))
      (quail-define-package
       "Lean" "UTF-8" "∏" guidance
       "Lean input method.
These characters are drawn largely from the TeX input method, with
modifications to better support editing Lean programs."
       nil nil nil nil nil create-decode-map maximum-shortest))

    ;; "Lean" is now the buffer-local active quail package
    ;; TODO: check for dupes?  any error handling?
    (let ((map (quail-map))
          (decode-map (quail-decode-map)))
      (cl-loop for (key . trans) in (lean-input--user-translations)
               do (quail-defrule-internal key trans map t decode-map))
      (cl-loop for (key . trans) in (lean-input--lean-translations)
               do (quail-defrule-internal key trans map t decode-map))
      (cl-loop for (key . trans) in (lean-input--tex-translations)
               do (quail-defrule-internal key trans map t decode-map)))))

(unless lean-input--inhibit-make
  (make-lean-input))

;;; TODO: Instead of including a provide, add this library as a prereq
;;; to an appropriate `register-input-method'.

;;; lean-input.el ends here
