open! Base
open! Stdio

let ( ^/ ) = Stdlib.Filename.concat

(* Do not translate line endings on Windows. *)
let () =
  Stdlib.set_binary_mode_out Stdlib.stdout true;
  Stdlib.set_binary_mode_out Stdlib.stderr true

let echo = ref false

(* [Unix], extended with what the tests need. The standard library has no
   [unsetenv]: unset variables are recorded here and removed from the
   environment of the processes we start.

   On Windows, there is no [/bin/sh]: the commands are run by [cmd.exe], as
   merge-fmt does. Setting a variable to the empty string removes it there. *)
module Unix = struct
  include Unix

  let unset = ref []

  let unsetenv key =
    if Sys.win32 then Unix.putenv key "" else unset := key :: !unset

  let putenv ~key ~data =
    unset := List.filter !unset ~f:(fun k -> not (String.equal k key));
    putenv key data

  let environment () =
    Array.filter (environment ()) ~f:(fun binding ->
        not
          (List.exists !unset ~f:(fun key ->
               String.is_prefix binding ~prefix:(key ^ "="))))

  let spawn s ~stdout =
    create_process_env "/bin/sh" [| "/bin/sh"; "-c"; s |] (environment ()) stdin
      stdout stderr

  let system s =
    if Sys.win32 then Unix.system s else snd (waitpid [] (spawn s ~stdout))

  let open_process_in s =
    if Sys.win32
    then Unix.open_process_in s
    else
      let r, w = pipe ~cloexec:true () in
      let (_ : int) = spawn s ~stdout:w in
      close w;
      in_channel_of_descr r

  let rec rm_rf path =
    match (lstat path).st_kind with
    | S_DIR ->
        Array.iter (Stdlib.Sys.readdir path) ~f:(fun name ->
            rm_rf (path ^/ name));
        rmdir path
    | _ -> (
        try unlink path
        with Unix_error _ ->
          (* On Windows, read-only files cannot be removed. *)
          chmod path 0o600;
          unlink path)

  let temp_dir ?(in_dir = Stdlib.Filename.get_temp_dir_name ()) prefix suffix =
    let rec loop () =
      let dir =
        in_dir
        ^/ Printf.sprintf "%s%06x%s" prefix (Stdlib.Random.bits ()) suffix
      in
      match mkdir dir 0o700 with
      | () -> dir
      | exception Unix_error (EEXIST, _, _) -> loop ()
    in
    loop ()
end

let system fmt =
  Printf.ksprintf
    (fun s ->
      if !echo then eprintf "+ %s\n%!" s;
      match Unix.system s with
      | WEXITED 0 -> ()
      | WEXITED n -> printf "Exit with %d\n" n
      | WSIGNALED _ | WSTOPPED _ -> printf "Signaled\n")
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

(* The files in the current directory, like [ls]. *)
let list_files () =
  let files = Stdlib.Sys.readdir "." in
  Array.sort files ~compare:String.compare;
  Array.iter files ~f:(fun file ->
      if not (String.is_prefix file ~prefix:".") then print_endline file)

let print_file file =
  printf "File %s\n" file;
  print_endline (In_channel.read_all file)

(* Recent versions of git print "Could not apply <sha>... # <subject>" where
   older ones print "Could not apply <sha>... <subject>". Normalize to the
   older form. *)
let normalize_could_not_apply s =
  if String.is_prefix ~prefix:"Could not apply " (String.strip s)
  then String.substr_replace_first s ~pattern:"... # " ~with_:"... "
  else s

let filter_hint expected =
  String.split ~on:'\n' expected
  |> List.filter ~f:(fun s ->
      not (String.is_prefix ~prefix:"hint:" (String.strip s)))
  |> List.map ~f:normalize_could_not_apply
  |> String.concat ~sep:"\n" |> print_string

(* [git init] records settings describing the filesystem, which depend on the
   platform. *)
let filter_platform_config output =
  String.split ~on:'\n' output
  |> List.filter ~f:(fun s ->
      not
        (List.exists
           [ "core.filemode="
           ; "core.symlinks="
           ; "core.ignorecase="
           ; "core.precomposeunicode="
           ] ~f:(fun prefix -> String.is_prefix (String.strip s) ~prefix)))
  |> String.concat ~sep:"\n" |> print_string

let git_init () =
  system "git init . -q";
  write ".ocamlformat" "profile=janestreet";
  git_commit "initial"

