Merge-fmt - git mergetool leveraging code formatters
====================================================

[![build](https://github.com/hhugo/merge-fmt/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/hhugo/merge-fmt/actions/workflows/build.yml?query=branch%3Amain)

WARNING: This tool is still experimental.

`merge-fmt` is a small wrapper on top git commands to help resolve conflicts by leveraging
code formatters.

`merge-fmt` currently only knows about the following formatters:
- [ocamlformat](https://github.com/ocaml-ppx/ocamlformat) for OCaml (`.ml` and `.mli` files).
- [refmt](https://github.com/facebook/reason) for Reason (`.re` and `.rei` files).
- [dune](https://github.com/ocaml/dune) for dune (`dune`, `dune-project` and `dune-workspace` files).

They are looked up in the `PATH`. Use `--ocamlformat`, `--refmt` and `--dune`
to run other ones.

Note that supporting new code formatters is trivial.

`merge-fmt` is tested on Linux, macOS and Windows.

Getting started
----------------
There are four ways to use merge-fmt.

### Standalone
Just call `merge-fmt` while there are unresolved conflicts. `merge-fmt` will try
resolve conflicts automatically.

It considers all the conflicted files of the repository, whatever the current
directory is. The files it resolves are added to the index with `git add`.
Files with conflicts left, and files without a formatter, are reported and
left for you to resolve.

`merge-fmt` exits with 0 when no conflict is left in the repository, and with
1 otherwise.

### As a Git mergetool
`merge-fmt` can act as a git [mergetool](https://git-scm.com/docs/git-mergetool).
`merge-fmt setup-mergetool` prints the commands that configure the current
git repository. Run them, or let merge-fmt do it with
`merge-fmt setup-mergetool --update`.
```
$ merge-fmt setup-mergetool
git config --local mergetool.mergefmt.cmd 'merge-fmt mergetool --base="$BASE" --current="$LOCAL" --other="$REMOTE" -o "$MERGED" --name="$MERGED"'
git config --local mergetool.mergefmt.trustExitCode true
```
Then, use `git mergetool` to resolve conflicts with
```
git mergetool -t mergefmt
```
This command changed in merge-fmt 0.5.1: run `merge-fmt setup-mergetool --update`
again in the repositories configured with an older version, where dune files
are not formatted.

### As a git merge driver
`merge-fmt` can act as a git [merge driver](https://git-scm.com/docs/gitattributes).
Configure the current git repository to use merge-fmt as the default merge driver
with `merge-fmt setup-merge --update`, or by running the commands it prints.
```
$ merge-fmt setup-merge
git config --local merge.mergefmt.name 'merge-fmt driver'
git config --local merge.mergefmt.driver 'merge-fmt mergetool --base=%O --current=%A --other=%B -o %A --name=%P'
git config --local merge.tool 'mergefmt'
git config --local merge.default 'mergefmt'
```

### As a Jujutsu merge tool
`merge-fmt` can act as a jujutsu [merge tool](https://docs.jj-vcs.dev/latest/config/#3-way-merge-tools-for-conflict-resolution).
This requires jj 0.33 or later.

`merge-fmt setup-jj-mergetool` prints the commands that configure the current
jj repository. Run them, or let merge-fmt do it with
`merge-fmt setup-jj-mergetool --update`.
```
$ merge-fmt setup-jj-mergetool
jj config set --repo merge-tools.merge-fmt.program '"merge-fmt"'
jj config set --repo merge-tools.merge-fmt.merge-args '["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path", "--diff3"]'
jj config set --repo merge-tools.merge-fmt.merge-conflict-exit-codes '[1]'
```

Then, use `jj resolve` to resolve conflicts with
```
jj resolve --tool merge-fmt
```
Conflicts that are still there once the files are formatted are left for you
to resolve.

### When a file cannot be formatted
As a merge tool or a merge driver, when the formatter fails on one of the
versions of a file, because of a syntax error for instance, `merge-fmt` says so
and merges the versions as they are. It exits with 0 when the merge succeeds,
and with 1 when the result has conflicts.

Install
-------
```sh
$ opam install merge-fmt
```
The development version can be installed with
```sh
$ opam pin add merge-fmt https://github.com/hhugo/merge-fmt.git
```
