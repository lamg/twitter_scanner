# Twitter Scanner

Given:
- Twitter API token. You can get it [here](https://developer.twitter.com/en/portal/projects-and-apps)
- SQLite database with the proper schema and initialization

Does:
- Searches tweets given a query, like `#SOSCuba`.
- Gets the user profiles which created the above tweets
- Scans the timelines of selected users

### Install OCaml

Install and initialize [opam](https://ocaml.org/docs/up-and-running), then

```
opam update
opam switch create 5.0.0
```

### Install `twitter_scanner`

``` sh
git clone https://github.com/lamg/io_layer
opam pin add ./io_layer
git clone https://github.com/lamg/twitter_scanner
cd twitter_scanner
dune build
dune install
cd database
# edit init.sql and replace the bearer value with a proper Twitter API token
sh init_db.sh
```

### Usage

Now you just need to run in the above mentioned `database` directory

``` sh
twitter_scanner
```

### Troubleshooting

For a summary of failed operations
``` sh
echo 'select performed_at, code, body from failed_request order by performed_at desc limit 10' | sqlite3 db.sqlite3
```

Example output:

```
2022-12-25T17:00:51.629603Z|401|{
  "title": "Unauthorized",
  "type": "about:blank",
  "status": 401,
  "detail": "Unauthorized"
}
```

The above means that the the bearer token is not valid.

### Querying results

For a summary of results in the latest scan:

``` sh
echo '
select q.tweet_query, max(s.scan_date), s.amount
from scanning s, query q
where s.query_id = q.id
group by s.query_id
order by amount desc;' | sqlite3 db.sqlite3
```

For more queries see [queries.org](./database/queries.org)
