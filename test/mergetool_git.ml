open! Base
open! Stdio
open! Common

let%expect_test "print the git mergetool configuration" =
  system "%s setup-mergetool" merge_fmt;
  [%expect
    {|
    git config --local mergetool.mergefmt.cmd 'merge-fmt mergetool --base="$BASE" --current="$LOCAL" --other="$REMOTE" -o "$MERGED" --name="$MERGED"'
    git config --local mergetool.mergefmt.trustExitCode true
    |}]

(* One side reformats the file and changes the libraries, the other one
   changes the name. *)
let conflict_on filename =
  let commit content msg =
    Out_channel.write_all filename ~data:content;
    system "git add -- %s" (Stdlib.Filename.quote filename);
    git_commit msg
  in
  let dune ~indent name libraries =
    String.concat ~sep:("\n" ^ indent)
      [ "(executable"
      ; Printf.sprintf "(name %s)" name
      ; "(modules a b c d e f g)"
      ; Printf.sprintf "(libraries %s))\n" libraries
      ]
  in
  commit (dune ~indent:"" "aaaa" "unix") "base";
  system "git checkout -q -b side";
  commit (dune ~indent:" " "aaaa" "unix str") "side";
  system "git checkout -q -";
  commit (dune ~indent:"" "bbbb" "unix") "main";
  system "git merge side >/dev/null 2>&1"

let mergetool () =
  system "%s setup-mergetool --merge-fmt-path %s --update" merge_fmt merge_fmt;
  system "git config mergetool.prompt false";
  system "git config mergetool.keepBackup false";
  system "git mergetool -t mergefmt >/dev/null 2>&1";
  system "git status --short"

let%expect_test "git mergetool on a dune file" =
  within_temp_dir (fun () ->
      git_init ();
      conflict_on "dune";
      mergetool ();
      print_file "dune";
      [%expect
        {|
        M  dune
        Exit with 1
        File dune
        (executable
         (name bbbb)
         (modules a b c d e f g)
         (libraries unix str))
        |}])

let%expect_test "git mergetool on a file in a directory with a space" =
  within_temp_dir (fun () ->
      git_init ();
      Unix.mkdir "my lib" 0o700;
      conflict_on "my lib/dune";
      mergetool ();
      print_file "my lib/dune";
      [%expect
        {|
        M  "my lib/dune"
        Exit with 1
        File my lib/dune
        (executable
         (name bbbb)
         (modules a b c d e f g)
         (libraries unix str))
        |}])

let%expect_test "refmt is asked to format in place" =
  within_temp_dir (fun () ->
      List.iter [ "base"; "current"; "other" ] ~f:(fun side ->
          Out_channel.write_all (side ^ ".re") ~data:"let x = 1;\n");
      Out_channel.write_all "result.re" ~data:"";
      system
        "%s mergetool --refmt=true --echo --base=base.re --current=current.re \
         --other=other.re -o result.re --name=result.re 2>&1 | grep true"
        merge_fmt;
      [%expect
        {|
        + true --in-place 'current.re'
        + true --in-place 'other.re'
        + true --in-place 'base.re'
        |}])
