open! Core
open Io_layer

type ref_tweet =
  { id : string
  ; ref_type : string [@key "type"]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type tweet =
  { id : string
  ; author_id : string
  ; created_at : string
  ; text : string
  ; referenced_tweets : ref_tweet list option [@yojson.option]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type meta =
  { newest_id : string option [@yojson.option]
  ; next_token : string option [@yojson.option]
  ; oldest_id : string option [@yojson.option]
  ; result_count : int option [@yojson.option]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type timeline =
  { data : tweet list option [@yojson.option]
  ; meta : meta option [@yojson.option]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type profile =
  { id : string
  ; name : string
  ; username : string
  ; created_at : string
  ; location : string option [@yojson.option]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type profile_error =
  { value : string
  ; title : string
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

type users =
  { data : profile list
  ; errors : profile_error list option [@yojson.option]
  }
[@@deriving yojson] [@@yojson.allow_extra_fields]

let do_query db_uri query =
  Caqti_lwt.with_connection db_uri query
  |> Lwt_main.run
  |> function
  | Ok r -> r
  | Error e -> Caqti_error.Exn e |> raise
;;

let is_retweet (refs : ref_tweet list option) =
  Option.map refs ~f:(fun rs ->
    match List.hd rs with
    | Some { id = _; ref_type = "retweeted" } -> true
    | _ -> false)
  |> is_some
;;

let parse_timeline (body : string) =
  try
    let t = body |> Yojson.Safe.from_string |> timeline_of_yojson in
    let ndata =
      Option.value ~default:[] t.data
      |> List.map ~f:(fun m ->
           { m with
             text =
               m.text |> String.substr_replace_all ~pattern:"'" ~with_:"''"
           })
    in
    Some { t with data = Some ndata }
  with
  | _ -> None
;;

let insert_reference_tweet
  (ctx : Db.context)
  ~id
  ~reference_id
  ~reference_type
  =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO reference_tweet(id, reference_id, reference_type)
VALUES (%string{id}, %string{reference_id}, %string{reference_type})
|sql}
      syntax_off]
    ~id
    ~reference_id
    ~reference_type
  |> do_query ctx.db_uri
;;

let insert_original_tweet (ctx : Db.context) ~id ~tweet_text =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO original_tweet(id, tweet_text)
VALUES (%string{id}, %string{tweet_text})
|sql}
      syntax_off]
    ~id
    ~tweet_text
  |> do_query ctx.db_uri
;;

let insert_ref_tweet ctx (d : tweet) =
  Option.value d.referenced_tweets ~default:[]
  |> List.iter ~f:(fun (rf : ref_tweet) ->
       insert_reference_tweet
         ctx
         ~id:d.id
         ~reference_id:rf.id
         ~reference_type:rf.ref_type);
  insert_original_tweet ctx ~id:d.id ~tweet_text:d.text
;;

let insert_base_tweet (ctx : Db.context) (t : tweet) =
  [%rapper
    execute
      {sql|
           INSERT OR IGNORE INTO base_tweet(id, author_id, created_at)
           VALUES
           (%string{id}, %string{author_id}, %string{created_at})
  |sql} syntax_off]
    ~id:t.id
    ~author_id:t.author_id
    ~created_at:t.created_at
  |> do_query ctx.db_uri
;;

type context =
  { request : Uri.t -> (int * string) option
  ; db_ctx : Db.context
  ; time_ctx : Time.context
  }

let insert_failed_request (ctx : context) ~url ~code ~body =
  let id = ctx.time_ctx.now_unix () in
  let performed_at = ctx.time_ctx.now_str () in
  [%rapper
    execute
      {sql|
      INSERT INTO failed_request(id, performed_at, url, code, body)
      VALUES
      (%int64{id}, %string{performed_at}, %string{url}, %int{code}, %string{body})
|sql}]
    ~id
    ~performed_at
    ~url
    ~code
    ~body
  |> do_query ctx.db_ctx.db_uri;
  id
;;
