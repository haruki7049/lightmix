import { toSSG } from "hono/bun";
import app from "./src/index.tsx";

toSSG(app)
