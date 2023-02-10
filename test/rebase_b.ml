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
      system "git rebase branch2^ -q";
      print_status ();
      [%expect {|
        no changes |}];
      system "git rebase branch2 -q";
      [%expect
        {|
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply 6070a8f... second commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 6070a8f... second commit (fork)
        Exit with 1 |}];
      print_status ();
      [%expect
        {|
        UU File b.ml

        <<<<<<< HEAD
        type t = { a : int; b : string;
                   c : float; d : unit option }
        =======
        type t =
          { a : int option;
            b : string;
            c : float;
          }
        >>>>>>> 6070a8f (second commit (fork)) |}];
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
      [%expect
        {|
        [detached HEAD b70d467] second commit (fork)
         1 file changed, 6 insertions(+), 3 deletions(-) |}])
