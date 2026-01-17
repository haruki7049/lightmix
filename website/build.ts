import { toSSG } from "hono/bun";
import app from "./src/main.ts";

toSSG(app)
