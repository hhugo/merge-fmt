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
           c : float;
         }
|};
      git_commit "first commit";
      git_branch "branch1";
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
           d : unit option
         }
|};
      system "git mv a.ml b.ml";
      git_commit "second commit";
      git_branch "branch2";
      [%expect {||}];
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
      (* FIXME: we use the --apply backend explicitly. We should fix
         the test to use the merge backend *)
      system "git rebase branch2 -q --apply";
      [%expect
        {|
        error: Failed to merge in the changes.
        hint: Use 'git am --show-current-patch=diff' to see the failed patch
        Patch failed at 0001 second commit (fork)
        Resolve all conflicts manually, mark them as resolved with
        "git add/rm <conflicted_files>", then run "git rebase --continue".
        You can instead skip this commit: run "git rebase --skip".
        To abort and get back to the state before "git rebase", run "git rebase --abort".
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
        UU File b.ml

        <<<<<<< HEAD:b.ml
        type t = { a : int;
                   b : string;
                   c : float;
                   d : unit option
                 }
        =======
        type t =
          { a : int option;
            b : string;
            c : float;
          }
        >>>>>>> second commit (fork):a.ml |}];
      resolve ();
      [%expect {| Resolved 1/1 b.ml |}];
      print_status ();
      [%expect
        {|
        M File b.ml
        type t =
          { a : int option
          ; b : string
          ; c : float
          ; d : unit option
          } |}];
      system "git rebase --continue";
      [%expect {| Applying: second commit (fork) |}])
