open! Core
open Shared
open Io_layer

(* ***********|SQL and HTTP queries|************* *)

let users_endpoint = "https://api.twitter.com/2/users"

let users_query ids =
  [ "ids", ids; "user.fields", [ "created_at"; "location" ] ]
;;

let profiles_to_update (ctx : Db.context) =
  [%rapper
    get_many
      {sql| SELECT @string{profile_id} FROM update_profile_batch |sql}
      function_out]
    (fun ~profile_id -> profile_id)
    ()
  |> do_query ctx.db_uri
;;

let insert_profile (ctx : Db.context) (p : profile) =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO profile(id, name, created_at, username)
VALUES (%string{id}, %string{name}, %string{created_at}, %string{username})
|sql}
      syntax_off]
    ~id:p.id
    ~name:p.name
    ~created_at:p.created_at
    ~username:p.username
  |> do_query ctx.db_uri
;;

let insert_profile_location
  (ctx : Db.context)
  (profile_id : string)
  (location : string)
  =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO profile_location(profile_id, location)
VALUES (%string{profile_id}, %string{location})
            |sql}
      syntax_off]
    ~profile_id
    ~location
  |> do_query ctx.db_uri
;;

let insert_deactivated_profile (ctx : context) (e : profile_error) =
  [%rapper
    execute
      {sql|
INSERT OR IGNORE INTO profile_deactivated(profile_id, noticed_at, status)
VALUES (%string{profile_id}, %string{noticed_at}, %string{status})
       |sql}
      syntax_off]
    ~profile_id:e.value
    ~noticed_at:(ctx.time_ctx.now_str ())
    ~status:e.title
  |> do_query ctx.db_ctx.db_uri
;;

let insert_failed_profile_update ctx ~request_id ~profile_id =
  [%rapper
    execute
      {sql|
INSERT INTO failed_profile_update(request_id, profile_id)
VALUES (%int64{request_id}, %string{profile_id})
|sql}]
    ~request_id
    ~profile_id
  |> do_query ctx.db_ctx.db_uri
;;

(* end *)

(* ***********|DB and HTTP operations|************ *)

let found_profiles (ctx : Db.context) (data : profile list) =
  data
  |> List.iter ~f:(fun (p : profile) ->
       insert_profile ctx p;
       p.location
       |> Option.value_map ~default:() ~f:(insert_profile_location ctx p.id))
;;

let deactivated_profiles (ctx : context) errors =
  errors |> List.iter ~f:(insert_deactivated_profile ctx)
;;

let process_body (ctx : context) ~body ~url =
  let users =
    try
      body |> Yojson.Safe.from_string |> users_of_yojson |> Option.return
    with
    | _ -> None
  in
  match users with
  | Some { data; errors } ->
    found_profiles ctx.db_ctx data;
    deactivated_profiles ctx (errors |> Option.value ~default:[])
  | None -> insert_failed_request ctx ~url ~code:500 ~body |> const ()
;;

let failed_profile_update ctx ~body ~url ~ids ~code =
  let request_id = insert_failed_request ctx ~url ~code ~body in
  ids
  |> List.iter ~f:(fun profile_id ->
       insert_failed_profile_update ctx ~request_id ~profile_id)
;;

(* end *)

let main (ctx : context) =
  let ids = profiles_to_update ctx.db_ctx in
  match ids with
  | [] -> ()
  | _ ->
    let url_t = ids |> users_query |> Request.build_uri users_endpoint in
    let url = url_t |> Uri.to_string in
    url_t
    |> ctx.request
    |> (function
    | None -> insert_failed_request ctx ~url ~code:500 ~body:"" |> const ()
    | Some (200, body) -> process_body ctx ~body ~url
    | Some (code, body) -> failed_profile_update ctx ~code ~body ~ids ~url)
;;
