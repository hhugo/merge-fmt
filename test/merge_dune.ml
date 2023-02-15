open! Base
open! Stdio
open! Common

let%expect_test "default merge tool" =
  within_temp_dir (fun () ->
      git_init ();

      write "dune" {|
(executable
(name aaaa)
(libraries unix))
|};
      git_commit "first commit";
      git_branch "branch1";

      (* add public name *)
      if false
      then (
        write "dune"
          {|
(executable
(name aaaa)
(libraries unix)
(public_name pppp))
|};
        git_commit "second commit");

      (* add library *)
      write "dune"
        {|
(executable
(name aaaa)
(libraries unix))

(library
(name liblib))
|};
      git_commit "third commit";
      git_branch "branch2";

      git_checkout "branch1";
      [%expect {| Switched to branch 'branch1' |}];
      (* change name to b, reformat *)
      write "dune" {|
(executable
 (name bbbb)
 (libraries unix))
|};
      git_commit "second commit (fork)";

      write "dune"
        {|
(alias
 (name runtest)
 (action
  (diff rebase.diff rebase.diff.gen)))

(executable
 (name bbbb)
 (libraries unix))
|};

      git_commit "third commit (fork)";
      git_branch "old_branch1";
      system "git rebase branch2 -q";
      [%expect
        {|
        Auto-merging dune
        CONFLICT (content): Merge conflict in dune
        error: could not apply 2e00bc1... second commit (fork)
        hint: Resolve all conflicts manually, mark them as resolved with
        hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
        hint: You can instead skip this commit: run "git rebase --skip".
        hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
        Could not apply 2e00bc1... second commit (fork)
        Exit with 1 |}];
      print_file "dune";
      [%expect
        {|
        File dune

        (executable
        <<<<<<< HEAD
        (name aaaa)
        (libraries unix))

        (library
        (name liblib))
        =======
         (name bbbb)
         (libraries unix))
        >>>>>>> 2e00bc1 (second commit (fork)) |}])

let%expect_test "custom merge tool" =
  within_temp_dir (fun () ->
      git_init ();
      system "%s setup-merge --merge-fmt-path %s --update" merge_fmt merge_fmt;
      [%expect {||}];

      write "dune" {|
(executable
(name aaaa)
(libraries unix))
|};
      git_commit "first commit";
      git_branch "branch1";

      (* add public name *)
      if false
      then (
        write "dune"
          {|
(executable
(name aaaa)
(libraries unix)
(public_name pppp))
|};
        git_commit "second commit");

      (* add library *)
      write "dune"
        {|
(executable
(name aaaa)
(libraries unix))

(library
(name liblib))
|};
      git_commit "third commit";
      git_branch "branch2";

      git_checkout "branch1";
      [%expect {| Switched to branch 'branch1' |}];
      (* change name to b, reformat *)
      write "dune" {|
(executable
 (name bbbb)
 (libraries unix))
|};
      git_commit "second commit (fork)";

      write "dune"
        {|
(alias
 (name runtest)
 (action
  (diff rebase.diff rebase.diff.gen)))

(executable
 (name bbbb)
 (libraries unix))
|};
      git_commit "third commit (fork)";
      git_branch "old_branch1";

      system "git rebase branch2 -q";
      [%expect
        {| |}];
      system "%s" merge_fmt;
      print_file "dune";
      [%expect
        {|
        Nothing to resolve
        Exit with 1
        File dune
        (alias
         (name runtest)
         (action
          (diff rebase.diff rebase.diff.gen)))

        (executable
         (name bbbb)
         (libraries unix))

        (library
         (name liblib)) |}])
