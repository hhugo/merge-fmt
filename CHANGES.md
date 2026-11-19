## Unreleased

- Add `setup-jj-mergetool`, to use merge-fmt as a Jujutsu merge tool. (#15)
- `mergetool`: add `--diff3`, to show conflicts in diff3 style. (#15)
- `mergetool`: OCaml files are no longer formatted in place: the files given
  with `--current`, `--base` and `--other` are left untouched. (#15)
- `mergetool`: `--name` no longer needs to be the path of an existing file.
- `mergetool`: when no formatter is found, write the result to the output
  given with `-o` instead of modifying the current file in place.
- `mergetool`: when the merge has conflicts, write the result, with its
  conflict markers, to the output and exit with 1. When the merge fails,
  leave the output untouched.
- `mergetool`: a relative `--name` is now relative to the root of the
  repository (the closest parent directory containing `.git` or `.jj`), not
  to the current directory.

## 0.3 (2023-02-18)

- Add support of dune formatter. (#3)

## 0.2 (2019-02-19)

- Initial release.
