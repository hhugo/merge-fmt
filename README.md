Merge-fmt - git mergetool leveraging code formatters
====================================================

WARNING: This tool is still experimental.

`merge-fmt` is a small wrapper on top git commands to help resolve conflicts by leveraging
code formatters.

`merge-fmt` currently only knows about the following formatters:
- [ocamlformat](https://github.com/ocaml-ppx/ocamlformat) for OCaml.
- [refmt](https://github.com/facebook/reason) for reason.
- [dune](https://github.com/ocaml/dune) for dune.

Note that supporting new code formatters is trivial.

Getting started
----------------
There are four ways to use merge-fmt.

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

### As a Jujutsu merge tool
`merge-fmt` can act as a jujutsu [merge tool](https://docs.jj-vcs.dev/latest/config/#3-way-merge-tools-for-conflict-resolution).
Configure the current jj repository with
```
merge-fmt setup-jj-mergetool
jj config set --repo merge-tools.merge-fmt.program '"merge-fmt"'
jj config set --repo merge-tools.merge-fmt.merge-args '["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path", "--diff3"]'
jj config set --repo merge-tools.merge-fmt.merge-conflict-exit-codes '[1]'
```

Then, use `jj resolve` to resolve conflicts with
```
jj resolve --tool merge-fmt
```

Install
-------
```sh
$ opam pin add merge-fmt git@github.com:hhugo/merge-fmt.git
```
