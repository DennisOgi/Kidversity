"""School-field backdrop for Rope Pull, rendered with the same orthographic
camera tilt as the character sprites. Distant props use forced perspective
(scaled down) so the ortho view still reads as depth.

usage: python scene.py <out_dir> [--preview]
"""
import json
import math
import os
import random
import sys

import bpy
import bmesh
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import toon as T  # noqa: E402

PITCH = 9.0
WIDTH_M = 8.4
HEIGHT_M = 5.2
CENTER_Z = 1.2
PX_PER_M = 343
rnd = random.Random(11)
OUT = 0.012


def box(name, size, mat, outline=OUT, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    ob = T.mesh_obj(name, bm, mat, outline, smooth=False)
    if bevel:
        m = ob.modifiers.new('bev', 'BEVEL')
        m.width = bevel
        m.segments = 2
        ob.modifiers.move(len(ob.modifiers) - 1, 0)
    return ob


def plane(name, x0, x1, y0, y1, z, mat):
    bm = bmesh.new()
    vs = [bm.verts.new((x0, y0, z)), bm.verts.new((x1, y0, z)),
          bm.verts.new((x1, y1, z)), bm.verts.new((x0, y1, z))]
    bm.faces.new(vs)
    return T.mesh_obj(name, bm, mat, 0, smooth=False)


def disc(name, r, mat, seg=20, sy=1.0, outline=0):
    bm = bmesh.new()
    vs = [bm.verts.new((math.cos(a) * r, math.sin(a) * r * sy, 0))
          for a in (2 * math.pi * i / seg for i in range(seg))]
    bm.faces.new(vs)
    return T.mesh_obj(name, bm, mat, outline, smooth=False)


def at(ob, x, y, z, scale=1.0, rz=0.0):
    ob.matrix_world = (Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, 'Z')
                       @ Matrix.Scale(scale, 4))
    return ob


def tree(x, y, k, kind='round'):
    trunk_m = T.toon('trunk', '#7A5236', 0.72)
    if kind == 'palm':
        h = 3.2
        segs = 7
        prev = Vector((x, y, 0))
        lean = rnd.uniform(-0.25, 0.25)
        for i in range(segs):
            t = (i + 1) / segs
            nxt = Vector((x + lean * t * t * h, y, h * t))
            seg = T.lathe('palm', T.capsule_profile((nxt - prev).length, 0.09 - 0.03 * t, 0.085 - 0.03 * t),
                          trunk_m, seg=12, outline=OUT * 0.8)
            T.place(seg, prev, nxt)
            for o in (seg,):
                o.matrix_world = Matrix.Translation(Vector((x, y, 0))) @ Matrix.Scale(k, 4) @ Matrix.Translation(-Vector((x, y, 0))) @ o.matrix_world
            prev = nxt
        top = prev
        leaf = T.toon('frond', '#3E9A48', 0.72)
        for j in range(8):
            a = j * math.pi * 2 / 8 + rnd.uniform(-0.2, 0.2)
            fr = T.ellipsoid('frond', 0.75, 0.13, 0.05, leaf, outline=OUT * 0.8, seg=16, rings=8)
            mw = (Matrix.Translation(top) @ Matrix.Rotation(a, 4, 'Z')
                  @ Matrix.Rotation(math.radians(28), 4, 'Y') @ Matrix.Translation((0.62, 0, 0)))
            fr.matrix_world = Matrix.Translation(Vector((x, y, 0))) @ Matrix.Scale(k, 4) @ Matrix.Translation(-Vector((x, y, 0))) @ mw
        return
    h = rnd.uniform(1.6, 2.2)
    tr = T.lathe('trunk', T.capsule_profile(h, 0.13, 0.09), trunk_m, seg=12, outline=OUT)
    T.place(tr, (x, y, 0), (x, y, h))
    tr.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Scale(k, 4) @ Matrix.Translation((-x, -y, 0)) @ tr.matrix_world
    shades = ['#3F9B4A', '#4BAA52', '#358A41']
    for i in range(9):
        r = rnd.uniform(0.6, 0.9)
        dx = rnd.uniform(-0.9, 0.9)
        dz = rnd.uniform(-0.2, 0.7)
        blob = T.ellipsoid('leaf', r, r * 0.9, r * 0.85, T.toon('leaf' + str(i % 3), shades[i % 3], 0.74),
                           outline=OUT, seg=20, rings=12)
        mw = Matrix.Translation((x + dx, y + rnd.uniform(-0.3, 0.3), h + 0.6 + dz))
        blob.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Scale(k, 4) @ Matrix.Translation((-x, -y, 0)) @ mw


