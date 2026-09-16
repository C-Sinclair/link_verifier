(* Assert that every link between two scanned files is reciprocated. *)
type missing = {
  link : Parser.link;
  target : string;
}

(* An edge is only judged when both ends were scanned. A target outside the
   scanned set has never been parsed, so whether it links back is unknown. *)
let build_outgoing links_by_file =
  let outgoing = Hashtbl.create 64 in
  List.iter
    (fun (filepath, links) ->
      let key = Resolver.canonical_file filepath in
      let targets =
        List.map
          (fun (link : Parser.link) ->
            Resolver.canonical_target ~source_file:link.source_file link.path)
          links
      in
      let existing = Hashtbl.find_opt outgoing key |> Option.value ~default:[] in
      Hashtbl.replace outgoing key (targets @ existing))
    links_by_file;
  outgoing

let find_missing links_by_file =
  let outgoing = build_outgoing links_by_file in
  List.concat_map
    (fun (filepath, links) ->
      let source_key = Resolver.canonical_file filepath in
      List.filter_map
        (fun (link : Parser.link) ->
          let target =
            Resolver.canonical_target ~source_file:link.source_file link.path
          in
          if target = source_key then None
          else
            match Hashtbl.find_opt outgoing target with
            | None -> None
            | Some target_links ->
              if List.mem source_key target_links then None
              else Some { link; target })
        links)
    links_by_file
