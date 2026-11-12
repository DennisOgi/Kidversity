import os
WORK = os.environ.get('ROPE_PULL_WORK', 'rp_work')  # scratch folder for renders
"""Python port of lib/widgets/rope_arena.dart's painter, used to preview the
arena as animated GIFs at phone / tablet / classroom sizes."""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else f'{WORK}/out'
kids = json.load(open(f'{ROOT}/kids.json'))
COURT = dict(width=2881.0, height=1783.0, ppm=342.976, gx=1440.5, gy=1298.0)
BG = Image.open(f'{WORK}/scn/court.png').convert('RGBA')
SHEETS = {k: Image.open(f'{ROOT}/{k}.png').convert('RGBA') for k in kids['kids']}
CELL = kids['cell']
COLS = kids['cols']
CPPM = CELL / 1.9
MINW, MINH, VCEN = 5.6, 3.4, 0.9
ROOTS = {'indigo-partner': -1.75, 'indigo-captain': -0.72, 'teal-captain': 0.72, 'teal-partner': 1.75}
MAXSHIFT = 0.55
ORDER = ['indigo-partner', 'teal-partner', 'indigo-captain', 'teal-captain']
OFFS = {'indigo-partner': 0.37, 'teal-captain': 0.19, 'teal-partner': 0.53, 'indigo-captain': 0.0}
INDIGO = (68, 51, 204)
TEAL = (20, 125, 133)
SS = 2  # supersample
_bg_cache = {}


class State:
    phase = 'playing'
    clock = 0.0
    position = 0.0
    impact_team = None
    impact_at = -100
    impact_correct = True
    winner = None
    finished_at = -100


def impulse(st, team):
    age = st.clock - st.impact_at
    if age < 0 or age >= .65 or st.impact_team != team:
        return 0
    return math.sin(age / .65 * math.pi)


