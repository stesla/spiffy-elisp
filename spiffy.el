(provide 'spiffy)

(defun spiffy-cwd ()
  ; pwd returns "Directory /where/you/are/"; this gets rid of the baloney
  (substring (pwd) 10))

(defmacro spiffy-run-in-directory (dir &rest body)
  "Execute code in a particular current working directory"
  (let ((retval-var (make-symbol "retval"))
        (original-dir-var (make-symbol "original-dir")))
    `(let ((,original-dir-var (spiffy-cwd)))
       (cd ,dir)
       (setq ,retval-var (funcall (lambda () ,@body)))
       (cd ,original-dir-var)
       ,retval-var)))

(defun spiffy-spec-binary-to-run-for (filename)
  (let ((merb-root (spiffy-merb-root-for filename)))
    (if merb-root
        (concat (file-name-as-directory merb-root) "bin/spec")
      "spec")))    ; whatever the system's spec binary is

(defun spiffy-make-shell-command (&rest parts)
  (mapconcat
   (lambda (str)
     (if (string-match "[\t ]" str)
         (concat "\"" str "\"")
       str))
   parts
   " "))

(defun spiffy-parent-directory (filename)
  (file-name-as-directory (expand-file-name (concat(file-name-as-directory filename) ".."))))

(defun spiffy-is-merb-root (dir)
  (file-exists-p (concat (file-name-as-directory dir) "bin/merb")))

(defun spiffy-merb-root-for (filename)
  (let ((as-dir (file-name-as-directory filename)))
    (if (string= (file-truename as-dir) (file-truename (spiffy-parent-directory as-dir)))
        nil    ; base case
      (if (spiffy-is-merb-root as-dir)
          as-dir
        (spiffy-merb-root-for (spiffy-parent-directory filename))))))

; holy fucking crap
; it's 2009
; where is my tail-call optimization?
(defun filter (predicate l)
  (let ((result '()))
    (while (not (null l))
      (if (funcall predicate (car l))
          (setq result (append result (list (car l)))))
      (setq l (cdr l)))
    result))

; have to rewrite this iteratively too
; and then load it into the computer by toggling switches on its front panel
(defun flatten (l)
  (cond
   ((atom l) l)
   ((listp (car l)) (append (flatten (car l)) (flatten (cdr l))))
   (t (append (list (car l)) (flatten (cdr l))))))

(defun spiffy-useful-directory-files (directory)
  (filter
   (lambda (filename) (and (not (string= filename ".")) (not (string= filename ".."))))
   (directory-files directory)))

(defun spiffy-find-interesting-files (interesting-p directory)
  (filter interesting-p (spiffy-find-all-files directory)))

; all files, including directories (notably, empty directories)
(defun spiffy-find-all-files (directory)
  (if (not (file-directory-p directory))
      (list directory)  ; base case: it's just a file
    (let ((files (list directory)))
      ; XXX there's a reduce function in cl-extra... use it instead of mapcar+setq
      (mapcar (lambda (subdir-files) (setq files (append files subdir-files)))
              (mapcar 'spiffy-find-all-files
                      (mapcar (lambda (filename) (concat (file-name-as-directory directory) filename))
                              (spiffy-useful-directory-files directory))))
      files)))

; just files
(defun spiffy-find-files (directory)
  (filter 'file-regular-p (spiffy-find-all-files directory)))

(defun spiffy-is-project-root (directory)
  (file-exists-p (concat (file-name-as-directory directory) ".git")))

; XXX refactor with spiffy-merb-root-dir-for
(defun spiffy-project-root-for (filename)
  (let ((as-dir (file-name-as-directory filename)))
    (if (string= (file-truename as-dir) (file-truename (spiffy-parent-directory as-dir)))
        nil    ; base case
      (if (spiffy-is-project-root as-dir)
          as-dir
        (spiffy-project-root-for (spiffy-parent-directory filename))))))

(defun spiffy-command-t-files-for (file)
  (filter
   (lambda (f) (not (string-match ".git/" f)))
   (spiffy-find-files (spiffy-project-root-for file))))

; XXX test me
(defun spiffy-run-spec-under-point ()
  (interactive)
  (save-buffer)
  (spiffy-run-in-directory
   (spiffy-merb-root-for (buffer-file-name))
   (compile
    (spiffy-make-shell-command
     (spiffy-spec-binary-to-run-for (buffer-file-name))
     "-l"
     (format "%d" (line-number-at-pos)) ; defaults to line number at point
     (buffer-file-name)))))

; XXX test + refactor with spiffy-run-spec-under-point
(defun spiffy-run-spec-file ()
  (interactive)
  (save-buffer)
  (spiffy-run-in-directory
   (spiffy-merb-root-for (buffer-file-name))
   (compile
    (spiffy-make-shell-command
     (spiffy-spec-binary-to-run-for (buffer-file-name))
     (buffer-file-name)))))
