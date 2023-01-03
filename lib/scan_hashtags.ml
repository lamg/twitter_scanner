open! Core
open Shared
open Io_layer

(* ***********|SQL and HTTP queries|************* *)

type id_tweet_query =
  { id : int64
  ; tweet_query : string
  }

let queries (ctx : Db.context) : id_tweet_query list =
  [%rapper
    get_many
      {sql|SELECT @int64{id}, @string{tweet_query} FROM query|sql}
      record_out]
    ()
  |> do_query ctx.db_uri
;;

let search_recent_endpoint = "https://api.twitter.com/2/tweets/search/recent"

let search_recent_query last_id query =
  [ "query", [ query ]
  ; "tweet.fields", [ "author_id"; "geo"; "created_at"; "referenced_tweets" ]
  ; "max_results", [ "100" ]
  ]
  |> List.append
       (match last_id with
        | None -> []
        | Some id -> [ "since_id", [ id ] ])
;;

let insert_scanning ctx ~query_id ~len =
  [%rapper
    execute
      {sql|
INSERT INTO scanning(query_id, scan_date, amount)
VALUES (%int64{query_id}, %string{scan_date}, %int{len})
ON CONFLICT DO
UPDATE SET scan_date=%string{scan_date}, amount=%int{len}
WHERE query_id=%int64{query_id}
      |sql}]
    ~query_id
    ~scan_date:(ctx.time_ctx.now_str ())
    ~len
  |> do_query ctx.db_ctx.db_uri
;;

let insert_query_tweet ctx ~query_id ~tweet_id =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO query_tweet(query_id, tweet_id, seen)
VALUES (%int64{query_id}, %string{tweet_id}, 0)
|sql}
      syntax_off]
    ~query_id
    ~tweet_id
  |> do_query ctx.db_ctx.db_uri
;;

let update_seen ctx ~query_id ~tweet_id =
  [%rapper
    execute
      {sql|
UPDATE query_tweet SET seen = seen + 1
WHERE query_id = %int64{query_id} AND tweet_id = %string{tweet_id}|sql}]
    ~query_id
    ~tweet_id
  |> do_query ctx.db_ctx.db_uri
;;

let insert_failed_query (ctx : context) ~request_id ~query_id =
  [%rapper
    execute
      {sql|
INSERT INTO failed_query(request_id, query_id)
VALUES (%int64{request_id}, %int64{query_id})
|sql}]
    ~request_id
    ~query_id
  |> do_query ctx.db_ctx.db_uri
;;

let get_last_id (ctx : Db.context) =
  [%rapper
    get_opt
      {sql|
SELECT @string{id} FROM base_tweet ORDER BY created_at DESC LIMIT 1
|sql}
      function_out]
    (fun ~id -> id)
    ()
  |> do_query ctx.db_uri
;;

(* end *)

(* ***********|DB and HTTP operations|************ *)

let insert_query_tweets (ctx : context) (query_id : int64) (m : timeline) =
  let data = m.data |> Option.value ~default:[] in
  let len = List.length data in
  data
  |> List.iter ~f:(fun d ->
       insert_ref_tweet ctx.db_ctx d;
       insert_scanning ctx ~query_id ~len;
       insert_base_tweet ctx.db_ctx d;
       insert_query_tweet ctx ~query_id ~tweet_id:d.id;
       update_seen ctx ~query_id ~tweet_id:d.id)
;;

let failed_request ctx ~code ~url ~query_id ~body =
  let request_id = insert_failed_request ctx ~url ~code ~body in
  insert_failed_query ctx ~request_id ~query_id
;;

let process_body ctx ~body ~query_id ~url =
  parse_timeline body
  |> function
  | Some timeline -> insert_query_tweets ctx query_id timeline
  | None ->
    let request_id = insert_failed_request ctx ~url ~code:200 ~body in
    insert_failed_query ctx ~request_id ~query_id
;;

(* end *)

(* ***********|Main functionality************ *)

let rec search_recent
  (ctx : context)
  (last_id : string option)
  (query_id : int64)
  (query : string)
  =
  let url_t =
    search_recent_query last_id query
    |> Request.build_uri search_recent_endpoint
  in
  let url = url_t |> Uri.to_string in
  url_t
  |> ctx.request
  |> function
  | None -> failed_request ctx ~url ~query_id ~code:500 ~body:""
  | Some (200, body) -> process_body ctx ~body ~query_id ~url
  | Some (400, body) when body |> String.is_substring ~substring:"since_id"
    ->
    (* in case last_id is from a tweet older than one week, Twitter API
       responds with an error *)
    search_recent ctx None query_id query
  | Some (code, body) -> failed_request ctx ~url ~query_id ~code ~body
;;

let main (ctx : context) =
  let last_id = get_last_id ctx.db_ctx in
  queries ctx.db_ctx
  |> List.iter ~f:(fun { id; tweet_query } ->
       search_recent ctx last_id id tweet_query)
;;

(* end *)

let%test "build_uri" =
  search_recent_query None "#SOSCuba"
  |> Request.build_uri search_recent_endpoint
  |> Uri.to_string
  |> String.equal
       "https://api.twitter.com/2/tweets/search/recent?max_results=100&tweet.fields=author_id,geo,created_at,referenced_tweets&query=%23SOSCuba"
;;
