## Unreleased

- Fix the handling of file names when resolving conflicts: names containing
  spaces made `merge-fmt` fail, and shell special characters in names were
  interpreted by the shell.
- The versions of a file being merged are no longer written next to it
  (`a.ours.ml`, `a.theirs.ml`, `a.common.ml`), where they were left behind
  when some conflicts remained.

## 0.5 (2026-11-19)

- Add `setup-jj-mergetool`, to use merge-fmt as a Jujutsu merge tool. (#15)
- `mergetool`: add `--diff3`, to show conflicts in diff3 style. (#15)
- `mergetool`: OCaml files are no longer formatted in place: the files given
  with `--current`, `--base` and `--other` are left untouched. (#15)
- `mergetool`: when the merge has conflicts, write the result, with its
  conflict markers, to the output and exit with 1. When the merge fails,
  leave the output untouched. (#26)
- `mergetool`: when no formatter is found, write the result to the output
  given with `-o` instead of modifying the current file in place. (#24)
- `mergetool`: a relative `--name` is now relative to the root of the
  repository (the closest parent directory containing `.git` or `.jj`), not
  to the current directory. (#27)
- `mergetool`: `--name` no longer needs to be the path of an existing file.
  (#23)
- Recognize dune files in nested directories. (#21)
- Require dune 3.15. (#15)
- Tests: use `ppx_devtools-expect` instead of `ppx_expect` and drop the
  dependency on `core_unix`. (#19, #20)

## 0.4 (2025-06-02)

- Update to the latest cmdliner.
- Modernize the codebase. (#8, #9)

## 0.3 (2023-02-18)

- Add support of dune formatter. (#3)

## 0.2 (2019-02-19)

- Initial release.
