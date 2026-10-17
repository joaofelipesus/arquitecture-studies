import http from "k6/http";
import exec from "k6/execution";
import { check } from "k6";
import { SharedArray } from "k6/data";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";
const HEADERS = { "Content-Type": "application/json", Accept: "application/json" };
// A request still waiting after this long fails as a timeout (k6's default is 60s). Keep it below nginx's
// proxy_read_timeout (config/nginx/nginx.conf), or slow requests fail as nginx 504s instead.
const REQUEST_TIMEOUT = __ENV.REQUEST_TIMEOUT || "120s";

// Real rows sampled from the database by k6/prepare_data.sh.
const data = new SharedArray("data", () => [JSON.parse(open("../data/data.json"))])[0];

// Steps the load up from 100 to 1000 requests per second, 100 at a time, holding each step for STEP_DURATION.
const STEP_DURATION = "10s";
const STAGES = [];
for (let rate = 100; rate <= 1000; rate += 100) {
  STAGES.push({ target: rate, duration: "1s" }, { target: rate, duration: STEP_DURATION });
}

export const options = {
  scenarios: {
    mixed: {
      executor: "ramping-arrival-rate",
      startRate: 100,
      timeUnit: "1s",
      stages: STAGES,
      preAllocatedVUs: 200,
      maxVUs: 1000,
    },
  },
  // Drops the url tag (one series per id) so requests are grouped by the `name` tag set on each call.
  systemTags: ["status", "method", "name", "scenario", "expected_response", "check"],
  // Response time is only reported, not enforced: the load keeps stepping up however slow the app gets, and the
  // run stops early once the server is down, i.e. more than 10% of requests fail (errors or REQUEST_TIMEOUT).
  thresholds: {
    http_req_failed: [{ threshold: "rate<0.1", abortOnFail: true, delayAbortEval: "10s" }],
  },
};

const sample = (list) => list[Math.floor(Math.random() * list.length)];

function createBook() {
  const title = `k6 Book ${exec.scenario.iterationInTest}-${Date.now()}`;
  const res = http.post(
    `${BASE_URL}/books`,
    JSON.stringify({
      book: {
        title,
        description: "Created by the k6 load test.",
        release_date: "2024-01-01",
        total_pages: 320,
        author_name: "k6 Author",
        subject_names: ["Load Testing"],
      },
    }),
    { headers: HEADERS, timeout: REQUEST_TIMEOUT, tags: { name: "POST /books" } },
  );
  check(res, { "books create: 201": (r) => r.status === 201 });
}

function searchBooks() {
  const res = http.get(`${BASE_URL}/books/search?title=${encodeURIComponent(sample(data.book_titles))}`, {
    headers: HEADERS,
    timeout: REQUEST_TIMEOUT,
    tags: { name: "GET /books/search" },
  });
  check(res, { "books search: 200": (r) => r.status === 200 });
}

function showBook() {
  const res = http.get(`${BASE_URL}/books/${sample(data.book_ids)}`, {
    headers: HEADERS,
    timeout: REQUEST_TIMEOUT,
    tags: { name: "GET /books/:id" },
  });
  check(res, { "books show: 200": (r) => r.status === 200 });
}

function searchUsers() {
  const res = http.get(`${BASE_URL}/users/search?username=${encodeURIComponent(sample(data.usernames))}`, {
    headers: HEADERS,
    timeout: REQUEST_TIMEOUT,
    tags: { name: "GET /users/search" },
  });
  check(res, { "users search: 200": (r) => r.status === 200 });
}

function showUser() {
  const res = http.get(`${BASE_URL}/users/${sample(data.user_ids)}`, {
    headers: HEADERS,
    timeout: REQUEST_TIMEOUT,
    tags: { name: "GET /users/:id" },
  });
  check(res, { "users show: 200": (r) => r.status === 200 });
}

function createUserBook() {
  // Each iteration takes its own (user, book) pair so no two requests collide on the uniqueness validation.
  const pair = data.new_user_books[exec.scenario.iterationInTest % data.new_user_books.length];
  const res = http.post(`${BASE_URL}/user_books`, JSON.stringify({ user_book: pair }), {
    headers: HEADERS,
    timeout: REQUEST_TIMEOUT,
    tags: { name: "POST /user_books" },
  });
  check(res, { "user_books create: 201": (r) => r.status === 201 });
}

function updateProgress() {
  const userBook = sample(data.user_books);
  const currentPage = Math.floor(Math.random() * (userBook.total_pages + 1));
  const res = http.patch(
    `${BASE_URL}/user_books/${userBook.id}/update_progress`,
    JSON.stringify({ user_book: { current_page: currentPage } }),
    { headers: HEADERS, timeout: REQUEST_TIMEOUT, tags: { name: "PATCH /user_books/:id/update_progress" } },
  );
  check(res, { "user_books update_progress: 200": (r) => r.status === 200 });
}

// Relative weights: each iteration runs one action, picked at random with this distribution.
const ACTIONS = [
  [createBook, 0.2],
  [searchBooks, 0.2],
  [showBook, 0.1],
  [searchUsers, 0.1],
  [showUser, 0.2],
  [createUserBook, 0.1],
  [updateProgress, 0.3],
];
const TOTAL_WEIGHT = ACTIONS.reduce((sum, [, weight]) => sum + weight, 0);

export default function () {
  let roll = Math.random() * TOTAL_WEIGHT;
  for (const [action, weight] of ACTIONS) {
    roll -= weight;
    if (roll < 0) return action();
  }
  ACTIONS[ACTIONS.length - 1][0]();
}