def building(y, k):
    """Two-storey classroom block with a corridor, forced-perspective scale k."""
    wall = T.toon('wall', '#F6EEDC', 0.82)
    trim = T.toon('btrim', '#4B3BD6', 0.75)
    roof = T.toon('roof', '#56619F', 0.72)
    win = T.toon('window', '#2F3B78', 0.9)
    louv = T.toon('louver', '#9AA4D2', 0.9)
    col = T.toon('column', '#FFFFFF', 0.85)
    shade = T.toon('corridor', '#E2D6BD', 0.9)
    objs = []
    L = 22.0
    H1 = 3.0
    D = 6.0
    objs.append(at(box('block', (L, D, 2 * H1), wall), 0, y + D / 2 + 1.2, H1))
    objs.append(at(box('back', (L, 0.1, 2 * H1), shade, outline=0), 0, y + 1.15, H1))
    objs.append(at(box('slab', (L + 0.3, 1.6, 0.18), trim), 0, y + 0.45, H1))
    objs.append(at(box('eave', (L + 0.6, 1.8, 0.14), trim), 0, y + 0.45, 2 * H1))
    objs.append(at(box('rail', (L, 0.08, 0.7), trim, outline=OUT * 0.7), 0, y - 0.3, H1 + 0.35))
    bm = bmesh.new()
    w = L / 2 + 0.5
    pts = [(-w, -0.6, 0), (w, -0.6, 0), (w, D + 1.6, 0), (-w, D + 1.6, 0), (-w + 1.0, D / 2 + 0.5, 1.6), (w - 1.0, D / 2 + 0.5, 1.6)]
    vs = [bm.verts.new(q) for q in pts]
    bm.faces.new((vs[0], vs[1], vs[5], vs[4]))
    bm.faces.new((vs[3], vs[4], vs[5], vs[2]))
    bm.faces.new((vs[0], vs[4], vs[3]))
    bm.faces.new((vs[1], vs[2], vs[5]))
    objs.append(at(T.mesh_obj('roof', bm, roof, OUT, smooth=False), 0, y, 2 * H1 + 0.07))
    bay = 2.2
    n = int(L / bay)
    for i in range(n + 1):
        cx = -L / 2 + i * bay
        objs.append(at(box('col', (0.22, 0.22, 2 * H1), col, outline=OUT), cx, y - 0.3, H1))
    for f in range(2):
        z0 = f * H1
        for i in range(n):
            cx = -L / 2 + i * bay + bay / 2
            objs.append(at(box('win', (1.1, 0.06, 1.2), win, outline=OUT * 0.8), cx, y + 1.12, z0 + 1.55))
            for j in range(5):
                objs.append(at(box('louv', (1.0, 0.04, 0.07), louv, outline=0), cx, y + 1.06, z0 + 1.05 + j * 0.24))
            if i % 3 == 1:
                objs.append(at(box('door', (0.9, 0.06, 2.0), T.toon('door', '#13A3A0', 0.8), outline=OUT * 0.8), cx + 0.9, y + 1.12, z0 + 1.0))
    for ob in objs:
        ob.matrix_world = Matrix.Translation((0, y, 0)) @ Matrix.Scale(k, 4) @ Matrix.Translation((0, -y, 0)) @ ob.matrix_world


