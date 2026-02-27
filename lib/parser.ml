type link = {
  source_file : string;
  line : int;
  path : string;
}

let link_re =
  Re.compile (Re.Perl.re {|\[.*?\]\(([^()]*(?:\([^()]*\)[^()]*)*)\)|})

let starts_with s prefix =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

let is_external path =
  starts_with path "https://" || starts_with path "http://"

let strip_fragment path =
  match String.index_opt path '#' with
  | Some i -> String.sub path 0 i
  | None -> path

let should_check path =
  path <> ""
  && not (is_external path)
  && not (starts_with path "mailto:")
  && not (starts_with path "tel:")
  && not (path.[0] = '?')

let parse_links_from_string ~source_file contents =
  let lines = String.split_on_char '\n' contents in
  let links = ref [] in
  List.iteri
    (fun idx line_content ->
      let matches = Re.all link_re line_content in
      List.iter
        (fun group ->
          match Re.Group.get_opt group 1 with
          | Some raw_path ->
            let path = strip_fragment raw_path in
            if should_check path then
              links := { source_file; line = idx + 1; path } :: !links
          | None -> ())
        matches)
    lines;
  List.rev !links

let parse_file_for_links filepath =
  let ic = open_in filepath in
  let contents = In_channel.input_all ic in
  close_in ic;
  parse_links_from_string ~source_file:filepath contents
