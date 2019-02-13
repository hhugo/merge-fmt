Merge-fmt - git mergetool leveraging code formatters
====================================================

WARNING: This tool is still experimental.

`merge-fmt` is a small wrapper on top git commands to help resolve conflicts by leveraging
code formatters.

`merge-fmt` currently only knows about the following formatters:
- [ocamlformat](https://github.com/ocaml-ppx/ocamlformat) for OCaml.
- [refmt](https://github.com/facebook/reason) for reason.

Note that supporting new code formatters is trivial.

Getting starting
----------------
There are two ways to use merge-fmt.

### Standalone
Just call `merge-fmt` while there are unresolved conflicts. `merge-fmt` will try
resolve conflicts automatically.

### As a Git mergetool
`merge-fmt` can act as a git [mergetool](https://git-scm.com/docs/git-mergetool).
First configure the current git repository with
```merge-fmt mergetool-setup --update```
Then, use `git mergetool` to resolve conflicts with
```git mergetool -t mergefmt```


Install
-------
```sh
$ opam pin add merge-fmt git@github.com:hhugo/merge-fmt.git
```