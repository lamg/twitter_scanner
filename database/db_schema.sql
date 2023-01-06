CREATE TABLE query (
  id integer NOT NULL,
  tweet_query text NOT NULL,
  start_date text NOT NULL
);

-- association between a tweet and the query that found it
CREATE TABLE query_tweet (
  query_id integer NOT NULL,
  tweet_id text NOT NULL,
  seen integer NOT NULL,
  UNIQUE (query_id, tweet_id)
);

-- fields common to all kinds of tweets
CREATE TABLE base_tweet (
  id text NOT NULL,
  author_id text NOT NULL,
  created_at text NOT NULL,
  UNIQUE (id)
);

-- original tweets (i.e. not retweeted or cited)
CREATE TABLE original_tweet (
  id text NOT NULL,
  tweet_text text NOT NULL,
  UNIQUE (id)
);

CREATE TABLE reference_tweet (
  id text NOT NULL,
  reference_id text NOT NULL,
  reference_type text NOT NULL,
  UNIQUE (id)
);

CREATE TABLE tweet_source(
id TEXT NOT NULL,
source TEXT NOT NULL
);

--
-- record of scans section
-- how many tweets returned a query at a point in time
CREATE TABLE scanning (
  query_id integer NOT NULL,
  scan_date text NOT NULL,
  amount integer NOT NULL,
  UNIQUE(query_id)
);

--
CREATE TABLE failed_request (
  id INTEGER NOT NULL,
  performed_at TEXT NOT NULL,
  url TEXT NOT NULL,
  code INTEGER NOT NULL,
  body TEXT NOT NULL
);

CREATE TABLE failed_decode (
  request_id INTEGER NOT NULL
);

CREATE TABLE failed_profile_update(
request_id INTEGER NOT NULL,
profile_id TEXT NOT NULL
);

CREATE TABLE failed_query(
query_id INTEGER NOT NULL,
request_id INTEGER NOT NULL
);

-- profiles section
CREATE TABLE profile (
  id text NOT NULL,
  name text NOT NULL,
  created_at text NOT NULL,
  username text NOT NULL,
  UNIQUE (id)
);


CREATE TABLE profile_location (
  profile_id text NOT NULL,
  location text NOT NULL,
  UNIQUE (profile_id)
);

CREATE TABLE watched_profile (
  id text NOT NULL,
  started_at text NOT NULL,
  UNIQUE (id)
);

CREATE TABLE oldest_timeline_tweet (
  profile_id text NOT NULL,
  tweet_id text NOT NULL,
  UNIQUE (profile_id)
);

-- view for creating a batch of the next profiles to be updated
CREATE VIEW update_profile_batch AS
SELECT
  0 AS id,
  profile_id
FROM
  profiles_to_update
LIMIT 100;

--
CREATE VIEW profiles_to_update AS
SELECT
  author_id AS profile_id
FROM
  base_tweet
WHERE
  author_id NOT IN (
    SELECT
      id
    FROM
      profile)
  AND author_id NOT IN (
    SELECT
      profile_id
    FROM
      profile_deactivated);

-- profile whose information couldn't be retrieved as part of an update
CREATE TABLE profile_deactivated (
  profile_id text NOT NULL,
  noticed_at text NOT NULL,
  status text NOT NULL,
  UNIQUE (profile_id)
);

-- configuration section
CREATE TABLE token (
  id integer NOT NULL,
  bearer text NOT NULL,
  app_name text NOT NULL,
  tweets_per_month integer NOT NULL,
  ref_date text NOT NULL,
  UNIQUE (id)
);

-- frontend data

CREATE VIEW tweets_by_query_view AS
SELECT q.tweet_query, count(t.tweet_id) AS total
FROM query_tweet t, query q
WHERE q.id = t.query_id
GROUP BY q.id
ORDER BY total DESC;


CREATE VIEW query_authors_by_age_view AS
SELECT
  q.tweet_query,
  CAST(
    AVG(julianday('now') - julianday(p.created_at)) AS INTEGER
  ) AS age
FROM
  profile p,
  base_tweet t,
  query_tweet qt,
  query q
WHERE
  p.id = t.author_id and qt.tweet_id = t.id and q.id = qt.query_id
GROUP BY
  qt.query_id
ORDER BY
  age DESC;

CREATE VIEW base_tweet_query AS
SELECT t.id AS tweet_id, t.author_id, t.created_at, q.id AS query_id , q.tweet_query FROM
base_tweet t, query_tweet qt, query q
WHERE q.id = qt.query_id AND qt.tweet_id = t.id;

CREATE TABLE watched_profile_creation_by_query (query_id INTEGER NOT NULL);

CREATE VIEW profiles_created_by_query AS
SELECT
t.tweet_query,
cast(strftime('%Y',date(p.created_at)) AS INTEGER) AS year,
cast(strftime('%m',date(p.created_at)) AS INTEGER) AS month,
count(p.id) AS total
FROM base_tweet_query t, profile p, watched_profile_creation_by_query w
WHERE t.query_id = w.query_id AND p.id = t.author_id
GROUP BY w.query_id, year, month
ORDER BY w.query_id, year, month ASC;


-- indexes
CREATE INDEX IF NOT EXISTS query_id ON query(id);

CREATE INDEX IF NOT EXISTS query_tweet_tweet_id ON query_tweet(tweet_id);

CREATE INDEX IF NOT EXISTS base_tweet_id_index ON base_tweet(id);
CREATE INDEX IF NOT EXISTS base_tweet_created_at_index ON base_tweet(created_at);

CREATE INDEX IF NOT EXISTS original_tweet_id ON original_tweet(id);

CREATE INDEX IF NOT EXISTS reference_tweet_id ON reference_tweet(id);
CREATE INDEX IF NOT EXISTS reference_tweet_reference_id ON reference_tweet(reference_id);


CREATE INDEX IF NOT EXISTS scanning_scan_date ON scanning(scan_date);
CREATE INDEX IF NOT EXISTS scanning_query_id ON scanning(id_query);


CREATE INDEX IF NOT EXISTS profile_id ON profile(id);
CREATE INDEX IF NOT EXISTS profile_created_at ON profile(created_at);


CREATE INDEX IF NOT EXISTS profile_id ON profile_location(profile_id);
