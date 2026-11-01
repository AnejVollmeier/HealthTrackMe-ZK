import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "1m", target: 5 },
    { duration: "1m", target: 10 },
    { duration: "1m", target: 20 },
    { duration: "1m", target: 20 },
    { duration: "1m", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<1000"],
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
  },
};

const baseUrl = "http://localhost:8080";
const token = __ENV.TEST_JWT;
const userId = __ENV.TEST_USER_ID;

export default function () {
  if (!token || !userId) {
    throw new Error("Manjkata TEST_JWT ali TEST_USER_ID");
  }

  const response = http.get(`${baseUrl}/api/v1/medicines/users/${userId}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
    tags: { name: "GET_medicines" },
  });

  check(response, {
    "HTTP status 200": (r) => r.status === 200,
    "uspesen odgovor in 3 zdravila": (r) => {
      try {
        const body = r.json();
        return (
          body.success === true &&
          Array.isArray(body.data) &&
          body.data.length === 3
        );
      } catch {
        return false;
      }
    },
  });

  sleep(1);
}
