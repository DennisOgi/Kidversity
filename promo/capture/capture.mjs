// Records real browser footage of Kidversity for the promo.
//
//   npm run capture                       # films ../build/promo_demo locally
//   BASE_URL=https://www.kidversity.app npm run capture   # films a live site
//
// The local demo build (flutter build web -t tool/promo_demo.dart
// -o build/promo_demo) is the real app with sample data, so signed-in pages
// can be filmed without an account. Clips land in public/footage as .webm,
// with public/footage/clips.json noting when each page finished loading so
// the video can skip the blank start.
import { createServer } from 'node:http';
import { readFile, mkdir, rename, writeFile, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const ROOT = resolve(import.meta.dirname, '..');
const OUT = join(ROOT, 'public', 'footage');
const BUILD = resolve(ROOT, '..', 'build', 'promo_demo');
const PORT = 4600;

const DESKTOP = { width: 1440, height: 900 };
const PHONE = { width: 390, height: 844 };

const types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wav': 'audio/wav',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};

function serve(dir) {
  const server = createServer(async (req, res) => {
    const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let file = join(dir, path === '/' ? 'index.html' : path);
    if (!existsSync(file)) file = join(dir, 'index.html');
    try {
      const body = await readFile(file);
      res.writeHead(200, {
        'content-type': types[extname(file)] ?? 'application/octet-stream',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  return new Promise((ok) => server.listen(PORT, () => ok(server)));
}

const pause = (ms) => new Promise((ok) => setTimeout(ok, ms));

/** Smooth, human-paced scroll with the mouse wheel. */
async function scroll(page, total, { steps = 40, every = 45 } = {}) {
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, total / steps);
    await pause(every);
  }
}

/**
 * One clip: a fresh browser context recording video, the page opened at
 * [path], then [act] runs the interaction. Returns seconds until the app's
 * first frame, so the edit can trim the loading screen.
 */
async function clip(browser, base, name, path, size, act, { mobile = false } = {}) {
  const context = await browser.newContext({
    viewport: size,
    deviceScaleFactor: 1,
    isMobile: mobile,
    hasTouch: mobile,
    recordVideo: { dir: OUT, size },
  });
  const page = await context.newPage();
  const started = Date.now();
  let readyAt = null;
  await page.exposeFunction('__promoReady', () => {
    readyAt ??= (Date.now() - started) / 1000;
  });
  await page.addInitScript(() => {
    window.addEventListener('flutter-first-frame', () => window.__promoReady());
  });
  await page.goto(`${base}/?view=${encodeURIComponent(path)}`);
  await page.waitForFunction(() => !document.getElementById('loading'), null, {
    timeout: 60000,
  });
  readyAt ??= (Date.now() - started) / 1000;
  // Let fonts, images and the first animations settle.
  await pause(1800);
  await page.mouse.move(size.width / 2, size.height / 2);
  await act(page);
  // A still of the last frame, to check clicks landed where intended.
  await mkdir(join(ROOT, 'capture', 'debug'), { recursive: true });
  await page.screenshot({ path: join(ROOT, 'capture', 'debug', `${name}.png`) });
  const video = page.video();
  await context.close();
  const target = join(OUT, `${name}.webm`);
  await rm(target, { force: true });
  await rename(await video.path(), target);
  console.log(`  ${name}.webm  (app ready after ${readyAt.toFixed(1)} s)`);
  return { name, readyAt: readyAt + 1.8 };
}

const base = process.env.BASE_URL?.replace(/\/$/, '');
await mkdir(OUT, { recursive: true });
const server = base ? null : await serve(BUILD);
const url = base ?? `http://localhost:${PORT}`;
console.log(`Filming ${url}`);

const browser = await chromium.launch();
const clips = [];
try {
  // Desktop -----------------------------------------------------------------
  clips.push(
    await clip(browser, url, 'landing', '/', DESKTOP, async (page) => {
      await pause(2500);
      await scroll(page, 900, { steps: 60, every: 40 });
      await pause(1500);
      await scroll(page, 1000, { steps: 60, every: 40 });
      await pause(1500);
    }),
  );
  clips.push(
    await clip(browser, url, 'student', '/student', DESKTOP, async (page) => {
      await pause(2500);
      await scroll(page, 700, { steps: 60, every: 45 });
      await pause(2000);
    }),
  );
  clips.push(
    await clip(browser, url, 'rope', '/rope', DESKTOP, async () => {
      await pause(13000);
    }),
  );
  clips.push(
    await clip(browser, url, 'teacher', '/teacher', DESKTOP, async (page) => {
      await pause(2500);
      await scroll(page, 600, { steps: 60, every: 45 });
      await pause(2000);
    }),
  );
  clips.push(
    await clip(browser, url, 'school', '/school', DESKTOP, async (page) => {
      await pause(3000);
      await scroll(page, 400, { steps: 50, every: 45 });
      await pause(1500);
    }),
  );
  clips.push(
    await clip(browser, url, 'school-teachers', '/school/teachers', DESKTOP, async (page) => {
      await pause(4000);
    }),
  );
  clips.push(
    await clip(browser, url, 'parent', '/parent', DESKTOP, async (page) => {
      await pause(3000);
      // The second child chip, "Kemi Okafor".
      await page.mouse.click(520, 291);
      await pause(2500);
    }),
  );
  clips.push(
    await clip(browser, url, 'onboarding', '/onboarding', DESKTOP, async (page) => {
      await pause(1500);
      // "I run a school" role card.
      await page.mouse.click(1064, 565);
      await pause(2500);
    }),
  );

  // Phone -------------------------------------------------------------------
  clips.push(
    await clip(
      browser,
      url,
      'phone-landing',
      '/',
      PHONE,
      async (page) => {
        await pause(2500);
        await scroll(page, 1400, { steps: 70, every: 45 });
        await pause(1500);
      },
      { mobile: true },
    ),
  );
  clips.push(
    await clip(
      browser,
      url,
      'phone-student',
      '/student',
      PHONE,
      async (page) => {
        await pause(2500);
        await scroll(page, 900, { steps: 60, every: 45 });
        await pause(1500);
      },
      { mobile: true },
    ),
  );
} finally {
  await browser.close();
  server?.close();
}

await writeFile(
  join(OUT, 'clips.json'),
  JSON.stringify(Object.fromEntries(clips.map((c) => [c.name, c.readyAt])), null, 2),
);
console.log('Done.');
