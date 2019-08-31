Merge-fmt - git mergetool leveraging code formatters
====================================================

WARNING: This tool is still experimental.

`merge-fmt` is a small wrapper on top git commands to help resolve conflicts by leveraging
code formatters.

`merge-fmt` currently only knows about the following formatters:
- [ocamlformat](https://github.com/ocaml-ppx/ocamlformat) for OCaml.
- [refmt](https://github.com/facebook/reason) for reason.

Note that supporting new code formatters is trivial.

Getting started
----------------
There are three ways to use merge-fmt.

### Standalone
Just call `merge-fmt` while there are unresolved conflicts. `merge-fmt` will try
resolve conflicts automatically.

### As a Git mergetool
`merge-fmt` can act as a git [mergetool](https://git-scm.com/docs/git-mergetool).
First configure the current git repository with
```
merge-fmt setup-mergetool
git config --local mergetool.mergefmt.cmd 'merge-fmt mergetool --base=$BASE --current=$LOCAL --other=$REMOTE -o $MERGED'
git config --local mergetool.mergefmt.trustExitCode true
```
Then, use `git mergetool` to resolve conflicts with
```git mergetool -t mergefmt```

### As a git merge driver
`merge-fmt` can act as a git [merge driver](https://git-scm.com/docs/gitattributes).
Configure the current git repository to use merge-fmt as the default merge driver.
```
$ merge-fmt setup-merge
git config --local merge.mergefmt.name 'merge-fmt driver'
git config --local merge.mergefmt.driver 'merge-fmt mergetool --base=%O --current=%A --other=%B -o %A --name=%P'
git config --local merge.tool 'mergefmt'
git config --local merge.default 'mergefmt'
```


Install
-------
```sh
$ opam pin add merge-fmt git@github.com:hhugo/merge-fmt.git
```