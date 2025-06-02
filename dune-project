(lang dune 3.0)

(name merge-fmt)

(generate_opam_files true)

(authors "Hugo Heuzard")

(maintainers "hugo.heuzard@gmail.com")

(homepage "https://github.com/hhugo/merge-fmt")

(documentation "https://hhugo.github.io/merge-fmt/")

(license "MIT")

(package
 (name merge-fmt)
 (synopsis "Git mergetool leveraging code formatters")
 (description
  "`merge-fmt` is a small wrapper on top git commands to help resolve conflicts by leveraging code formatters.")
 (depends
  (ocaml
   (>= 4.8))
  (cmdliner
   (>= 1.1.0))
  base
  stdio
  (ppx_expect :with-test)
  (core_unix :with-test)
  (ocamlformat
   (and
    (= 0.27.0)
    :with-test))))
