open! Base
open! Stdio
open! Common

let%expect_test _ =
  within_temp_dir (fun () ->
      git_init ();
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float }
|};
      git_commit "first commit";
      git_branch "branch1";
      system "git mv a.ml b.ml";
      git_commit "move a to b";
      write "b.ml"
        {|
type t = { a : int; b : string;
           c : float; d : unit option }
|};
      git_commit "second commit";
      git_branch "branch2";
      git_checkout "branch1";
      write "a.ml"
        {|
type t =
  { a : int option;
    b : string;
    c : float;
  }
|};
      git_commit "second commit (fork)";
      git_branch "old_branch1";
      [%expect {| Switched to branch 'branch1' |}];
      system "git rebase branch2 -q";
      [%expect
        {|
        CONFLICT (modify/delete): a.ml deleted in HEAD and modified in 5f62452 (second commit (fork)).  Version 5f62452 (second commit (fork)) of a.ml left in tree.
        error: could not apply 5f62452... second commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 5f62452... second commit (fork)
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
        DU File a.ml

        type t =
          { a : int option;
            b : string;
            c : float;
          } |}];
      resolve ();
      [%expect
        {|
        Ignore a.ml (not a 3-way merge)
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
        DU File a.ml

        type t =
          { a : int option;
            b : string;
            c : float;
          } |}];
      system "git rebase --continue";
      [%expect
        {|
        a.ml: needs merge
        You must edit all merge conflicts and then
        mark them as resolved using git add
        Exit with 1 |}])
