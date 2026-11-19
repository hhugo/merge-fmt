open! Base
open! Stdio
open! Merge_fmt_test.Common

let%expect_test "print jj configuration" =
  system "%s setup-jj-mergetool" merge_fmt;
  [%expect
    {|
    jj config set --repo merge-tools.merge-fmt.program '"merge-fmt"'
    jj config set --repo merge-tools.merge-fmt.merge-args '["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path", "--diff3"]'
    jj config set --repo merge-tools.merge-fmt.merge-conflict-exit-codes '[1]'
    |}]

let%expect_test "configure jj without changing the default merge tool" =
  within_temp_dir (fun () ->
      Unix.putenv ~key:"XDG_CONFIG_HOME"
        ~data:(Stdlib.Filename.concat (Unix.getcwd ()) "config");
      system "jj git init . >/dev/null 2>&1";
      system "jj config set --repo ui.merge-editor :builtin";
      system "%s setup-jj-mergetool --update --merge-fmt-path %s" merge_fmt
        (Stdlib.Filename.quote "/tmp/merge fmt's tool");
      system "jj config get merge-tools.merge-fmt.program";
      system "jj config get merge-tools.merge-fmt.merge-args";
      system "jj config get merge-tools.merge-fmt.merge-conflict-exit-codes";
      system "jj config get ui.merge-editor";
      [%expect
        {|
        /tmp/merge fmt's tool
        ["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path", "--diff3"]
        [1]
        :builtin
        |}])

(* One side reformats the file, the other one changes [x] and [y]. [y] is also
   changed by the first side: this is the only conflict left. *)
let%expect_test "resolve conflicts with jj" =
  within_temp_dir (fun () ->
      Unix.putenv ~key:"XDG_CONFIG_HOME"
        ~data:(Stdlib.Filename.concat (Unix.getcwd ()) "config");
      Unix.putenv ~key:"JJ_USER" ~data:"John Doe";
      Unix.putenv ~key:"JJ_EMAIL" ~data:"johndoe@doe.com";
      let jj fmt = Printf.ksprintf (system "jj --quiet %s 2>&1") fmt in
      let commit name files =
        List.iter files ~f:(fun (filename, contents) ->
            Out_channel.write_all filename ~data:contents);
        jj "commit -m %s" name;
        jj "bookmark create %s -r @-" name
      in
      jj "git init .";
      system "%s setup-jj-mergetool --update --merge-fmt-path %s" merge_fmt
        merge_fmt;
      Unix.mkdir "lib" 0o700;
      let middle = "let a = 0\nlet b = 0\nlet c = 0\n" in
      commit "base"
        [ (".ocamlformat", "profile=janestreet\n")
        ; ("lib/a.ml", "let x=1\n" ^ middle ^ "let y=2\n")
        ; ("lib/t.txt", "a\nb\nc\n")
        ];
      commit "side1"
        [ ("lib/a.ml", "let x = 1\n" ^ middle ^ "let y = 22\n")
        ; ("lib/t.txt", "a\nB1\nc\n")
        ];
      jj "new base";
      commit "side2"
        [ ("lib/a.ml", "let x=7\n" ^ middle ^ "let y=33\n")
        ; ("lib/t.txt", "a\nB2\nc\n")
        ];
      jj "new side1 side2";
      system "jj resolve --list";
      [%expect
        {|
        lib/a.ml     2-sided conflict
        lib/t.txt    2-sided conflict
        |}];
      (* From a subdirectory, on all the files. In [lib/a.ml], [x] is merged
         and only the conflict on [y] is left. *)
      system "cd lib && jj --quiet resolve --tool merge-fmt 2>&1";
      system "jj resolve --list";
      system "grep -c '^<<<<<<<' lib/a.ml lib/t.txt";
      system "head -n 4 lib/a.ml";
      [%expect
        {|
        lib/a.ml     2-sided conflict
        lib/t.txt    2-sided conflict
        lib/a.ml:1
        lib/t.txt:1
        let x = 7
        let a = 0
        let b = 0
        let c = 0
        |}])
