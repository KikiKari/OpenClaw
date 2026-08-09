#lang racket/base
;; OpenClaw Gateway Client (Racket)
(require net/url racket/string)

(define (check-health base-url)
  (with-handlers ([exn:fail? (lambda (_) "FAIL")])
    (define u (string->url (string-append base-url "/health")))
    (define port (get-impure-port u))
    (define status-line (read-line port))
    (close-input-port port)
    (string-trim status-line)))

(define args (current-command-line-arguments))
(define url (if (> (vector-length args) 0)
                (vector-ref args 0)
                "http://localhost:8080"))
(printf "Gateway ~a -> ~a\n" url (check-health url))
