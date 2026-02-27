let pluralize count singular plural =
  if count = 1 then singular else plural

let report_broken_links (bad_links : Parser.link list) =
  match bad_links with
  | [] -> 0
  | _ ->
    List.iter
      (fun (link : Parser.link) ->
        Printf.eprintf "%s:%d: broken link -> %s\n" link.source_file link.line
          link.path)
      bad_links;
    let link_count = List.length bad_links in
    let file_count =
      bad_links
      |> List.map (fun (l : Parser.link) -> l.source_file)
      |> List.sort_uniq String.compare
      |> List.length
    in
    Printf.eprintf "\n%d broken %s in %d %s\n" link_count
      (pluralize link_count "link" "links")
      file_count
      (pluralize file_count "file" "files");
    2