def bunting(y, z, x0, x1, k):
    cols = ['#4B3BD6', '#13A3A0', '#F5C56A', '#FFFFFF']
    pole = T.toon('pole', '#E9E4DA', 0.8)
    line = T.toon('string', '#5B5470', 0.8)
    for x in (x0, x1):
        p = T.lathe('pole', T.capsule_profile(z, 0.035, 0.03), pole, seg=10, outline=OUT * 0.8)
        T.place(p, (x, y, 0), (x, y, z))
    n = int((x1 - x0) / 0.32)
    prev = None
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        sag = 0.45 * (1 - (2 * t - 1) ** 2)
        pt = Vector((x, y, z - sag))
        if prev is not None:
            seg = T.lathe('str', T.capsule_profile((pt - prev).length, 0.01, 0.01), line, seg=6, outline=0)
            T.place(seg, prev, pt)
            mid = (prev + pt) / 2
            bm = bmesh.new()
            a = bm.verts.new((-0.11, 0, 0))
            b = bm.verts.new((0.11, 0, 0))
            c = bm.verts.new((0, 0, -0.26))
            bm.faces.new((a, b, c))
            fl = T.mesh_obj('flag', bm, T.toon('flag' + str(i % 4), cols[i % 4], 0.85, light=(0, -1, 0.3)), OUT * 0.6, smooth=False)
            fl.matrix_world = Matrix.Translation(mid) @ Matrix.Rotation(rnd.uniform(-0.15, 0.15), 4, 'Y')
        prev = pt


def cloud(x, z, k):
    m = T.toon('cloud', '#FFFFFF', 0.93, light=(0, -1, 1))
    for i in range(6):
        r = rnd.uniform(0.35, 0.6) * k
        b = T.ellipsoid('cloud', r * 1.3, r * 0.4, r, m, outline=0, seg=20, rings=10)
        at(b, x + (i - 2.5) * 0.45 * k, 20, z + rnd.uniform(-0.1, 0.25) * k)


