(* Parse markdown-style links from file contents. *)
type link = {
  source_file : string;
  line : int;
  path : string;
}

let link_re =
  (* Capture markdown link targets, allowing balanced parentheses inside. *)
  Re.compile (Re.Perl.re {|\[.*?\]\(([^()]*(?:\([^()]*\)[^()]*)*)\)|})

let is_external path =
  String.starts_with ~prefix:"https://" path
  || String.starts_with ~prefix:"http://" path

let strip_fragment path =
  match String.index_opt path '#' with
  | Some i -> String.sub path 0 i
  | None -> path

let should_check path =
  path <> ""
  && not (is_external path)
  && not (String.starts_with ~prefix:"mailto:" path)
  && not (String.starts_with ~prefix:"tel:" path)
  && not (path.[0] = '?')

let parse_links_from_string ~source_file contents =
  (* Line-by-line scanning keeps line numbers stable for error reporting. *)
  let lines = String.split_on_char '\n' contents in
  lines
  |> List.mapi (fun idx line_content ->
       let matches = Re.all link_re line_content in
       List.filter_map
         (fun group ->
           match Re.Group.get_opt group 1 with
           | Some raw_path ->
             let path = strip_fragment raw_path in
             if should_check path then Some { source_file; line = idx + 1; path }
             else None
           | None -> None)
         matches)
  |> List.concat

let parse_file_for_links filepath =
  In_channel.with_open_text filepath (fun ic ->
    In_channel.input_all ic |> parse_links_from_string ~source_file:filepath)
