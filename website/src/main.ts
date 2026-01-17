import { Hono } from 'hono';
import { serveStatic } from "hono/bun";
import type { FC } from "hono/jsx";
import index from "./pages/index.tsx";

const app = new Hono()

app.route("/", index);

export default app
