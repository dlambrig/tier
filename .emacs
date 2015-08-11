  (setq c-default-style "linux"
          c-basic-offset 8)


(global-set-key (kbd "M-[ A") 'previous-line)
(global-set-key (kbd "M-[ B") 'next-line)
(global-set-key (kbd "M-[ C") 'forward-char)
(global-set-key (kbd "M-[ D") 'backward-char)
(global-set-key (kbd "M-n") 'scroll-up-line)
(global-set-key (kbd "M-p") 'scroll-down-line)
(global-set-key (kbd "C-x C-b") 'electric-buffer-list)
(global-set-key (kbd "M-g") 'goto-line)
(column-number-mode 1)
(setq-default indent-tabs-mode nil)


