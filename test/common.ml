open! Base
open! Stdio

let ( ^/ ) = Stdlib.Filename.concat
let echo = ref false

let system fmt =
  Printf.ksprintf
    (fun s ->
      if !echo then eprintf "+ %s\n%!" s;
      let p = Core_unix.system s in
      match p with
      | Ok () -> ()
      | Error (`Signal _) -> printf "Signaled\n"
      | Error (`Exit_non_zero n) -> printf "Exit with %d\n" n)
    fmt

let git_add fn = system "git add %s" fn
let git_commit msg = system "git commit -m %S -q" msg
let git_branch br = system "git branch %s" br
let git_checkout name = system "git checkout %s" name

let write fn content =
  Out_channel.write_all fn ~data:content;
  git_add fn

let print_status () =
  let ic = Unix.open_process_in "git status -s" in
  let stats =
    List.filter_map (In_channel.input_lines ic) ~f:(fun line ->
        match
          String.split (String.strip line) ~on:' '
          |> List.filter ~f:(function "" -> false | _ -> true)
        with
        | [ m; filename ] -> Some (m, filename)
        | _ -> assert false)
  in
  match stats with
  | [] -> printf "no changes"
  | l ->
      List.iter l ~f:(fun (m, f) ->
          printf "%s File %s\n" m f;
          print_endline (In_channel.read_all f))

let print_file file =
  printf "File %s\n" file;
  print_endline (In_channel.read_all file)

let git_init () =
  system "git init . -q";
  write ".ocamlformat" "profile=janestreet";
  git_commit "initial"

let merge_fmt =
  let current_dir = Unix.getcwd () in
  let tool = "../src/merge_fmt.exe" in
  Stdlib.Filename.concat current_dir tool

let resolve () = system "%s" merge_fmt

let with_temp_dir f =
  let in_dir = Sys.getenv "TMPDIR" in
  let keep_tmp_dir = Option.is_some (Sys.getenv "KEEP_EXPECT_TEST_DIR") in
  let dir = Filename_unix.temp_dir ?in_dir "expect-" "-test" in
  (* Note that this blocks *)
  assert (not (Stdlib.Filename.is_relative dir));
  let res = match f dir with x -> Ok x | exception e -> Error e in
  if keep_tmp_dir
  then eprintf "OUTPUT LEFT IN %s\n" dir
  else system "rm -rf %s" dir;
  Result.ok_exn res

let within_temp_dir ?(links = []) f =
  let cwd = Unix.getcwd () in
  let (_ : int) = Unix.umask 0o077 in
  with_temp_dir (fun temp_dir ->
      (* disable all external git configuration configuration *)
      Core_unix.putenv ~key:"GIT_CONFIG_NOSYSTEM" ~data:"1";
      Core_unix.putenv ~key:"GIT_CONFIG_NOGLOBAL" ~data:"1";

      Core_unix.unsetenv "GIT_CONFIG";
      Core_unix.unsetenv "HOME";
      Core_unix.unsetenv "XDG_CONFIG_HOME";

      Core_unix.putenv ~key:"GIT_COMMITTER_NAME" ~data:"John Doe";
      Core_unix.putenv ~key:"GIT_COMMITTER_DATE"
        ~data:"2020-12-03 19:00:00 +0000";
      Core_unix.putenv ~key:"GIT_COMMITTER_EMAIL" ~data:"johndoe@doe.com";
      Core_unix.putenv ~key:"GIT_AUTHOR_NAME" ~data:"John Doe";
      Core_unix.putenv ~key:"GIT_AUTHOR_EMAIL" ~data:"johndoe@doe.com";
      Core_unix.putenv ~key:"GIT_AUTHOR_DATE" ~data:"2020-12-03 19:00:00 +0000";
      Core_unix.putenv ~key:"GIT_EDITOR" ~data:"true";
      let path_var = "PATH" in
      let old_path = Sys.getenv_exn path_var in
      let bin = temp_dir ^/ "bin" in
      Core_unix.putenv ~key:path_var
        ~data:(String.concat ~sep:":" [ bin; old_path ]);
      let () = system "mkdir %s" bin in
      let () =
        List.iter links ~f:(fun (file, action, link_as) ->
            let link_as =
              match action with
              | `In_path_as -> "bin" ^/ link_as
              | `In_temp_as -> link_as
            in
            (* We use hard links to ensure that files remain available and unchanged even if
               jenga starts to rebuild while the test is running. *)
            system "/bin/ln -T %s %s" file (temp_dir ^/ link_as))
      in
      let () = Unix.chdir temp_dir in
      let res = match f () with x -> Ok x | exception e -> Error e in
      Core_unix.putenv ~key:path_var ~data:old_path;
      Unix.chdir cwd;
      Result.ok_exn res)

let%expect_test _ =
  within_temp_dir (fun () ->
      git_init ();
      system "git config -l";
      [%expect
        {|
        core.repositoryformatversion=0
        core.filemode=true
        core.bare=false
        core.logallrefupdates=true |}];
      system "git show --format=raw HEAD";
      [%expect
        {|
        commit 4de0f8c2fa140c9b4cf667864af6fb76afae0206
        tree 90f548f11622b8462d718dfa8a6b5749c67145e7
        author John Doe <johndoe@doe.com> 1607022000 +0000
        committer John Doe <johndoe@doe.com> 1607022000 +0000

            initial

        diff --git a/.ocamlformat b/.ocamlformat
        new file mode 100644
        index 0000000..fa4af5a
        --- /dev/null
        +++ b/.ocamlformat
        @@ -0,0 +1 @@
        +profile=janestreet
        \ No newline at end of file |}];
      write "a.ml"
        {|
type t = { a : int;
           b : string;
           c : float;
         }
|};
      git_commit "first commit";
      system "git show --format=raw HEAD";
      [%expect
        {|
        commit 2a7a47ddd1c03d9e88ab56eac01765014c53b2de
        tree c274a479e323ccf6b8b06ed2984b8147f56ca87c
        parent 4de0f8c2fa140c9b4cf667864af6fb76afae0206
        author John Doe <johndoe@doe.com> 1607022000 +0000
        committer John Doe <johndoe@doe.com> 1607022000 +0000

            first commit

        diff --git a/a.ml b/a.ml
        new file mode 100644
        index 0000000..648ba45
        --- /dev/null
        +++ b/a.ml
        @@ -0,0 +1,5 @@
        +
        +type t = { a : int;
        +           b : string;
        +           c : float;
        +         } |}])
