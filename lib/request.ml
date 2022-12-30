open! Core
open Io_layer
open Shared

let fmap f = Option.map ~f
let ( |. ) (a : 'x option) (f : 'x -> 'y) = a |> fmap f
let ( $ ) = Fn.compose

let rotate (xs : 'a list) =
  match xs with
  | [] -> []
  | y :: ys -> List.append ys [ y ]
;;

type id_record = { id : int64 }


let rotate_tokens (ctx : Db.context) =
  let ( + ) = Int64.( + ) in
  let ( - ) = Int64.( - ) in
  let token_ids =
    [%rapper
      get_many
        {sql|SELECT @int64{id} FROM token ORDER BY id ASC|sql}
        record_out]
      ()
    |> do_query ctx.db_uri
    |> List.map ~f:(fun { id } -> id)
  in
  let total = token_ids |> List.length |> Int64.of_int in
  let rt = token_ids |> rotate |> List.map ~f:(( + ) total) in
  let update = List.zip_exn token_ids rt in
  update
  |> List.iter ~f:(fun (curr_id, new_id) ->
       [%rapper
         execute
           {sql|UPDATE token SET id = %int64{new_id} WHERE id = %int64{curr_id}|sql}]
         ~new_id
         ~curr_id
       |> do_query ctx.db_uri);
  rt
  |> List.iter ~f:(fun curr_id ->
       [%rapper
         execute
           {sql|UPDATE token SET id = %int64{new_id} WHERE id = %int64{curr_id}|sql}]
         ~new_id:(curr_id - total)
         ~curr_id
       |> do_query ctx.db_uri)
;;

let%test "rotate" = rotate [ 0; 1; 2 ] |> List.equal Int.equal [ 1; 2; 0 ]

let build_uri (path : string) (qs : (string * string list) list) =
  List.fold qs ~init:(Uri.of_string path) ~f:Uri.add_query_param
;;

type bearer_record = { bearer : string }

let request_rotate (db_ctx : Db.context) (req : string -> int * string) =
  [%rapper
    get_many
      {sql|SELECT @string{bearer} FROM token ORDER BY id ASC|sql}
      record_out] ()
  |> do_query db_ctx.db_uri
  |> List.find_map
       ~f:
         ((function
           | 429, _ ->
             rotate_tokens db_ctx;
             None
           | code, body -> Some (code, body))
         $ req
         $ fun { bearer } -> bearer)
;;

let main_ctx time_ctx db_ctx (http_ctx : Http.context) =
  { request = (fun uri -> request_rotate db_ctx (http_ctx.get_with_auth uri))
  ; db_ctx
  ; time_ctx
  }
;;
