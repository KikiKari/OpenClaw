(* OpenClaw Node Health Check (OCaml) — raw TCP connect probe via Unix *)

let check_node addr =
  match String.rindex_opt addr ':' with
  | None -> Printf.sprintf "FAIL %s: no port" addr
  | Some i ->
    let host = String.sub addr 0 i in
    let port = int_of_string (String.sub addr (i + 1) (String.length addr - i - 1)) in
    let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    (try
       let he = Unix.gethostbyname host in
       Unix.connect sock (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port));
       Unix.close sock;
       Printf.sprintf "OK   %s: connected" addr
     with e ->
       (try Unix.close sock with _ -> ());
       Printf.sprintf "FAIL %s: %s" addr (Printexc.to_string e))

let () =
  let n = Array.length Sys.argv in
  let nodes =
    if n > 1 then Array.to_list (Array.sub Sys.argv 1 (n - 1))
    else [ "localhost:8080"; "localhost:8081" ]
  in
  List.iter (fun node -> print_endline (check_node node)) nodes
