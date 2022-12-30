-- table with hashtags (queries) and the date when monitoring them started
INSERT INTO query(id, tweet_query, start_date)
VALUES
(0, '#SOSCuba', '2023-01-01'),
(1, '#VamosConTodo', '2023-01-01');

INSERT INTO token(id, bearer, app_name, tweets_per_month, ref_date)
VALUES
(0, 'AAAAAAxxxxxxxxxxxxxxxx99999999', 'project0', 500000, '2023-01-01');
