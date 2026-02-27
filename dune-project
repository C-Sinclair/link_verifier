(lang dune 3.0)

(name link_verifier)

(generate_opam_files true)

(source
 (github C-Sinclair/link_verifier))

(license MIT)

(package
 (name link_verifier)
 (synopsis "CLI tool to verify markdown-style local links")
 (depends
  (ocaml
   (>= 5.0))
  (cmdliner
   (>= 2.1.0))
  (re
   (>= 1.10.0))
  (alcotest
   (and
    :with-test
    (>= 1.0.0)))))
