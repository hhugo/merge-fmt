open! Base
open! Stdio
open! Common

(* Tests mergetool *)

let%expect_test _ =
  within_temp_dir (fun () ->
      git_init ();
      system "%s setup-mergetool --merge-fmt-path %s --update" merge_fmt
        merge_fmt;
      [%expect {||}];
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
         }
|};
      git_commit "first commit";
      git_branch "branch1";

      (* Add new field, move file *)
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
           d : unit option }
|};
      system "git mv a.ml b.ml";
      git_commit "second commit";

      (* Add new type *)
      write "b.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
           d : unit option }

type u = A | B of int
|};
      git_commit "third commit";
      git_branch "branch2";

      (* Go back to branch1, turn [a] to [int option], reformat *)
      git_checkout "branch1";
      write "a.ml"
        {|
type t =
  { a : int option
  ; b : string
  ; c : float
  }
|};
      git_commit "second commit (fork)";
      [%expect {| Switched to branch 'branch1' |}];

      (* add new type before *)
      write "a.ml"
        {|
type b = int


type t =
  { a : int option
  ; b : string
  ; c : float
  }
|};
      git_commit "third commit (fork)";
      git_branch "old_branch1";
      system "git rebase branch2 -q";
      [%expect
        {|
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply 12ef546... second commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 12ef546... second commit (fork)
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
          UU File b.ml

          <<<<<<< HEAD:b.ml
          type t = { a : int;
                     b : string;
                     c : float;
                     d : unit option }

          type u = A | B of int
          =======
          type t =
            { a : int option
            ; b : string
            ; c : float
            }
          >>>>>>> 12ef546 (second commit (fork)):a.ml |}];
      system "git mergetool --tool mergefmt -y";
      system "git clean -f";
      [%expect
        {|
        Merging:
        b.ml

        Normal merge conflict for 'b.ml':
          {local}: modified file
          {remote}: modified file
        Removing b.ml.orig |}];
      print_status ();
      [%expect
        {|
          M File b.ml
          type t =
            { a : int option
            ; b : string
            ; c : float
            ; d : unit option
            }

          type u =
            | A
            | B of int |}];
      system "git rebase --continue";
      [%expect
        {|
        [detached HEAD 38f05c7] second commit (fork)
         1 file changed, 9 insertions(+), 6 deletions(-)
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply 7e70a06... third commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 7e70a06... third commit (fork)
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
        UU File b.ml
        <<<<<<< HEAD:b.ml
        =======

        type b = int


        >>>>>>> 7e70a06 (third commit (fork)):a.ml
        type t =
          { a : int option
          ; b : string
          ; c : float
          ; d : unit option
          }

        type u =
          | A
          | B of int |}];
      system "git mergetool --tool mergefmt -y";
      system "git clean -f";
      [%expect
        {|
        Merging:
        b.ml

        Normal merge conflict for 'b.ml':
          {local}: modified file
          {remote}: modified file
        Removing b.ml.orig |}];
      print_status ();
      [%expect
        {|
        M File b.ml
        type b = int

        type t =
          { a : int option
          ; b : string
          ; c : float
          ; d : unit option
          }

        type u =
          | A
          | B of int |}];
      system "git rebase --continue";
      [%expect {|
        [detached HEAD d0f3d71] third commit (fork)
         1 file changed, 2 insertions(+) |}])
