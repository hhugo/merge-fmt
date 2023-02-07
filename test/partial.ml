open! Base
open! Stdio
open! Common

(* Tests partial resolution *)

let%expect_test _ =
  within_temp_dir (fun () ->
      git_init ();
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
         }
|};
      git_commit "first";
      git_branch "branch1";
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
           d : unit option }

let y = 0

(** doc *)xs
let x = 1
|};
      system "git mv a.ml b.ml";
      git_commit "second";
      write "b.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
           d : unit option }

let y = 0

(** doc *)
let x = 1
|};
      git_commit "third";
      git_branch "branch2";
      git_checkout "branch1";
      write "a.ml"
        {|
type t =
  { a : int option
  ; b : string
  ; c : float
  }

let y = 0

(** doc *)
let x = 5
|};
      git_commit "second prime";
      git_branch "old_branch1";
      [%expect {| Switched to branch 'branch1' |}];
      system "git rebase branch2 -q";
      [%expect
        {|
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply 48173d8... second prime
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 48173d8... second prime
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
        =======
        type t =
          { a : int option
          ; b : string
          ; c : float
          }
        >>>>>>> 48173d8 (second prime):a.ml

        let y = 0

        (** doc *)
        <<<<<<< HEAD:b.ml
        let x = 1
        =======
        let x = 5
        >>>>>>> 48173d8 (second prime):a.ml |}];
      resolve ();
      print_status ();
      [%expect
        {|
        Resolved 1/2 b.ml
        Exit with 1
        UU File b.ml
        type t =
          { a : int option
          ; b : string
          ; c : float
          ; d : unit option
          }

        let y = 0

        (** doc *)
        <<<<<<< b.ours.ml
        let x = 1
        =======
        let x = 5
        >>>>>>> b.theirs.ml

        ?? File b.common.ml
        type t =
          { a : int
          ; b : string
          ; c : float
          }

        ?? File b.ours.ml
        type t =
          { a : int
          ; b : string
          ; c : float
          ; d : unit option
          }

        let y = 0

        (** doc *)
        let x = 1

        ?? File b.theirs.ml
        type t =
          { a : int option
          ; b : string
          ; c : float
          }

        let y = 0

        (** doc *)
        let x = 5 |}];
      system "git merge-file -p b.ours.ml b.common.ml b.theirs.ml --ours";
      [%expect
        {|
        type t =
          { a : int option
          ; b : string
          ; c : float
          ; d : unit option
          }

        let y = 0

        (** doc *)
        let x = 1 |}];
      system "git add b.ml";
      [%expect {||}];
      system "git rebase --continue";
      [%expect {|
        [detached HEAD 730f3dc] second prime
         1 file changed, 10 insertions(+), 5 deletions(-) |}])
