open! Core
open Twitter_scanner
open Io_layer

let db_file = ref "db.sqlite3"

let spec_list =
  [ "-db", Arg.Set_string db_file, "database file (db.sqlite3 by default)" ]
;;

let usage_msg =
  {|
SYNOPSIS
Scans tweets by hashtags, profiles and timelines

REQUIREMENTS
- SQlite3 database with the schema defined at db_schema.sql
- Twitter API bearer token. See https://developer.twitter.com/en/portal/projects-and-apps
- the token needs to be in the token table described in db_schema.sql
|}
;;

let () =
  let () = Arg.parse spec_list (const ()) usage_msg in
  let db_uri =
    UnixLabels.getenv "PWD"
    |> fun pwd ->
    Printf.sprintf "sqlite3://%s/%s" pwd !db_file |> Uri.of_string
  in
  let db_ctx = Db.main_ctx db_uri in
  let time_ctx = Time.main_ctx in
  let http_ctx = Http.main_ctx in
  let ctx = Request.main_ctx time_ctx db_ctx http_ctx in
  Scan_hashtags.main ctx;
  Scan_users_timeline.main ctx;
  Scan_users.main ctx;
  Refresh_public_tables.main ctx
;;
