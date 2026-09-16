(* Resolve and validate filesystem paths for parsed links. *)
(** Decode percent-encoded sequences in a URL path (e.g. "%20" -> " ").
    Decodes any byte value, so multi-byte UTF-8 sequences such as "%E2%80%93"
    (en dash) round-trip correctly. Malformed sequences are left as-is. *)
let percent_decode input =
  let len = String.length input in
  let buf = Buffer.create len in
  (* Convert a hex character ('0'-'9', 'a'-'f', 'A'-'F') to its integer
     value (0-15), or None if not a valid hex digit. *)
  let hex_digit = function
    | '0' .. '9' as c -> Some (Char.code c - Char.code '0')
    | 'a' .. 'f' as c -> Some (Char.code c - Char.code 'a' + 10)
    | 'A' .. 'F' as c -> Some (Char.code c - Char.code 'A' + 10)
    | _ -> None
  in
  (* Walk the string character by character. When we encounter a valid
     "%XX" sequence, emit the decoded byte and skip ahead 3 positions.
     Otherwise emit the literal char and advance by 1. *)
  let rec loop i =
    if i >= len then ()
    else
      match
        if input.[i] = '%' && i + 2 < len then
          match (hex_digit input.[i + 1], hex_digit input.[i + 2]) with
          | Some v1, Some v2 ->
            let n = (v1 * 16) + v2 in
            (* A NUL byte cannot appear in a filename, so leave it literal. *)
            if n = 0 then None
            else (
              Buffer.add_char buf (Char.chr n);
              Some (i + 3))
          | _ -> None
        else None
      with
      | Some next -> loop next
      | None ->
        Buffer.add_char buf input.[i];
        loop (i + 1)
  in
  loop 0;
  Buffer.contents buf

let directory_of filepath =
  let dir = Filename.dirname filepath in
  if dir = "" then "." else dir

let resolve_path ~source_file link_path =
  (* Paths resolve relative to the source file's directory. *)
  if link_path <> "" && link_path.[0] = '/' then link_path
  else Filename.concat (directory_of source_file) link_path

(* Candidate paths to try, most likely first: a link may be percent-encoded,
   or may name a file that literally contains a '%'. *)
let candidate_paths ~source_file link_path =
  let decoded = percent_decode link_path in
  let paths =
    if decoded = link_path then [ link_path ] else [ decoded; link_path ]
  in
  List.map (resolve_path ~source_file) paths

let path_exists path =
  try
    let st = Unix.stat path in
    st.Unix.st_kind = Unix.S_REG || st.Unix.st_kind = Unix.S_DIR
  with Unix.Unix_error _ -> false

let find_missing_files links =
  List.filter
    (fun (link : Parser.link) ->
      candidate_paths ~source_file:link.source_file link.path
      |> List.for_all (fun p -> not (path_exists p)))
    links
