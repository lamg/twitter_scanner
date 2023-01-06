open! Core
open Twitter_scanner
open Io_layer

let db_file = ref "db.sqlite3"
let reports_db = ref "reports.sqlite3"
let slow_reports = ref false
let fast_reports = ref false

let spec_list =
  [ "--db", Arg.Set_string db_file, "database file (db.sqlite3 by default)"
  ; "--reports-db", Arg.Set_string reports_db, "reports database"
  ; "--slow-reports", Arg.Set slow_reports, "executes the slow reports"
  ; "--fast-reports", Arg.Set fast_reports, "executes the fast reports"
    ]
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

let db_uri uri =
  (if String.is_prefix uri ~prefix:"/"
  then Printf.sprintf "sqlite3://%s" uri
  else
    UnixLabels.getenv "PWD"
    |> fun pwd -> Printf.sprintf "sqlite3://%s/%s" pwd uri)
  |> Uri.of_string
;;

let () =
  let () = Arg.parse spec_list (const ()) usage_msg in
  let db_ctx = Db.main_ctx (db_uri !db_file) in
  let reports_db_ctx = Db.main_ctx (db_uri !reports_db) in
  match !slow_reports, !fast_reports with
  | false,false ->
    let time_ctx = Time.main_ctx in
    let http_ctx = Http.main_ctx in
    let ctx = Request.main_ctx time_ctx db_ctx http_ctx in
    Scan_hashtags.main ctx;
    Scan_users_timeline.main ctx;
    Scan_users.main ctx
  | true, _ -> Reports.slow_reports db_ctx reports_db_ctx
  | _, true -> Reports.fast_reports db_ctx reports_db_ctx
;;
