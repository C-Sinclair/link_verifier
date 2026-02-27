let percent_decode input =
  let len = String.length input in
  let buf = Buffer.create len in
  let i = ref 0 in
  while !i < len do
    if
      input.[!i] = '%'
      && !i + 2 < len
      && (let h1 = input.[!i + 1] and h2 = input.[!i + 2] in
          let hex c =
            match c with
            | '0' .. '9' -> Some (Char.code c - Char.code '0')
            | 'a' .. 'f' -> Some (Char.code c - Char.code 'a' + 10)
            | 'A' .. 'F' -> Some (Char.code c - Char.code 'A' + 10)
            | _ -> None
          in
          match (hex h1, hex h2) with
          | Some v1, Some v2 ->
            let n = (v1 * 16) + v2 in
            if n >= 32 && n <= 126 then (
              Buffer.add_char buf (Char.chr n);
              i := !i + 3;
              true)
            else false
          | _ -> false)
    then ()
    else (
      Buffer.add_char buf input.[!i];
      incr i)
  done;
  Buffer.contents buf

let directory_of filepath =
  let dir = Filename.dirname filepath in
  if dir = "" then "." else dir

let resolve_path ~source_file link_path =
  let decoded = percent_decode link_path in
  if String.length decoded > 0 && decoded.[0] = '/' then decoded
  else Filename.concat (directory_of source_file) decoded

let path_exists path =
  try
    let st = Unix.stat path in
    st.Unix.st_kind = Unix.S_REG || st.Unix.st_kind = Unix.S_DIR
  with Unix.Unix_error _ -> false

let find_missing_files links =
  List.filter
    (fun (link : Parser.link) ->
      let resolved = resolve_path ~source_file:link.source_file link.path in
      not (path_exists resolved))
    links
