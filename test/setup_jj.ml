open! Base
open! Stdio
open! Merge_fmt_test.Common

let%expect_test "print jj configuration" =
  system "%s setup-jj-mergetool" merge_fmt;
  [%expect
    {|
    jj config set --repo merge-tools.merge-fmt.program '"merge-fmt"'
    jj config set --repo merge-tools.merge-fmt.merge-args '["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path"]'
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
      system "jj config get ui.merge-editor";
      [%expect
        {|
        /tmp/merge fmt's tool
        ["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path"]
        :builtin
        |}])
