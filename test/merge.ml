open! Base
open! Stdio
open! Common

(* Tests mergetool *)

let%expect_test "default merge tool" =
  within_temp_dir (fun () ->
      git_init ();

      (* system "%s setup-merge --merge-fmt-path %s --update" merge_fmt merge_fmt; *)
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
        error: could not apply 6499b96... second commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 6499b96... second commit (fork)
        Exit with 1 |}];
      print_file "b.ml";
      [%expect
        {|
          File b.ml

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
          >>>>>>> 6499b96 (second commit (fork)):a.ml |}])

let%expect_test "custom merge tool" =
  within_temp_dir (fun () ->
      git_init ();
      system "%s setup-merge --merge-fmt-path %s --update" merge_fmt merge_fmt;
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
      [%expect {| |}];
      print_file "b.ml";
      [%expect
        {|
          File b.ml
          type b = int

          type t =
            { a : int option
            ; b : string
            ; c : float
            ; d : unit option
            }

          type u =
            | A
            | B of int |}])
