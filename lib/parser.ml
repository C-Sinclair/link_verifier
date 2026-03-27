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

let fence_re =
  Re.compile (Re.Perl.re {|^(`{3,}|~{3,})|})

let inline_code_re =
  Re.compile (Re.Perl.re {|`[^`]+`|})

let strip_inline_code line =
  Re.replace inline_code_re ~f:(fun _ -> "") line

let parse_links_from_string ?(skip_code = false) ~source_file contents =
  let lines = String.split_on_char '\n' contents in
  let _in_fence, result =
    List.fold_left
      (fun (in_fence, acc) (idx, line_content) ->
        if skip_code && Re.execp fence_re line_content then
          (not in_fence, acc)
        else if skip_code && in_fence then (in_fence, acc)
        else
          let effective_line =
            if skip_code then strip_inline_code line_content
            else line_content
          in
          let matches = Re.all link_re effective_line in
          let links =
            List.filter_map
              (fun group ->
                match Re.Group.get_opt group 1 with
                | Some raw_path ->
                  let path = strip_fragment raw_path in
                  if should_check path then
                    Some { source_file; line = idx + 1; path }
                  else None
                | None -> None)
              matches
          in
          (in_fence, links :: acc))
      (false, [])
      (List.mapi (fun i l -> (i, l)) lines)
  in
  List.concat (List.rev result)

let parse_file_for_links ?(skip_code = false) filepath =
  In_channel.with_open_text filepath (fun ic ->
    In_channel.input_all ic
    |> parse_links_from_string ~skip_code ~source_file:filepath)