let merge_fmt =
  Stdlib.Filename.dirname (Unix.getcwd ()) ^/ "src" ^/ "merge_fmt.exe"

(* The path of merge-fmt, as recorded in the configuration of git. Git runs it
   with a POSIX shell, even on Windows, where the backslashes would be
   interpreted. That shell also understands [C:/dir/file]. *)
let merge_fmt_path =
  if Sys.win32
  then String.tr merge_fmt ~target:'\\' ~replacement:'/'
  else merge_fmt

let resolve () = system "%s" merge_fmt

let with_temp_dir f =
  let in_dir = Sys.getenv "TMPDIR" in
  let keep_tmp_dir = Option.is_some (Sys.getenv "KEEP_EXPECT_TEST_DIR") in
  let dir = Unix.temp_dir ?in_dir "expect-" "-test" in
  (* Note that this blocks *)
  assert (not (Stdlib.Filename.is_relative dir));
  let res = match f dir with x -> Ok x | exception e -> Error e in
  if keep_tmp_dir then eprintf "OUTPUT LEFT IN %s\n" dir else Unix.rm_rf dir;
  Result.ok_exn res

let within_temp_dir ?(links = []) f =
  let cwd = Unix.getcwd () in
  (* [Unix.umask] is not implemented on Windows. *)
  if not Sys.win32 then ignore (Unix.umask 0o077 : int);
  with_temp_dir @@ fun home ->
  with_temp_dir (fun temp_dir ->
      (* disable all external git configuration configuration *)
      Unix.putenv ~key:"GIT_CONFIG_NOSYSTEM" ~data:"1";
      Unix.putenv ~key:"GIT_CONFIG_NOGLOBAL" ~data:"1";

      Unix.unsetenv "GIT_CONFIG";
      (* Use an empty home directory. Without [HOME], git looks elsewhere for
         the configuration of the user on Windows: in the user profile for
         Git for Windows, in the home directory of the POSIX environment for
         the git of Cygwin and MSYS2. *)
      Unix.putenv ~key:"HOME" ~data:home;
      Unix.unsetenv "XDG_CONFIG_HOME";
      (* The tests run under dune; make nested dune invocations behave as if
         run by a user (no missing dune-project warning, no stray _build). *)
      Unix.unsetenv "INSIDE_DUNE";

      Unix.putenv ~key:"GIT_COMMITTER_NAME" ~data:"John Doe";
      Unix.putenv ~key:"GIT_COMMITTER_DATE" ~data:"2020-12-03 19:00:00 +0000";
      Unix.putenv ~key:"GIT_COMMITTER_EMAIL" ~data:"johndoe@doe.com";
      Unix.putenv ~key:"GIT_AUTHOR_NAME" ~data:"John Doe";
      Unix.putenv ~key:"GIT_AUTHOR_EMAIL" ~data:"johndoe@doe.com";
      Unix.putenv ~key:"GIT_AUTHOR_DATE" ~data:"2020-12-03 19:00:00 +0000";
      Unix.putenv ~key:"GIT_EDITOR" ~data:"true";
      let path_var = "PATH" in
      let old_path = Sys.getenv_exn path_var in
      let bin = temp_dir ^/ "bin" in
      let path_sep = if Sys.win32 then ";" else ":" in
      Unix.putenv ~key:path_var
        ~data:(String.concat ~sep:path_sep [ bin; old_path ]);
      let () = Unix.mkdir bin 0o700 in
      let () =
        List.iter links ~f:(fun (file, action, link_as) ->
            let link_as =
              match action with
              | `In_path_as -> "bin" ^/ link_as
              | `In_temp_as -> link_as
            in
            (* We use hard links to ensure that files remain available and unchanged even if
               jenga starts to rebuild while the test is running. *)
            Unix.link file (temp_dir ^/ link_as))
      in
      let () = Unix.chdir temp_dir in
      let res = match f () with x -> Ok x | exception e -> Error e in
      Unix.putenv ~key:path_var ~data:old_path;
      Unix.chdir cwd;
      Result.ok_exn res)

let%expect_test _ =
  within_temp_dir (fun () ->
      git_init ();
      system "git config -l";
      filter_platform_config [%expect.output];
      [%expect
        {|
        core.repositoryformatversion=0
        core.bare=false
        core.logallrefupdates=true
        |}];
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
