;;; flymake-zig.el --- flymake diagnostics for zig   -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Jürgen Hötzel

;; Author: Jürgen Hötzel <juergen@hoetzel.info>
;; Keywords: tools, languages
;; Package-Version: 20230817.173336
;; Package-Requires: ((emacs "26.1"))
;; Version: 1.0.0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; This package adds zig syntax checker to flymake.
;; 

;;; Code:

(defgroup flymake-zig nil "flymake-zig preferences." :group 'flymake-zig)

(defcustom flymake-zig-executable "zig"
  "The zig executable to use for syntax checking."
  :safe #'stringp
  :type 'string
  :group 'flymake-zig)


(defvar-local flymake-zig--id 0
  "A buffer-local variable storing a unique id for flymake to prevent duplicate reports.")

(defun flymake-zig-diagnostics (report-fn &rest _args)
  (let ((zig-exec (executable-find flymake-zig-executable))
	(process-connection-type nil)
	(source-buffer (current-buffer))
	(current-id (setq flymake-zig--id (1+ flymake-zig--id)))
	diagnostics)
    (unless zig-exec (error "%s not found on PATH" flymake-zig-executable))
    (if (buffer-modified-p (current-buffer))
	(funcall report-fn nil)
      (make-process
       :name "flymake-zig" :noquery t :connection-type 'pipe
       :buffer (generate-new-buffer " *flymake-zig*")
       :command `(,flymake-zig-executable "build")
       :sentinel (lambda (proc _event)
		   (when (eq 'exit (process-status proc))
		     (unwind-protect
			 (with-current-buffer (process-buffer proc)
			   (save-excursion
			     (goto-char (point-min))
			     (while (search-forward-regexp "^.+:\\([0-9]+\\):\\([0-9]+\\): \\(.+?\\): \\(.+\\)$" nil t)
			       (let* ((lnum (string-to-number (match-string 1)))
				      (col (string-to-number (match-string 2)))
				      (severity (match-string 3))
				      (msg (match-string 4))
				      (type (cond
					     ((string= severity "error") :error)
					     ((string= severity "warning") :warning)
					     (t :note))))
				 ;; FIXME: Check for current file name
				 (setq diagnostics
				       (nconc diagnostics (list (flymake-make-diagnostic (buffer-file-name source-buffer) `(,lnum . ,col) nil type msg))))))))))
		   (kill-buffer (process-buffer proc))
		   (when (= current-id flymake-zig--id)  ;don't sent obsolete reports
		     (funcall report-fn diagnostics)))))))

;;;###autoload
(defun flymake-zig-setup ()
  "Enable flymake backend."
  (interactive)
  (add-hook 'flymake-diagnostic-functions
	    #'flymake-zig-diagnostics nil t))

(provide 'flymake-zig)
;;; flymake-zig.el ends here
