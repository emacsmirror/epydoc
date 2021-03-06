;;; epydoc.el --- pydoc interface for emacs

;; Copyright (C) 2010  mooz

;; Author: mooz <stillpedant@gmail.com>
;; Keywords: python, anything, imenu

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Usage:

;;; Code:

(eval-when-compile
  (require 'cl))

(defvar epydoc--module-directories
  (list "/usr/lib/python2.6"
        "/usr/lib/pymodules/python2.6"))

(defun epydoc--get-all-modules ()
  (sort (loop for dir in epydoc--module-directories
              append (epydoc--get-modules dir))
        'string<))

(defun epydoc--get-modules (directory)
  (when (file-exists-p directory)
    (sort (loop for entry in (file-name-all-completions "" directory)
                if (and (string-match "\\(.*\\)\\(\\.py\\|/\\)$" entry)
                        (not (string-match-p "\\." (match-string-no-properties 1 entry))))
                collect (match-string-no-properties 1 entry))
          'string<)))

(defun epydoc--view-doc (&rest args)
  (when args
    ;; XXX: with-current-buffer
    (switch-to-buffer (get-buffer-create "*Pydoc*"))
    (setq buffer-read-only nil)
    (delete-region (point-min) (point-max))
    (apply 'call-process (append '("pydoc" nil t nil) args))
    (unless (eq major-mode 'view-mode)
      (view-mode 1))
    (epydoc--setup-imenu)
    (setq buffer-read-only t)
    (goto-char (point-min))))

;; ============================================================ ;;
;; font-lock support
;; ============================================================ ;;

(defface epydoc--header-face
  '((t
     (:foreground "dodger blue"
      :height 1.5
      :italic nil
      :bold t)))
  "Style of the header in the pydoc")

(defvar epydoc--header-regexp
  "^\\([A-Z][A-Z ]+\\)$")

(setq epydoc--font-lock-keywords
  `((,epydoc--header-regexp . font-lock-keyword-face)))

;; ============================================================ ;;
;; anything support
;; ============================================================ ;;

(defvar anything-c-source-python-modules
  '((name . "Python Modules")
    (candidates . (lambda () (epydoc--get-all-modules)))
    (action . (("Show document" . (lambda (doc) (epydoc--view-doc doc))))))
  "Source for completing Python modules.")

;; ============================================================ ;;
;; imenu support
;; ============================================================ ;;

(defvar epydoc--identifier-pattern
  "[a-zA-Z_][a-zA-Z_0-9]*")

(defvar epydoc--class-pattern
  (concat "^\s*class\s+\\(" epydoc--identifier-pattern "\\)"))

(defvar epydoc--method-pattern
  (concat "^\s*|  \\(" epydoc--identifier-pattern "\\)("))

(defun epydoc--imenu-create-class-index ()
  (cons "CLASSES"
        (let (index)
          (goto-char (point-min))
          (while (re-search-forward epydoc--class-pattern (point-max) t)
            (push (cons (match-string 1) (match-beginning 1)) index))
          (nreverse index))))

(defun epydoc--find-next-for (pattern)
  (let ((max (point-max)))
    (save-excursion
      (or (re-search-forward pattern max t)
          max))))

(defun epydoc--imenu-create-method-indices ()
  (let (next-class-pos
        class
        classes)
    (goto-char (point-min))
    (while (re-search-forward epydoc--class-pattern (point-max) t)
      ;; in the class
      (setq class (match-string 1))
      (setq next-class-pos (epydoc--find-next-for epydoc--class-pattern))
      (push (cons class
                  (let (index)
                    ;; seek for the class methods
                    (while (re-search-forward epydoc--method-pattern next-class-pos t)
                      (push (cons (match-string 1) (match-beginning 1)) index))
                    (nreverse index)))
            classes))
    (nreverse classes)))

(defun epydoc--imenu-create-header-index ()
  (cons "HEADER"
        (let (index)
          (goto-char (point-min))
          (while (re-search-forward epydoc--header-regexp (point-max) t)
            (push (cons (match-string 1) (match-beginning 1)) index))
          (nreverse index))))

(defun epydoc--imenu-create-index ()
  (append
   (list
    (epydoc--imenu-create-header-index)
    (epydoc--imenu-create-class-index))
   (epydoc--imenu-create-method-indices)))

(defun epydoc--setup-imenu ()
  (make-local-variable imenu-create-index-function)
  (setq imenu-create-index-function 'epydoc--imenu-create-index))

(defun epydoc--next-header (&optional previous)
  (if previous
      (progn
        (beginning-of-line)
        (re-search-backward epydoc--header-regexp (point-min) t))
    (end-of-line)
    (re-search-forward epydoc--header-regexp (point-max) t))
  (beginning-of-line)
  (recenter))

;; (define-key epydoc-mode-map (kbd "n")
;;   (lambda () (interactive) (epydoc--next-header)))
;; (define-key epydoc-mode-map (kbd "p")
;;   (lambda () (interactive) (epydoc--next-header t)))

;; ============================================================ ;;
;; commands
;; ============================================================ ;;

(defun epydoc-view-module-anything ()
  "View documentaion of python with anything"
  (interactive)
  (anything :sources anything-c-source-python-modules))

(provide 'epydoc)
;;; epydoc.el ends here
