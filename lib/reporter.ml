(* Emit broken-link diagnostics and compute exit code. *)
let pluralize count singular plural =
  if count = 1 then singular else plural

let report_broken_links (bad_links : Parser.link list) =
  match bad_links with
  | [] -> 0
  | _ ->
    List.iter
      (fun { Parser.source_file; line; path } ->
        Printf.eprintf "%s:%d: broken link -> %s\n" source_file line path)
      bad_links;
    let link_count = List.length bad_links in
    let file_count =
      bad_links
      |> List.map (fun { Parser.source_file; _ } -> source_file)
      |> List.sort_uniq String.compare
      |> List.length
    in
    Printf.eprintf "\n%d broken %s in %d %s\n" link_count
      (pluralize link_count "link" "links")
      file_count
      (pluralize file_count "file" "files");
    (* Exit code 2 signals broken links (per CLI contract). *)
    2

let report_missing_backlinks (missing : Backlinks.missing list) =
  match missing with
  | [] -> 0
  | _ ->
    List.iter
      (fun { Backlinks.link; target } ->
        Printf.eprintf "%s:%d: no backlink from %s\n" link.Parser.source_file
          link.Parser.line target)
      missing;
    let count = List.length missing in
    let file_count =
      missing
      |> List.map (fun { Backlinks.link; _ } -> link.Parser.source_file)
      |> List.sort_uniq String.compare
      |> List.length
    in
    Printf.eprintf "\n%d missing %s in %d %s\n" count
      (pluralize count "backlink" "backlinks")
      file_count
      (pluralize file_count "file" "files");
    2
