open! Base
open! Stdio
open! Common

let commit filename content msg =
  Out_channel.write_all filename ~data:content;
  system "git add -- %s" (Stdlib.Filename.quote filename);
  git_commit msg

let middle = "let a = 0\nlet b = 0\nlet c = 0\n"

(* A conflict on [filename] that goes away once the files are formatted, in
   the middle of a merge. *)
let conflict_on filename =
  commit filename ("let x=1\n" ^ middle ^ "let y=2\n") "base";
  system "git checkout -q -b side";
  commit filename ("let x = 1\n" ^ middle ^ "let y = 22\n") "side";
  system "git checkout -q -";
  commit filename ("let x=3\n" ^ middle ^ "let y=2\n") "main"

let merge () = system "git merge side >%s 2>&1" Stdlib.Filename.null

let%expect_test "file name with a space" =
  within_temp_dir (fun () ->
      git_init ();
      conflict_on "my file.ml";
      merge ();
      [%expect {| Exit with 1 |}];
      resolve ();
      system "git status --short";
      print_file "my file.ml";
      [%expect
        {|
        Resolved 1/1 my file.ml
        M  "my file.ml"
        File my file.ml
        let x = 3
        let a = 0
        let b = 0
        let c = 0
        let y = 22
        |}])

let%expect_test "another conflicted file has a space in its name" =
  within_temp_dir (fun () ->
      git_init ();
      commit "read me.txt" "a\n" "text";
      conflict_on "a.ml";
      system "git checkout -q side";
      commit "read me.txt" "b\n" "side, text";
      system "git checkout -q -";
      commit "read me.txt" "c\n" "main, text";
      merge ();
      [%expect {| Exit with 1 |}];
      resolve ();
      system "git status --short";
      [%expect
        {|
        Resolved 1/1 a.ml
        Ignore read me.txt (no formatter register)
        M  a.ml
        UU "read me.txt"
        Exit with 1
        |}])

let%expect_test "shell special characters in a file name" =
  within_temp_dir (fun () ->
      git_init ();
      conflict_on "a$(touch PWNED)`touch PWNED`;touch PWNED;.ml";
      merge ();
      [%expect {| Exit with 1 |}];
      resolve ();
      system "git status --short";
      list_files ();
      [%expect
        {|
        Resolved 1/1 a$(touch PWNED)`touch PWNED`;touch PWNED;.ml
        M  "a$(touch PWNED)`touch PWNED`;touch PWNED;.ml"
        a$(touch PWNED)`touch PWNED`;touch PWNED;.ml
        bin
        |}])

let%expect_test "no file is left behind when conflicts remain" =
  within_temp_dir (fun () ->
      git_init ();
      conflict_on "a.ml";
      system "git checkout -q side";
      commit "a.ml" ("let x = 9\n" ^ middle ^ "let y = 22\n") "side, conflict";
      system "git checkout -q -";
      merge ();
      [%expect {| Exit with 1 |}];
      resolve ();
      system "git status --short";
      print_file "a.ml";
      [%expect
        {|
        Resolved 0/1 a.ml
        UU a.ml
        Exit with 1
        File a.ml
        <<<<<<< a.ours.ml
        let x = 3
        =======
        let x = 9
        >>>>>>> a.theirs.ml
        let a = 0
        let b = 0
        let c = 0
        let y = 22
        |}])

let%expect_test "a conflicted file missing from the working tree is ignored" =
  within_temp_dir (fun () ->
      git_init ();
      let commit x y msg =
        List.iter [ "a.ml"; "b.ml" ] ~f:(fun filename ->
            Out_channel.write_all filename ~data:(x ^ middle ^ y));
        system "git add a.ml b.ml";
        git_commit msg
      in
      commit "let x=1\n" "let y=2\n" "base";
      system "git checkout -q -b side";
      commit "let x = 1\n" "let y = 22\n" "side";
      system "git checkout -q -";
      commit "let x=3\n" "let y=2\n" "main";
      merge ();
      [%expect {| Exit with 1 |}];
      Unix.unlink "a.ml";
      resolve ();
      system "git status --short";
      [%expect
        {|
               Ignore a.ml (missing from the working tree)
               Resolved 1/1 b.ml
               UU a.ml
               M  b.ml
               Exit with 1
               |}])

(* From a subdirectory, the conflicts of the whole repository are resolved. *)
let%expect_test "resolve from a subdirectory" =
  within_temp_dir (fun () ->
      git_init ();
      Unix.mkdir "sub" 0o700;
      Unix.mkdir "other" 0o700;
      let files = [ "sub/a.ml"; "other/b.ml" ] in
      let commit x y msg =
        List.iter files ~f:(fun filename ->
            Out_channel.write_all filename ~data:(x ^ middle ^ y));
        system "git add sub other";
        git_commit msg
      in
      commit "let x=1\n" "let y=2\n" "base";
      system "git checkout -q -b side";
      commit "let x = 1\n" "let y = 22\n" "side";
      system "git checkout -q -";
      commit "let x=3\n" "let y=2\n" "main";
      merge ();
      [%expect {| Exit with 1 |}];
      Unix.chdir "sub";
      resolve ();
      system "git status --short";
      [%expect
        {|
               Resolved 1/1 ../other/b.ml
               Resolved 1/1 a.ml
               M  ../other/b.ml
               M  a.ml
               |}])
