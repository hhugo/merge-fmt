open! Base
open! Stdio
open! Common

(* [false] stands for a formatter that fails, as ocamlformat does on a syntax
   error or when [.ocamlformat] asks for another version. *)
let merge_with_failing_formatter ~current ~other =
  let inputs =
    [ ("base.ml", "let x=1\nlet a = 0\nlet b = 0\nlet c = 0\nlet y=2\n")
    ; ("current.ml", current)
    ; ("other.ml", other)
    ]
  in
  List.iter inputs ~f:(fun (filename, contents) ->
      Out_channel.write_all filename ~data:contents);
  Out_channel.write_all "result.ml" ~data:"previous content\n";
  system
    "%s mergetool --ocamlformat=false --base=base.ml --current=current.ml \
     --other=other.ml -o result.ml --name=result.ml"
    merge_fmt;
  List.iter inputs ~f:(fun (filename, contents) ->
      assert (String.equal (In_channel.read_all filename) contents));
  print_file "result.ml"

let%expect_test "when formatting fails, files are merged as they are" =
  within_temp_dir (fun () ->
      git_init ();
      merge_with_failing_formatter
        ~current:"let x=3\nlet a = 0\nlet b = 0\nlet c = 0\nlet y=2\n"
        ~other:"let x=1\nlet a = 0\nlet b = 0\nlet c = 0\nlet y=22\n";
      [%expect
        {|
        merge-fmt: failed to format result.ml (current, other, base), merging without formatting
        File result.ml
        let x=3
        let a = 0
        let b = 0
        let c = 0
        let y=22
        |}])

let%expect_test "when formatting fails, conflicts are still reported" =
  within_temp_dir (fun () ->
      git_init ();
      merge_with_failing_formatter
        ~current:"let x=3\nlet a = 0\nlet b = 0\nlet c = 0\nlet y=2\n"
        ~other:"let x=4\nlet a = 0\nlet b = 0\nlet c = 0\nlet y=2\n";
      [%expect
        {|
        merge-fmt: failed to format result.ml (current, other, base), merging without formatting
        Exit with 1
        File result.ml
        <<<<<<< current.ml
        let x=3
        =======
        let x=4
        >>>>>>> other.ml
        let a = 0
        let b = 0
        let c = 0
        let y=2
        |}])