def main():
    out_dir = sys.argv[1]
    preview = '--preview' in sys.argv
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rx = int(WIDTH_M * PX_PER_M)
    ry = int(HEIGHT_M * PX_PER_M)
    if preview:
        rx //= 3
        ry //= 3
    T.setup_render(rx, ry, samples=6 if preview else 16)
    s = bpy.context.scene
    s.render.film_transparent = False
    # sky gradient on the world background
    w = s.world
    nt = w.node_tree
    bg = nt.nodes['Background']
    bg.inputs[1].default_value = 1.0
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = T.srgb('#E8F5FA')
    ramp.color_ramp.elements[1].position = 0.6
    ramp.color_ramp.elements[1].color = T.srgb('#9FD3EE')
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value = 0.35
    mr.inputs['From Max'].default_value = 1.0
    nt.links.new(tc.outputs['Window'], sep.inputs[0])
    nt.links.new(sep.outputs['Y'], mr.inputs['Value'])
    nt.links.new(mr.outputs['Result'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])

    # ---- ground ---------------------------------------------------------
    grass_a = T.toon('grass_a', '#86C66B', 0.9, light=(0, -0.3, 1))
    grass_b = T.toon('grass_b', '#78BA5F', 0.9, light=(0, -0.3, 1))
    sand = T.toon('sand', '#D99A62', 0.9, light=(0, -0.3, 1))
    sand_d = T.flat('sand_d', '#C9864D')
    sand_l = T.flat('sand_l', '#E6AE7A')
    for i in range(-16, 8):
        plane('g', -8, 8, i * 0.9, (i + 1) * 0.9, 0, grass_a if i % 2 else grass_b)
    # sand court: rounded rectangle slightly above grass
    bm = bmesh.new()
    pts = []
    rx_, ry_, rr = 4.8, 3.0, 1.2
    for cx, cy, a0 in ((rx_ - rr, ry_ - rr, 0), (-rx_ + rr, ry_ - rr, 90), (-rx_ + rr, -ry_ + rr, 180), (rx_ - rr, -ry_ + rr, 270)):
        for j in range(9):
            a = math.radians(a0 + j * 90 / 8)
            pts.append(bm.verts.new((cx + math.cos(a) * rr, cy + math.sin(a) * rr, 0.004)))
    bm.faces.new(pts)
    court = T.mesh_obj('court', bm, sand, 0.0, smooth=False)
    at(court, 0, -0.4, 0)
    # darker edge rim
    bm = bmesh.new()
    pts2 = [bm.verts.new((p.co.x * 1.012, p.co.y * 1.03, 0.003)) for p in court.data.vertices]
    bm.faces.new(pts2)
    rim = T.mesh_obj('rim', bm, T.flat('rim', '#B8743F'), 0.0, smooth=False)
    at(rim, 0, -0.4, 0)
    for i in range(160):
        x = rnd.uniform(-4.3, 4.3)
        y = rnd.uniform(-3.2, 2.4)
        d = disc('spk', rnd.uniform(0.02, 0.06), sand_d if i % 3 else sand_l, sy=0.6)
        at(d, x, y, 0.006, rz=rnd.uniform(0, 3))
    for i in range(24):
        x = rnd.uniform(-4.2, 4.2)
        y = rnd.uniform(-3.0, 2.2)
        pb = T.ellipsoid('pebble', 0.04, 0.03, 0.02, T.toon('peb', '#A99A8B', 0.75), outline=0.006, seg=10, rings=6)
        at(pb, x, y, 0.01)
    # grass tufts along the court edge and field
    tuft = T.toon('tuft', '#5FA24E', 0.8)
    for i in range(70):
        x = rnd.uniform(-4.2, 4.2)
        y = rnd.choice([rnd.uniform(-9, -4.0), rnd.uniform(3.0, 5.8)])
        for j in range(3):
            bl = T.lathe('blade', [(0, 0.012), (0.08, 0.004), (0.1, 0.0005)], tuft, seg=5, outline=0)
            T.place(bl, (x + j * 0.02, y, 0), (x + j * 0.04 - 0.02, y, 0.1))

    # ---- mid ground -------------------------------------------------------
    wall = T.toon('lowwall', '#F1E6CC', 0.82)
    band = T.toon('wallband', '#4B3BD6', 0.75)
    at(box('lowwall', (20, 0.2, 0.42), wall), 0, 6.4, 0.21)
    at(box('wallcap', (20, 0.28, 0.06), band), 0, 6.4, 0.44)
    bunting(5.6, 1.9, -4.5, 4.5, 1)
    for x, kind, yy in ((-4.3, 'round', 7.2), (-3.0, 'palm', 6.9), (3.1, 'palm', 6.9), (4.4, 'round', 7.3),
                        (-5.6, 'round', 7.0), (5.6, 'palm', 7.0)):
        tree(x, yy, 0.62, kind)
    building(11.0, 0.3)
    for x, z in ((-3.4, 0.45), (0.2, 0.75), (3.5, 0.5), (-1.6, 0.85), (2.0, 0.95)):
        cloud(x, z, 1.0)

    # ---- camera -----------------------------------------------------------
    cam_data = bpy.data.cameras.new('cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = WIDTH_M
    cam = bpy.data.objects.new('cam', cam_data)
    s.collection.objects.link(cam)
    p = math.radians(PITCH)
    d = Vector((0, math.cos(p), -math.sin(p)))
    cam.location = Vector((0, 0, CENTER_Z)) - d * 30
    cam.rotation_euler = (math.radians(90) - p, 0, 0)
    cam_data.clip_end = 200
    s.camera = cam
    bpy.context.view_layer.update()
    c = world_to_camera_view(s, cam, Vector((0, 0, 0)))
    meta = {'width': rx, 'height': ry, 'px_per_m': rx / WIDTH_M,
            'ground': [round(c.x * rx, 2), round((1 - c.y) * ry, 2)]}
    s.render.filepath = os.path.join(out_dir, 'court.png')
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(out_dir, 'court.json'), 'w') as f:
        json.dump(meta, f)
    print('done', meta)


if __name__ == '__main__':
    main()
