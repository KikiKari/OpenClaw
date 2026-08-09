; OpenClaw Cluster Health Summary (Scheme, R7RS)
(import (scheme base) (scheme write))

(define statuses '(200 200 503 200))

(define (count-ok lst)
  (cond ((null? lst) 0)
        ((= (car lst) 200) (+ 1 (count-ok (cdr lst))))
        (else (count-ok (cdr lst)))))

(let loop ((lst statuses) (i 1))
  (when (pair? lst)
    (display "node ") (display i)
    (display " -> HTTP ") (display (car lst)) (newline)
    (loop (cdr lst) (+ i 1))))

(define ok (count-ok statuses))
(display "cluster availability: ")
(display (exact->inexact (/ (* 100 ok) (length statuses))))
(display " %")
(newline)
