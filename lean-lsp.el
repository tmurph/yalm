;;; lean-lsp.el --- LSP functionality for lean-mode  -*- lexical-binding: t; -*-

;; Copyright © 2026 Trevor Murphy

;; This is licensed under GNU General Public License (version 3 only),
;; see LICENSE.GPL3.  To be precise, it is licensed under Apache-2.0,
;; see LICENSE.APACHE2, and sublicensed under GPL3.

;;; Commentary:

;; This file defines generic methods and APIs for calling the Lean
;; server through an Elisp LSP backend.  The default backend is Eglot,
;; though lsp-mode is supported.

;;; Code:

(require 'eglot)
(require 'jsonrpc)

;;;; Lean LSP Extensions

(eval-and-compile
  (dolist (elt
           '((lean:PlainGoal (:goals) nil)
             (lean:PlainTermGoal (:goal) nil)
             (lean:Diagnostic
              (:range :fullRange :message)
              (:code :relatedInformation :severity :source :tags))))
    (add-to-list 'eglot--lsp-interface-alist elt t)))

;;;; Generic Method API

;;; To add more backend support, define an appropriate generic dispatch
;;; type and add its constructor to `lean-lsp--ensure-backend'.

(defvar lean-lsp--backend nil
  "LSP backend object for use by generic method dispatch.")

(cl-defstruct (lean-lsp--eglot
               (:constructor lean-lsp--create-eglot))
  "The default backend type for LSP method dispatch.")

(defun lean-lsp--ensure-backend ()
  (unless lean-lsp--backend
    (setq lean-lsp--backend
          (lean-lsp--create-eglot))))

(cl-defgeneric lean-lsp--request-async (backend method params success
                                                &key error-handler mode
                                                cancel-token)
  "Send an async LSP/Lean RPC via BACKEND (object).

METHOD is a symbol and PARAMS an appropriate plist or alist.
SUCCESS is a callback called with the result.
ERROR-HANDLER, MODE, CANCEL-TOKEN are backend-specific hints.")

(cl-defmethod lean-lsp--request-async ((_ lean-lsp--eglot)
                                       method params success
                                       &key error-handler)
  "Fallback method for Eglot LSP requests."
  (jsonrpc-async-request (eglot--current-server-or-lose)
                         method params
                         :success-fn success
                         :error-fn (or error-handler #'ignore)))

(cl-defmethod lean-lsp--request-async ((_ lean-lsp--eglot)
                                       (method (eql :$/lean/plainGoal))
                                       params success
                                       &key error-handler)
  "Request all goals from the server.  PARAMS should be a function of two
args (CALLBACK GOALS) that will process the goals (as an array of
strings) and call the ElDoc callback."
  (jsonrpc-async-request (eglot--current-server-or-lose)
                         method (eglot--TextDocumentPositionParams)
                         :success-fn (eglot--lambda ((lean:PlainGoal) goals)
                                       (funcall params success goals))
                         :error-fn (or error-handler #'ignore)))

(cl-defmethod lean-lsp--request-async ((_ lean-lsp--eglot)
                                       (method (eql :$/lean/plainTermGoal))
                                       params success
                                       &key error-handler)
  "Request the type of the term at point.  PARAMS should be a function of two
args (CALLBACK GOAL) that will process the \"goal\" (as a string) and
call the ElDoc callback."
  (jsonrpc-async-request (eglot--current-server-or-lose)
                         method (eglot--TextDocumentPositionParams)
                         :success-fn (eglot--lambda ((lean:PlainTermGoal) goal)
                                       (funcall params success goal))
                         :error-fn (or error-handler #'ignore)))

(provide 'lean-lsp)
;;; lean-lsp.el ends here
