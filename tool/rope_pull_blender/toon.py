"""Shared helpers: flat toon materials for Cycles, inverted-hull outlines,
lathe meshes. Everything renders as emission so frames are quick on CPU
and colours stay exactly on palette (view transform Standard)."""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

LIGHT = Vector((-0.45, -0.75, 0.85)).normalized()
OUTLINE_RGB = (0.07, 0.06, 0.13)


def srgb(hexstr):
    h = hexstr.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


_mats = {}


def toon(name, hexcol, shade=0.74, rim=0.0, light=None):
    key = (name, hexcol, shade, rim, tuple(light) if light else None)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    dot = nt.nodes.new('ShaderNodeVectorMath')
    dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = tuple(light or LIGHT)
    nt.links.new(geo.outputs['Normal'], dot.inputs[0])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'CONSTANT'
    e = ramp.color_ramp.elements
    e[0].position = 0.0
    e[0].color = (shade, shade, shade, 1)
    e[1].position = 0.38
    e[1].color = (1, 1, 1, 1)
    hi = e.new(0.93)
    hi.color = (1.06, 1.06, 1.06, 1)
    # map dot [-1,1] -> [0,1]
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value = -1
    mr.inputs['From Max'].default_value = 1
    nt.links.new(dot.outputs['Value'], mr.inputs['Value'])
    nt.links.new(mr.outputs['Result'], ramp.inputs['Fac'])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1
    mul.inputs[6].default_value = srgb(hexcol)
    nt.links.new(ramp.outputs['Color'], mul.inputs[7])
    col = mul.outputs[2]
    if rim > 0:
        # Soft rim on the side away from the light keeps forms readable.
        fres = nt.nodes.new('ShaderNodeLayerWeight')
        fres.inputs['Blend'].default_value = 0.35
        rr = nt.nodes.new('ShaderNodeValToRGB')
        rr.color_ramp.interpolation = 'CONSTANT'
        rr.color_ramp.elements[0].color = (0, 0, 0, 1)
        rr.color_ramp.elements[1].position = 0.72
        rr.color_ramp.elements[1].color = (rim, rim, rim, 1)
        nt.links.new(fres.outputs['Facing'], rr.inputs['Fac'])
        add = nt.nodes.new('ShaderNodeMix')
        add.data_type = 'RGBA'
        add.blend_type = 'ADD'
        add.inputs['Factor'].default_value = 1
        nt.links.new(col, add.inputs[6])
        nt.links.new(rr.outputs['Color'], add.inputs[7])
        col = add.outputs[2]
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(col, em.inputs['Color'])
    nt.links.new(em.outputs[0], out.inputs['Surface'])
    _mats[key] = m
    return m


def flat(name, hexcol, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = srgb(hexcol)
    if alpha < 1:
        tr = nt.nodes.new('ShaderNodeBsdfTransparent')
        mix = nt.nodes.new('ShaderNodeMixShader')
        mix.inputs[0].default_value = alpha
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs['Surface'])
    else:
        nt.links.new(em.outputs[0], out.inputs['Surface'])
    return m


_outline = None


def outline_mat():
    global _outline
    if _outline:
        return _outline
    m = bpy.data.materials.new('outline')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*OUTLINE_RGB, 1)
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(geo.outputs['Backfacing'], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
    _outline = m
    return m


def add_outline(obj, width=0.011):
    if width <= 0:
        return obj
    obj.data.materials.append(outline_mat())
    mod = obj.modifiers.new('outline', 'SOLIDIFY')
    mod.thickness = width
    mod.offset = 1
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(obj.data.materials) - 1
    return obj


def mesh_obj(name, bm, mat, outline=0.011, smooth=True, coll=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    me.materials.append(mat)
    add_outline(ob, outline)
    return ob


def lathe(name, profile, mat, seg=28, sx=1.0, sy=1.0, outline=0.011,
          close_top=True, close_bottom=True, coll=None):
    """profile: list of (z, r) bottom->top. Built along +Z at origin."""
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring.append(bm.verts.new((math.cos(a) * r * sx, math.sin(a) * r * sy, z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if close_bottom:
        c = bm.verts.new((0, 0, profile[0][0]))
        for i in range(seg):
            bm.faces.new((rings[0][(i + 1) % seg], rings[0][i], c))
    if close_top:
        c = bm.verts.new((0, 0, profile[-1][0]))
        for i in range(seg):
            bm.faces.new((rings[-1][i], rings[-1][(i + 1) % seg], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, mat, outline, coll=coll)


def capsule_profile(length, r0, r1, n=6):
    """Rounded tube from z=0 to z=length, radius r0 -> r1, hemispherical caps."""
    prof = []
    for i in range(n + 1):
        a = -math.pi / 2 + (math.pi / 2) * i / n
        prof.append((r0 * math.sin(a) + 0, r0 * math.cos(a)))
    steps = 6
    for i in range(1, steps):
        t = i / steps
        prof.append((length * t, r0 + (r1 - r0) * t))
    for i in range(n + 1):
        a = (math.pi / 2) * i / n
        prof.append((length + r1 * math.sin(a), r1 * math.cos(a)))
    prof[0] = (prof[0][0], 0.0005)
    prof[-1] = (prof[-1][0], 0.0005)
    # first point z = -r0
    return prof


def ellipsoid(name, rx, ry, rz, mat, outline=0.011, seg=28, rings=16, coll=None):
    prof = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        prof.append((rz * math.sin(a), max(1e-4, math.cos(a))))
    ob = lathe(name, prof, mat, seg=seg, sx=rx, sy=ry, outline=outline, coll=coll)
    return ob


def place(ob, a, b=None, roll=0.0):
    """Place an object built along +Z so its local Z runs from a to b."""
    a = Vector(a)
    if b is None:
        ob.matrix_world = Matrix.Translation(a) @ Matrix.Rotation(roll, 4, 'Z')
        return ob
    d = Vector(b) - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.matrix_world = Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Rotation(roll, 4, 'Z')
    return ob


def setup_render(res_x, res_y, samples=8):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = False
    s.cycles.max_bounces = 0
    s.cycles.transparent_max_bounces = 16
    s.cycles.filter_width = 1.1
    s.render.film_transparent = True
    s.render.resolution_x = res_x
    s.render.resolution_y = res_y
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'Standard'
    s.view_settings.look = 'None'
    s.render.threads_mode = 'AUTO'
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[1].default_value = 0
    s.world = world
