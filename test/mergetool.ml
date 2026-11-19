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
      filter_hint [%expect.output];
      [%expect
        {|
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply 6499b96... second commit (fork)
        Could not apply 6499b96... second commit (fork)
        Exit with 1
        |}];
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
          >>>>>>> 6499b96 (second commit (fork)):a.ml |}];
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
      filter_hint [%expect.output];
      [%expect
        {|
        [detached HEAD 3fd12a7] second commit (fork)
         1 file changed, 9 insertions(+), 6 deletions(-)
        Auto-merging b.ml
        CONFLICT (content): Merge conflict in b.ml
        error: could not apply bfafc01... third commit (fork)
        Could not apply bfafc01... third commit (fork)
        Exit with 1
        |}];
      print_status ();
      [%expect
        {|
        UU File b.ml
        <<<<<<< HEAD:b.ml
        =======

        type b = int


        >>>>>>> bfafc01 (third commit (fork)):a.ml
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
      [%expect
        {|
        [detached HEAD 2df8de0] third commit (fork)
         1 file changed, 2 insertions(+) |}])

let%expect_test "the result name does not need to exist" =
  within_temp_dir (fun () ->
      git_init ();
      List.iter
        [ ("base.ml", "let x=1\nlet y=2\n")
        ; ("current.ml", "let x = 1\nlet y = 2\n")
        ; ("other.ml", "let x=42\nlet y=2\n")
        ]
        ~f:(fun (filename, contents) ->
          Out_channel.write_all filename ~data:contents);
      Out_channel.write_all "result.ml" ~data:"";
      system
        "%s mergetool --base=base.ml --current=current.ml --other=other.ml -o \
         result.ml --name=missing/dir/new.ml"
        merge_fmt;
      print_file "result.ml";
      [%expect
        {|
        File result.ml
        let x = 42
        let y = 2
        |}])

let merge_txt ~current ~other =
  let inputs =
    [ ("base.txt", "a\nb\nc\nd\ne\n")
    ; ("current.txt", current)
    ; ("other.txt", other)
    ]
  in
  List.iter inputs ~f:(fun (filename, contents) ->
      Out_channel.write_all filename ~data:contents;
      Unix.chmod filename 0o444);
  Out_channel.write_all "result.txt" ~data:"";
  system
    "%s mergetool --base=base.txt --current=current.txt --other=other.txt -o \
     result.txt --name=result.txt"
    merge_fmt;
  List.iter inputs ~f:(fun (filename, contents) ->
      assert (String.equal (In_channel.read_all filename) contents));
  print_file "result.txt"

let%expect_test "without a formatter, the result is written to the output" =
  within_temp_dir (fun () ->
      merge_txt ~current:"A\nb\nc\nd\ne\n" ~other:"a\nb\nc\nd\nE\n";
      [%expect
        {|
        File result.txt
        A
        b
        c
        d
        E
        |}])

let%expect_test "without a formatter, conflicts are written to the output" =
  within_temp_dir (fun () ->
      merge_txt ~current:"a\nb\nC1\nd\ne\n" ~other:"a\nb\nC2\nd\ne\n";
      [%expect
        {|
        Exit with 1
        File result.txt
        a
        b
        <<<<<<< current.txt
        C1
        =======
        C2
        >>>>>>> other.txt
        d
        e
        |}])

(* A relative [--name] is relative to the root of the repository, whatever the
   current directory is: [a/b.ml] is formatted using [a/.ocamlformat] (default
   profile) and not the configuration at the root (janestreet profile). *)
let merge_with_relative_name ~from =
  Unix.mkdir "a" 0o700;
  Unix.mkdir "c" 0o700;
  Out_channel.write_all ".ocamlformat" ~data:"profile=janestreet\n";
  Out_channel.write_all "a/.ocamlformat" ~data:"profile=default\n";
  List.iter [ "base"; "current"; "other" ] ~f:(fun side ->
      Out_channel.write_all (side ^ ".ml") ~data:"type t={a:int;b:string}\n");
  Out_channel.write_all "result.ml" ~data:"";
  let root = Unix.getcwd () in
  system
    "cd %s && %s mergetool --base=%s/base.ml --current=%s/current.ml \
     --other=%s/other.ml -o %s/result.ml --name=a/b.ml"
    from merge_fmt root root root root;
  print_file "result.ml"

let%expect_test "relative name, from the root of a git repository" =
  within_temp_dir (fun () ->
      git_init ();
      merge_with_relative_name ~from:".";
      [%expect
        {|
        File result.ml
        type t = { a : int; b : string }
        |}])

let%expect_test "relative name, from a subdirectory of a git repository" =
  within_temp_dir (fun () ->
      git_init ();
      merge_with_relative_name ~from:"c";
      [%expect
        {|
        File result.ml
        type t = { a : int; b : string }
        |}])

let%expect_test "relative name, from a subdirectory of a jj repository" =
  within_temp_dir (fun () ->
      Unix.mkdir ".jj" 0o700;
      merge_with_relative_name ~from:"c";
      [%expect
        {|
        File result.ml
        type t = { a : int; b : string }
        |}])

let%expect_test "relative name, outside of a repository" =
  within_temp_dir (fun () ->
      merge_with_relative_name ~from:"c";
      [%expect
        {|
        File result.ml
        type t =
          { a : int
          ; b : string
          }
        |}])

let%expect_test "with a formatter, conflicts are written to the output" =
  within_temp_dir (fun () ->
      git_init ();
      List.iter
        [ ("base.ml", "let x=1\n")
        ; ("current.ml", "let x=2\n")
        ; ("other.ml", "let x=3\n")
        ]
        ~f:(fun (filename, contents) ->
          Out_channel.write_all filename ~data:contents);
      Out_channel.write_all "result.ml" ~data:"";
      system
        "%s mergetool --base=base.ml --current=current.ml --other=other.ml -o \
         result.ml --name=result.ml"
        merge_fmt;
      print_file "result.ml";
      [%expect
        {|
        Exit with 1
        File result.ml
        <<<<<<< current.ml
        let x = 2
        =======
        let x = 3
        >>>>>>> other.ml
        |}])

let%expect_test "when the merge fails, the output is left untouched" =
  within_temp_dir (fun () ->
      List.iter
        [ ("base.bin", "a\000b\n")
        ; ("current.bin", "a\000c\n")
        ; ("other.bin", "a\000d\n")
        ]
        ~f:(fun (filename, contents) ->
          Out_channel.write_all filename ~data:contents);
      Out_channel.write_all "result.bin" ~data:"previous content\n";
      system
        "%s mergetool --base=base.bin --current=current.bin --other=other.bin \
         -o result.bin --name=result.bin 2>&1"
        merge_fmt;
      print_file "result.bin";
      [%expect
        {|
        error: Cannot merge binary files: current.bin
        Exit with 255
        File result.bin
        previous content
        |}])

let%expect_test "read-only merge inputs are preserved" =
  within_temp_dir (fun () ->
      git_init ();
      let inputs =
        [ ("base.ml", "let x=1\nlet y=2\n")
        ; ("current.ml", "let x = 1\nlet y = 2\n")
        ; ("other.ml", "let x=42\nlet y=2\n")
        ]
      in
      List.iter inputs ~f:(fun (filename, contents) ->
          Out_channel.write_all filename ~data:contents;
          Unix.chmod filename 0o444);
      Out_channel.write_all "result.ml" ~data:"";
      system
        "%s mergetool --base=base.ml --current=current.ml --other=other.ml -o \
         result.ml --name=result.ml"
        merge_fmt;
      List.iter inputs ~f:(fun (filename, contents) ->
          assert (String.equal (In_channel.read_all filename) contents);
          assert (Int.equal (Unix.stat filename).st_perm 0o444));
      print_file "result.ml";
      [%expect
        {|
        File result.ml
        let x = 42
        let y = 2
        |}])

let%expect_test "omitted name uses the original input configuration" =
  within_temp_dir (fun () ->
      Unix.mkdir "project" 0o700;
      Out_channel.write_all "project/.ocamlformat" ~data:"profile=janestreet\n";
      List.iter [ "base"; "current"; "other" ] ~f:(fun side ->
          Out_channel.write_all
            ("project/" ^ side ^ ".ml")
            ~data:"type t={a:int;b:string;c:float}\n");
      Out_channel.write_all "result.ml" ~data:"";
      system
        "%s mergetool --base=project/base.ml --current=project/current.ml \
         --other=project/other.ml -o result.ml"
        merge_fmt;
      print_file "result.ml";
      [%expect
        {|
        File result.ml
        type t =
          { a : int
          ; b : string
          ; c : float
          }
        |}])

let%expect_test "conflicts in diff3 style" =
  within_temp_dir (fun () ->
      git_init ();
      List.iter
        [ ("base.ml", "let x=1\n")
        ; ("current.ml", "let x=2\n")
        ; ("other.ml", "let x=3\n")
        ]
        ~f:(fun (filename, contents) ->
          Out_channel.write_all filename ~data:contents);
      Out_channel.write_all "result.ml" ~data:"";
      system
        "%s mergetool --base=base.ml --current=current.ml --other=other.ml -o \
         result.ml --name=result.ml --diff3"
        merge_fmt;
      print_file "result.ml";
      [%expect
        {|
        Exit with 1
        File result.ml
        <<<<<<< current.ml
        let x = 2
        ||||||| base.ml
        let x = 1
        =======
        let x = 3
        >>>>>>> other.ml
        |}])
