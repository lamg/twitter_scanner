open! Core
open Io_layer
open Shared

(* ***********|SQL and HTTP queries|************* *)

let queries_timeline (oldest_tweet_id : string option) =
  let queries =
    [ "max_results", [ "100" ]
    ; ( "tweet.fields"
      , [ "author_id"; "created_at"; "referenced_tweets"; "text" ] )
    ]
  in
  match oldest_tweet_id with
  | None -> queries
  | Some id -> ("until_id", [ id ]) :: queries
;;

let users_timeline_url
  (profile_id : string)
  (oldest_tweet_id : string option)
  =
  let path =
    Printf.sprintf "https://api.twitter.com/2/users/%s/tweets" profile_id
  in
  queries_timeline oldest_tweet_id |> Http.build_uri path
;;

let insert_oldest_timeline_tweet (ctx : Db.context) ~profile_id ~tweet_id =
  [%rapper
    execute
      {sql|
          INSERT INTO oldest_timeline_tweet(profile_id, tweet_id)
          VALUES
          (%string{profile_id}, %string{tweet_id})
      |sql}]
    ~profile_id
    ~tweet_id
  |> do_query ctx.db_uri
;;

let last_id (ctx : Db.context) ~profile_id =
  [%rapper
    get_opt
      {sql|SELECT @string{tweet_id} FROM oldest_timeline_tweet WHERE profile_id = %string{profile_id}|sql}
      function_out]
    (fun ~tweet_id -> tweet_id)
    ~profile_id
  |> do_query ctx.db_uri
;;

let get_watched_profiles (ctx : Db.context) =
  [%rapper
    get_many {sql|SELECT @string{id} FROM watched_profile|sql} function_out]
    (fun ~id -> id)
    ()
  |> do_query ctx.db_uri
;;

(* end *)

(* ***********|DB and HTTP operations|************ *)

let oldest_timeline_tweet (ctx : Db.context) author_id (t : timeline) =
  (let ( >>= ) = Option.( >>= ) in
   t.meta
   >>= fun l ->
   l.oldest_id
   >>= fun tweet_id ->
   insert_oldest_timeline_tweet ctx ~profile_id:author_id ~tweet_id
   |> Option.return)
  |> Option.value ~default:()
;;

let timeline_insert (ctx : Db.context) (profile_id : string) (t : timeline) =
  let data = t.data |> Option.value ~default:[] in
  data |> List.iter ~f:(insert_base_tweet ctx);
  oldest_timeline_tweet ctx profile_id t;
  data
  |> List.iter ~f:(fun d ->
       d.referenced_tweets
       |> Option.value ~default:[]
       |> List.iter ~f:(fun (r : ref_tweet) ->
            insert_reference_tweet
              ctx
              ~id:r.id
              ~reference_id:r.id
              ~reference_type:r.ref_type))
;;

let process_body ctx ~body ~url ~profile_id =
  parse_timeline body
  |> function
  | Some timeline -> timeline_insert ctx.db_ctx profile_id timeline
  | None -> insert_failed_request ctx ~url ~code:500 ~body |> const ()
;;

(* end *)

(* ***********|Main functionality************ *)

let rec profile_timeline
  (ctx : context)
  ((profile_id, maybe_oldest_tweet_id) : string * string option)
  =
  let url_t = users_timeline_url profile_id maybe_oldest_tweet_id in
  let url = url_t |> Uri.to_string in
  url_t
  |> ctx.request
  |> function
  | None -> insert_failed_request ctx ~url ~code:500 ~body:"" |> const ()
  | Some (200, body) -> process_body ctx ~body ~url ~profile_id
  | Some (400, body) when String.is_substring body ~substring:"since_id" ->
    profile_timeline ctx (profile_id, None)
  | Some (code, body) ->
    insert_failed_request ctx ~url ~code ~body |> const ()
;;

let watched_profiles (ctx : Db.context) : (string * string option) list =
  get_watched_profiles ctx
  |> List.map ~f:(fun profile_id ->
       last_id ctx ~profile_id
       |> fun maybe_oldest_tweet_id -> profile_id, maybe_oldest_tweet_id)
;;

let main (ctx : context) : unit =
  watched_profiles ctx.db_ctx |> List.iter ~f:(profile_timeline ctx)
;;

(* end *)