def clip(st, kid, team):
    other = 'teal' if team == 'indigo' else 'indigo'
    t = st.clock + OFFS[kid]
    once = False
    since = t
    fps = 9
    if st.phase == 'finished':
        if st.winner is None:
            name = 'idle'
        else:
            name = 'win' if st.winner == team else 'lose'
            once, fps, since = True, 12, st.clock - st.finished_at
    elif st.phase == 'playing':
        losing = st.position > 0.45 if team == 'indigo' else st.position < -0.45
        yanked = st.impact_correct and impulse(st, other) > 0.05
        heave = st.impact_correct and impulse(st, team) > 0.05
        name = 'slip' if (losing or yanked) and not heave else 'pull'
        fps = 16 if heave else 9
    else:
        name, fps = 'idle', 6
    frames = kids['kids'][kid]['states'][name]
    i = int(max(0, since) * fps)
    if once and i >= len(frames):
        i = len(frames) - 4 + ((i - len(frames)) // 2) % 4
    return frames[i % len(frames)]


def render(W, H, st):
    W2, H2 = W * SS, H * SS
    k = min(W2 / MINW, H2 / MINH)
    k = max(k, W2 / (COURT['width'] / COURT['ppm']))
    half = H2 / (2 * k)
    vb = -(COURT['height'] - COURT['gy']) / COURT['ppm']
    vt = COURT['gy'] / COURT['ppm']
    lo, hi = vb + half, vt - half
    vc = (lo + hi) / 2 if lo > hi else min(max(VCEN, lo), hi)

    def S(x, v):
        return (W2 / 2 + x * k, H2 / 2 - (v - vc) * k)

    key = (W, H)
    if key not in _bg_cache:
        img = Image.new('RGBA', (W2, H2))
        s = k / COURT['ppm']
        gx, gy = S(0, 0)
        bgs = BG.resize((round(COURT['width'] * s), round(COURT['height'] * s)), Image.LANCZOS)
        img.alpha_composite(bgs, (round(gx - COURT['gx'] * s), round(gy - COURT['gy'] * s)))
        d = ImageDraw.Draw(img)
        wl = max(2, round(k * 0.03))
        d.line([S(0, 0.5), S(0, -0.55)], fill=(255, 255, 255, 235), width=round(wl * 1.4))
        for x, col in ((-MAXSHIFT, INDIGO), (MAXSHIFT, TEAL)):
            light = tuple(round(c + (255 - c) * .35) for c in col) + (242,)
            top, bot = S(x, 0.5), S(x, -0.55)
            y = top[1]
            while y < bot[1]:
                d.line([(top[0], y), (top[0], min(y + k * .07, bot[1]))], fill=light, width=wl)
                y += k * .12
            bx, by = S(x, -0.59)
            h, w = k * 0.17, k * 0.075
            d.polygon([(bx - w, by), (bx + w, by), (bx, by - h)], fill=col + (255,), outline=(18, 15, 34, 255))
            d.line([(bx - w * .55, by - h * .38), (bx + w * .55, by - h * .38)], fill=(255, 255, 255, 255), width=max(2, round(k * .018)))
        _bg_cache[key] = img
    img = _bg_cache[key].copy()
    shift = st.position * MAXSHIFT
    d = ImageDraw.Draw(img)
    finished = st.phase == 'finished'
    thick = max(4, 0.045 * k)
    if finished:
        pts = [S(-2.3 + 4.6 * i / 40 + shift, -0.12 + math.sin(i * .7) * .025) for i in range(41)]
        d.line(pts, fill=(74, 48, 22, 255), width=round(thick + 3), joint='curve')
        d.line(pts, fill=(217, 183, 126, 255), width=round(thick), joint='curve')
    grips = []
    sc = k / CPPM
    for kid in ORDER:
        team = 'teal' if kid.startswith('teal') else 'indigo'
        flip = team == 'teal'
        meta = kids['kids'][kid]
        idx = clip(st, kid, team)
        fr = meta['frames'][idx]
        ax, ay = meta['anchor']
        rx, ry = S(ROOTS[kid] + shift, 0)
        dirx = -1 if flip else 1

        def ts(p):
            return (rx + dirx * (p[0] - ax) * sc, ry + (p[1] - ay) * sc)
        feet = [ts(p) for p in fr['f']]
        l = min(f[0] for f in feet) - .12 * k
        r = max(f[0] for f in feet) + .12 * k
        sh = Image.new('RGBA', img.size)
        ImageDraw.Draw(sh).ellipse((l, ry - .05 * k, r, ry + .05 * k), fill=(90, 46, 16, 75))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(.02 * k + 1)))
        cell = SHEETS[kid].crop(((idx % COLS) * CELL, (idx // COLS) * CELL, (idx % COLS + 1) * CELL, (idx // COLS + 1) * CELL))
        if flip:
            cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
            ax2 = CELL - ax
        else:
            ax2 = ax
        size = max(1, round(CELL * sc))
        cs = cell.resize((size, size), Image.LANCZOS)
        img.alpha_composite(cs, (round(rx - ax2 * sc), round(ry - ay * sc)))
        if fr['g']:
            g = [ts(p) for p in fr['g']]
            grips.append((sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g)))
    d = ImageDraw.Draw(img)
    if not finished and len(grips) >= 2:
        grips.sort()
        td = .16 * k
        f0, f1 = grips[0], grips[-1]
        pts = [(f0[0] - .42 * k, f0[1] + td * 1.6), (f0[0] - .2 * k, f0[1] + td * .45)] + grips + \
              [(f1[0] + .2 * k, f1[1] + td * .45), (f1[0] + .42 * k, f1[1] + td * 1.6)]
        sag = (1 - abs(st.position)) * .02 * k
        path = []
        for i in range(len(pts) - 1):
            p0 = pts[i - 1] if i else pts[i]
            p1, p2 = pts[i], pts[i + 1]
            p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1]
            dip = sag if p2[0] - p1[0] > .6 * k else 0
            c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6 + dip)
            c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6 + dip)
            for j in range(12):
                t = j / 12
                u = 1 - t
                path.append((u ** 3 * p1[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * p2[0],
                             u ** 3 * p1[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * p2[1]))
        path.append(pts[-1])
        d.line(path, fill=(74, 48, 22, 255), width=round(thick + max(3, thick * .35)), joint='curve')
        d.line(path, fill=(217, 183, 126, 255), width=round(thick), joint='curve')
        d.line([(x, y - thick * .22) for x, y in path], fill=(241, 221, 177, 255), width=max(1, round(thick * .28)))
        acc = 0
        cx = S(shift, 0)[0]
        centre = None
        for a, b in zip(path, path[1:]):
            seg = math.dist(a, b)
            if seg == 0:
                continue
            vx, vy = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
            nx, ny = -vy, vx
            while acc < seg:
                px, py = a[0] + vx * acc, a[1] + vy * acc
                d.line([(px + nx * thick * .42 - vx * thick * .25, py + ny * thick * .42 - vy * thick * .25),
                        (px - nx * thick * .42 + vx * thick * .25, py - ny * thick * .42 + vy * thick * .25)],
                       fill=(156, 116, 64, 255), width=max(1, round(thick * .16)))
                if centre is None and px >= cx:
                    centre = (px, py)
                acc += max(5, thick * .9)
            acc -= seg
        at = centre or S(shift, .8)
        w, h = max(5, .07 * k), max(10, .2 * k)
        d.polygon([(at[0] - w * .5, at[1]), (at[0] + w * .5, at[1]), (at[0] + w * .8, at[1] + h), (at[0], at[1] + h * .78), (at[0] - w * .8, at[1] + h)],
                  fill=(245, 197, 106, 255), outline=(107, 74, 18, 255))
        d.ellipse((at[0] - thick * .7, at[1] - thick * .7, at[0] + thick * .7, at[1] + thick * .7), fill=(176, 57, 31, 255))
    return img.resize((W, H), Image.LANCZOS).convert('RGB')


def story(W, H, out, seconds=6.0, fps=12):
    """Lobby, a few Indigo pulls that move the line, then Indigo wins."""
    st = State()
    frames = []
    n = int(seconds * fps)
    for i in range(n):
        t = i / fps
        st.clock = t
        if t < 0.8:
            st.phase = 'lobby'
        elif t < 4.4:
            st.phase = 'playing'
            for at, team in ((1.2, 'indigo'), (2.2, 'teal'), (3.0, 'indigo'), (3.7, 'indigo')):
                if t >= at:
                    st.impact_team, st.impact_at = team, at
            target = 0.0
            for at, d in ((1.2, -0.35), (2.2, 0.25), (3.0, -0.4), (3.7, -0.45)):
                if t >= at:
                    target += d
            st.position += (target - st.position) * (1 - math.exp(-(1 / fps) * 10))
        else:
            if st.phase != 'finished':
                st.finished_at = t
            st.phase = 'finished'
            st.winner = 'indigo'
        frames.append(render(W, H, st).convert('P', palette=Image.ADAPTIVE, colors=255))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)


if __name__ == '__main__':
    for W, H, name in ((360, 277, 'phone'), (720, 424, 'tablet'), (1200, 571, 'classroom')):
        story(W, H, f'/tmp/rope_{name}.gif')
        print('ok', name)
