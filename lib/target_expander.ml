(* Expand CLI targets (files/dirs/globs) into concrete markdown file paths. *)
type expand_error =
  | Target_not_found of string
  | Target_read_error of string * string

let is_hidden name =
  String.length name > 0 && name.[0] = '.'

let rec walk_md_files dir =
  try
    let entries = Sys.readdir dir |> Array.to_list in
    List.concat_map
      (fun entry ->
        if is_hidden entry then []
        else
          let path = Filename.concat dir entry in
          if Sys.is_directory path then walk_md_files path
          else if Filename.check_suffix path ".md" then [ path ]
          else [])
      entries
  with Sys_error _ -> []

let has_glob_chars s =
  let len = String.length s in
  let rec loop i =
    if i >= len then false
    else
      match s.[i] with
      | '*' | '?' | '[' -> true
      | _ -> loop (i + 1)
  in
  loop 0

let glob_to_re pattern =
  (* Convert a shell-style glob to a full regex string. *)
  let buf = Buffer.create (String.length pattern * 2) in
  let len = String.length pattern in
  let i = ref 0 in
  Buffer.add_char buf '^';
  while !i < len do
    (match pattern.[!i] with
    | '*' ->
      if !i + 1 < len && pattern.[!i + 1] = '*' then (
        if !i + 2 < len && pattern.[!i + 2] = '/' then (
          Buffer.add_string buf "(.*/)?";
          i := !i + 2)
        else (
          Buffer.add_string buf ".*";
          incr i))
      else Buffer.add_string buf "[^/]*"
    | '?' -> Buffer.add_string buf "[^/]"
    | '[' ->
      Buffer.add_char buf '[';
      incr i;
      if !i < len && pattern.[!i] = '!' then (
        Buffer.add_char buf '^';
        incr i);
      while !i < len && pattern.[!i] <> ']' do
        Buffer.add_char buf pattern.[!i];
        incr i
      done;
      Buffer.add_char buf ']'
    | '.' -> Buffer.add_string buf {|\.|}
    | '(' -> Buffer.add_string buf {|\(|}
    | ')' -> Buffer.add_string buf {|\)|}
    | '+' -> Buffer.add_string buf {|\+|}
    | '^' -> Buffer.add_string buf {|\^|}
    | '$' -> Buffer.add_string buf {|\$|}
    | '{' -> Buffer.add_string buf {|\{|}
    | '}' -> Buffer.add_string buf {|\}|}
    | '|' -> Buffer.add_string buf {|\||}
    | c -> Buffer.add_char buf c);
    incr i
  done;
  Buffer.add_char buf '$';
  Buffer.contents buf

let rec walk_all_files dir =
  try
    let entries = Sys.readdir dir |> Array.to_list in
    List.concat_map
      (fun entry ->
        let path =
          if dir = "." then entry else Filename.concat dir entry
        in
        if Sys.is_directory path then walk_all_files path
        else [ path ])
      entries
  with Sys_error _ -> []

let expand_glob pattern =
  (* Normalize ./ prefixes so glob patterns match paths from walk_all_files. *)
  let normalize path =
    let len = String.length path in
    if len >= 2 && String.sub path 0 2 = "./" then String.sub path 2 (len - 2)
    else path
  in
  let normalized_pattern = normalize pattern in
  let re_str = glob_to_re normalized_pattern in
  let re = Re.compile (Re.Perl.re re_str) in
  let files = walk_all_files "." |> List.map normalize in
  let matches = List.filter (fun path -> Re.execp re path) files in
  match matches with
  | [] -> Error (Target_not_found pattern)
  | _ -> Ok (List.sort String.compare matches)

let expand_literal target =
  (* Expand a file or directory into a list of markdown files. *)
  try
    if Sys.is_directory target then
      let files = walk_md_files target in
      match files with
      | [] -> Error (Target_not_found target)
      | _ -> Ok (List.sort String.compare files)
    else if Sys.file_exists target then Ok [ target ]
    else Error (Target_not_found target)
  with Sys_error msg -> Error (Target_read_error (target, msg))

let expand_target target =
  if has_glob_chars target then expand_glob target
  else expand_literal target

let expand_targets targets =
  let seen = Hashtbl.create 64 in
  let rec loop targets acc =
    match targets with
    | [] -> Ok (List.rev acc)
    | target :: rest -> (
      match expand_target target with
      | Error e -> Error e
      | Ok paths ->
        let new_paths =
          List.filter
            (fun p ->
              if Hashtbl.mem seen p then false
              else (
                Hashtbl.replace seen p ();
                true))
            paths
        in
        loop rest (List.rev_append new_paths acc))
  in
  loop targets []
