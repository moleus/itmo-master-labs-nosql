// Same load in all phases. The header X-User-Id is always sent;
// the web flag decides if the server uses it.
import http from "k6/http";

const RPS = Number(__ENV.RPS || 400);
const POOL = Number(__ENV.USER_POOL || 1000000);
const TARGETS = (__ENV.TARGETS || "http://web1:8080,http://web2:8080").split(",");
const PATHS = ["/api/items", "/api/orders", "/api/search", "/api/cart"];

export const options = {
  discardResponseBodies: true,
  scenarios: {
    steady: {
      executor: "constant-arrival-rate",
      rate: RPS,
      timeUnit: "1s",
      duration: __ENV.DURATION || "3h",
      preAllocatedVUs: 50,
      maxVUs: 400,
    },
  },
};

export default function () {
  const base = TARGETS[__ITER % TARGETS.length];
  const path = PATHS[Math.floor(Math.random() * PATHS.length)];
  const user = "u" + (1 + Math.floor(Math.random() * POOL));
  http.get(base + path, {
    headers: { "X-User-Id": user },
    tags: { name: path },
  });
}
