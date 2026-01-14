;;; lean-input-test.el --- Unit tests for lean-input -*- lexical-binding: t -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

(load "lean-input")

(require 'ert-x)
(require 'buttercup)

(describe "`lean-input--user-translations'"

  (it "handles the expected format"
    (let ((lean-input-user-translations
           '(("key" "trans1" "trans2" "trans3"))))
      (expect (lean-input--user-translations) :to-equal
              '(("key" . ["trans1" "trans2" "trans3"]))))))

(defmacro describe-with-two-jsons (description &rest body)
  (declare (indent defun))
  `(describe ,description
     (describe "with `json-parse-buffer'"
       (assume (fboundp 'json-parse-buffer) "`json-parse-buffer' unavailable ... skipping")
       ,@body)
     (describe "with `json-read'"
       (before-each (spy-on 'fboundp :and-return-value nil))
       ,@body)))

(describe-with-two-jsons "`lean-input--lean-translations'"

  (it "handles the expected format"
    (let ((lean-input-translations-file (ert-resource-file "basic.json")))
      (expect (lean-input--lean-translations) :to-equal
              '(("number" . ?α)
                ("char-string" . ?β)
                ("string" . ["trans"])
                ("array" . ["trans" "rights"])))))

  (it "prefixes common language keys"
    (let ((lean-input-translations-file (ert-resource-file "wants-prefix.json")))
      (expect (lean-input--lean-translations) :to-equal
              '(("\\a" . ?α)
                ("\\1" . ?₁)
                ("\\em" . ?—)
                ("\\le" . ?≤))))))

(describe "`lean-input--tex-translations'"

  (it "returns the expected format"
    (let* ((trans (lean-input--tex-translations))
           (candidate "\\pounds"))
      (expect (assoc candidate trans) :to-equal '("\\pounds" . ?£)))))

(provide 'lean-input-test)
;;; lean-input-test.el ends here
