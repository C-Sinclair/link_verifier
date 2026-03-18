(* CLI entrypoint: argument parsing and main verification flow. *)
open Link_verifier_lib

let version = "0.3.1"

let filter_except filepaths except_patterns =
  (* Compile user-provided regexes once; invalid patterns fail fast. *)
  match except_patterns with
  | [] -> filepaths
  | _ ->
    let compiled =
      List.map
        (fun p ->
          match Re.compile (Re.Perl.re p) with
          | exception _ ->
            Printf.eprintf "invalid --except regex: %s\n" p;
            exit 1
          | re -> re)
        except_patterns
    in
    List.filter
      (fun path -> not (List.exists (fun re -> Re.execp re path) compiled))
      filepaths

let verify targets except =
  (* Expand targets into concrete files, then collect missing links. *)
  match Target_expander.expand_targets targets with
  | Error (Target_expander.Target_not_found target) ->
    Printf.eprintf "target not found: %s\n" target;
    exit 1
  | Error (Target_expander.Target_read_error (target, msg)) ->
    Printf.eprintf "could not read target: %s (%s)\n" target msg;
    exit 1
  | Ok filepaths ->
    let filepaths = filter_except filepaths except in
    let bad_links =
      List.concat_map
        (fun filepath ->
          match Parser.parse_file_for_links filepath with
          | exception Sys_error msg ->
            Printf.eprintf "error reading file: %s (%s)\n" filepath msg;
            exit 1
          | links -> Resolver.find_missing_files links)
        filepaths
    in
    let exit_code = Reporter.report_broken_links bad_links in
    exit exit_code

let targets_t =
  let doc = "Files, directories, or glob patterns to check." in
  Cmdliner.Arg.(value & pos_all string [] & info [] ~docv:"TARGET" ~doc)

let except_t =
  let doc = "Exclude files matching regex pattern (repeatable)." in
  Cmdliner.Arg.(
    value & opt_all string [] & info [ "x"; "except" ] ~docv:"PATTERN" ~doc)

let cmd =
  let doc = "Verify markdown-style local links" in
  let info = Cmdliner.Cmd.info "link_verifier" ~version ~doc in
  let term =
    Cmdliner.Term.(
      const (fun targets except ->
        match targets with
        | [] ->
          Printf.eprintf
            "usage: link_verifier <target> [target ...] [options]\n\n\
             targets can be files, directories, or wildcard patterns such as \
             *.md\n\n\
             options:\n\
            \  -h, --help              show this help\n\
            \  -v, --version           show version\n\
            \  -x, --except <pattern>  exclude files matching regex \
             (repeatable)\n";
          exit 1
        | _ -> verify targets except)
      $ targets_t
      $ except_t)
  in
  Cmdliner.Cmd.v info term

let () = exit (Cmdliner.Cmd.eval cmd)
