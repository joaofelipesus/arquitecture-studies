-- Samples real rows from the development database for the k6 tests (see k6/prepare_data.sh).
WITH
  sample_books AS (SELECT id, title FROM books ORDER BY random() LIMIT 2000),
  sample_users AS (SELECT id, username FROM users ORDER BY random() LIMIT 1000),
  sample_user_books AS (
    SELECT user_books.id, books.total_pages
    FROM user_books JOIN books ON books.id = user_books.book_id
    ORDER BY random() LIMIT 2000
  ),
  -- (user, book) pairs with no reading yet, so user_books create doesn't hit the uniqueness validation.
  -- Each sampled book goes to one user (round robin), so the pairs are distinct.
  random_books AS (SELECT id, row_number() OVER () - 1 AS n FROM (SELECT id FROM books ORDER BY random() LIMIT 10000) b),
  numbered_users AS (SELECT id, row_number() OVER (ORDER BY id) - 1 AS n, count(*) OVER () AS total FROM users),
  new_user_books AS (
    SELECT u.id AS user_id, b.id AS book_id
    FROM random_books b JOIN numbered_users u ON u.n = b.n % u.total
    WHERE NOT EXISTS (SELECT 1 FROM user_books ub WHERE ub.user_id = u.id AND ub.book_id = b.id)
  )
SELECT json_build_object(
  'book_ids',      (SELECT json_agg(id) FROM sample_books),
  'book_titles',   (SELECT json_agg(title) FROM sample_books),
  'user_ids',      (SELECT json_agg(id) FROM sample_users),
  'usernames',     (SELECT json_agg(username) FROM sample_users),
  'user_books',    (SELECT json_agg(json_build_object('id', id, 'total_pages', total_pages)) FROM sample_user_books),
  'new_user_books', (SELECT json_agg(json_build_object('user_id', user_id, 'book_id', book_id) ORDER BY random()) FROM new_user_books)
);
