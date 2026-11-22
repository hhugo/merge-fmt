open! Base
open! Stdio
open! Merge_fmt_test.Common

let base = "let a=1;\nlet f=(x,y)=>x+y;\nlet c = 3;\n"

(* [current] reformats the file and changes [c], [other] changes [a]. *)
let current = "let a = 1;\nlet f = (x, y) => x + y;\nlet c = 33;\n"
let other = "let a=11;\nlet f=(x,y)=>x+y;\nlet c = 3;\n"

(* The files given to the merge tool do not always have the extension of the
   file being merged: [--name] tells which file this is. *)
let mergetool ?(ext = ".re") ~name inputs =
  let inputs =
    List.map inputs ~f:(fun (side, contents) -> (side ^ ext, contents))
  in
  List.iter inputs ~f:(fun (filename, contents) ->
      Out_channel.write_all filename ~data:contents);
  Out_channel.write_all "result" ~data:"";
  system "%s mergetool --base=%s --current=%s --other=%s -o result --name=%s"
    merge_fmt ("base" ^ ext) ("current" ^ ext) ("other" ^ ext) name;
  (* The files given are left untouched. *)
  List.iter inputs ~f:(fun (filename, contents) ->
      assert (String.equal (In_channel.read_all filename) contents));
  print_file "result"

let%expect_test "mergetool on a Reason file" =
  within_temp_dir (fun () ->
      mergetool ~name:"a.re"
        [ ("base", base); ("current", current); ("other", other) ];
      [%expect
        {|
        File result
        let a = 11;
        let f = (x, y) => x + y;
        let c = 33;
        |}])

let%expect_test "mergetool on files without the extension of Reason files" =
  within_temp_dir (fun () ->
      mergetool ~ext:"" ~name:"a.re"
        [ ("base", base); ("current", current); ("other", other) ];
      [%expect
        {|
        File result
        let a = 11;
        let f = (x, y) => x + y;
        let c = 33;
        |}])

let%expect_test "mergetool on a Reason interface" =
  within_temp_dir (fun () ->
      mergetool ~ext:"" ~name:"a.rei"
        [ ("base", "let a:int;\nlet f:(int,int)=>int;\nlet c: int;\n")
        ; ("current", "let a: int;\nlet f: (int, int) => int;\nlet c: float;\n")
        ; ("other", "let a:string;\nlet f:(int,int)=>int;\nlet c: int;\n")
        ];
      [%expect
        {|
        File result
        let a: string;
        let f: (int, int) => int;
        let c: float;
        |}])

(* The files that could be formatted are not merged with the ones that could
   not. *)
let%expect_test "when refmt fails on a file, files are merged as they are" =
  within_temp_dir (fun () ->
      mergetool ~name:"a.re"
        [ ("base", "let a = 1;\nlet b = 2;\nlet c = 3;\n")
        ; ("current", "let a = 1;\nlet b = 2;\nlet c = 3;\nlet d=4;\n")
        ; ("other", "let a = ;\nlet b = 2;\nlet c = 3;\n")
        ];
      (* Skip the error reported by refmt, which depends on the version of
         OCaml. *)
      String.split_lines [%expect.output]
      |> List.drop_while ~f:(fun line ->
          not (String.is_prefix line ~prefix:"merge-fmt:"))
      |> List.iter ~f:print_endline;
      [%expect
        {|
        merge-fmt: failed to format a.re (other), merging without formatting
        File result
        let a = ;
        let b = 2;
        let c = 3;
        let d=4;
        |}])

let%expect_test "resolve conflicts on a Reason file" =
  within_temp_dir (fun () ->
      git_init ();
      let commit contents msg =
        Out_channel.write_all "a.re" ~data:contents;
        system "git add a.re";
        git_commit msg
      in
      commit base "base";
      system "git checkout -q -b side";
      commit other "side";
      system "git checkout -q -";
      commit current "main";
      system "git merge side >%s 2>&1" Stdlib.Filename.null;
      [%expect {| Exit with 1 |}];
      resolve ();
      system "git status --short";
      print_file "a.re";
      [%expect
        {|
        Resolved 1/1 a.re
        M  a.re
        File a.re
        let a = 11;
        let f = (x, y) => x + y;
        let c = 33;
        |}])
