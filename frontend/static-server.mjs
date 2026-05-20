import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve } from "node:path";

const root = resolve(process.cwd());
const port = Number(process.env.PORT || 4173);

const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
};

const server = createServer((req, res) => {
  const url = new URL(req.url || "/", `http://127.0.0.1:${port}`);
  const requested = normalize(decodeURIComponent(url.pathname)).replace(/^[/\\]+/, "");
  let file = resolve(join(root, requested || "index.html"));

  if (!file.startsWith(root)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  if (!existsSync(file)) {
    file = resolve(join(root, "index.html"));
  }

  if (statSync(file).isDirectory()) {
    file = join(file, "index.html");
  }

  res.writeHead(200, {
    "Content-Type": types[extname(file)] || "application/octet-stream",
    "Cache-Control": "no-store",
  });
  createReadStream(file).pipe(res);
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.log(`SUN/MOON static preview already running: http://127.0.0.1:${port}`);
    process.exit(0);
  }
  throw error;
});

server.listen(port, "127.0.0.1", () => {
  console.log(`SUN/MOON static preview: http://127.0.0.1:${port}`);
});
