;;; company-w32reg.el --- Company-backend for windows registry files.

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; Copyright (C) 2016, Noah Peart, all rights reserved.
;; Created: 15 July 2016
;; Package-Requires ((company "0.8.0") (cl-lib "0.5.0"))

;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;;  Company-mode backend for editing windows registry files (.reg).
;;  Provides company completion for keys between '[]'.

;; Usage:
;;
;; Add to a suitable location on the `load-path' and either require or autoload
;; `company-w32reg'.  Then add to company-backends where desired.
;;
;; See: [w32-registry-mode](http://github.com/nverno/w32-registry-mode)
;; for a major mode for registry files. 

;; Example:
;;
;; ![example pic](example.png)
;;

;; Todo:
;;
;; * Add better support for data types/values.
;; * Fix expansions of root abbreviations

;;; Code:

(require 'company)
(require 'cl-lib)

(defgroup company-w32reg nil
  "Company backend for editing windows registry files."
  :group 'convenience
  :prefix "company-w32reg-")

;; ------------------------------------------------------------
;;* variables
(defcustom company-w32reg-exe
  (or (executable-find "reg.exe")
      (expand-file-name "system32/reg.exe" (getenv "windir")))
  "Location of 'reg.exe' executable."
  :group 'company-w32reg
  :type 'string)

(defcustom company-w32reg-regex
  "\\([A-Za-z_0-9]+\\)\\s-*\\(REG_[A-Za-z]+\\)\\s-*\\([0-9a-zA-Z]+\\)"
  "Regex to match registry entries: (subkey, type, value)."
  :group 'company-w32reg
  :type 'regex)


(defcustom company-w32reg-modes
  '(w32-registry-mode conf-windows-mode)
  "Modes to activate `company-w32reg'."
  :group 'company-w32reg
  :type 'sexp)

;; ------------------------------------------------------------
;;* internal
(defvar company-w32reg-roots
  '(("HKLM" . "HKEY_LOCAL_MACHINE")
    ("HKCU" . "HKEY_CURRENT_USER")
    ("HKCR" . "HKEY_CLASSES_ROOT")
    ("HKU"  . "HKEY_USERS")
    ("HKCC" . "HKEY_CURRENT_CONFIG"))
  "Root keys, abbreviated or expanded.")

(defvar company-w32reg-roots-regex
  (concat "\\(?:^\\|[\\]\\)"
          (regexp-opt (mapcar 'car company-w32reg-roots) t)
          "\\(?:$\\|[\\]\\)"))

(defun company-w32reg-expand-root (key)
  "Expand abbreviated roots to match results."
  (if (string-match company-w32reg-roots-regex key)
      (replace-match (cdr (assoc (upcase (match-string-no-properties 1 key))
                                 company-w32reg-roots))
                     t t key 1)
    key))

(defun company-w32reg-in-key ()
  "Check if line starts with ?\[."
  (= (char-after (line-beginning-position)) ?\[))

(defun company-w32reg-grab-key ()
  "Get current key."
  (let ((end (point))
         (start (save-excursion
                  (goto-char (line-beginning-position))
                  (skip-chars-forward " [-" (line-end-position))
                  (point))))
    (company-w32reg-expand-root
     (buffer-substring-no-properties start end))))
    
(defun company-w32reg-split-key (key)
  "Split key into stem and leaf components, expand any abbreviated roots."
  (let ((parts (split-string key "\\\\")))
    (cons (mapconcat 'identity (butlast parts) "\\")
          (last parts))))

(defun company-w32reg-subkeys (stem leaf)
  "Get matching subkeys for split key."
  (let ((str (concat
              (regexp-quote (if (string= "" leaf)
                              stem
                            (concat stem "\\" leaf))) ".*"))
        (case-fold-search t)
        res)
    (with-temp-buffer
      (call-process company-w32reg-exe nil t nil "query" stem "/f" leaf "/k")
      (goto-char (point-min))
      (while (re-search-forward str nil t)
        (push (match-string-no-properties 0) res)))
    res))

(defun company-w32reg-candidates (arg)
  "Completion candidates for ARG."
  (let ((parts (company-w32reg-split-key arg))
        (case-fold-search t))
    (all-completions
     arg
     (if (string= "" (car parts))
         (append
          (mapcar 'cdr company-w32reg-roots)
          (mapcar 'car company-w32reg-roots))
       (company-w32reg-subkeys (car parts) (cadr parts))))))

(defun company-w32reg-prefix ()
  "Prefix to activate completion."
  (and (memq major-mode company-w32reg-modes)
       (company-w32reg-in-key)
       (company-w32reg-grab-key)))

(defun company-w32reg-doc (candidate)
  "Return company documentation buffer for CANDIDATE."
  (with-temp-buffer
    (call-process company-w32reg-exe nil t nil "query" candidate)
    (goto-char (point-min))
    (company-doc-buffer
     (buffer-substring-no-properties (line-beginning-position)
                                     (point-max)))))

;;;###autoload
(defun company-w32reg (command &optional arg &rest ignored)
  "Company backend for windows registry."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-w32reg))
    (prefix (company-w32reg-prefix))
    (candidates (company-w32reg-candidates arg))
    (doc-buffer (company-w32reg-doc arg))
    (ignore-case t)))

(provide 'company-w32reg)

;;; company-w32reg.el ends here
