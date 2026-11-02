"""Builds one rigged toon kid facing +X. Rest pose: standing, arms down.

Rig: root > pelvis > spine > chest > neck > head; chest > upperarm/forearm
(IK to hand_*); pelvis > thigh/shin (IK to foot_*); hand_* and foot_* are
children of root so poses are authored by placing hands and feet.
"""
import math

import bpy
from mathutils import Euler, Matrix, Vector

import toon as T

# ---- character looks ------------------------------------------------------
TEAMS = {
    'indigo': dict(jersey='#4B3BD6', jersey_dark='#3426A8', trim='#FFFFFF',
                   pants='#232A4D', shoe_accent='#4B3BD6', band='#F5C56A'),
    'teal': dict(jersey='#13A3A0', jersey_dark='#0C7C7A', trim='#FFFFFF',
                 pants='#2D3036', shoe_accent='#13A3A0', band='#F5C56A'),
}

KIDS = {
    'indigo-captain': dict(team='indigo', skin='#8A5634', hair='afro', girl=False, h=1.50),
    'indigo-partner': dict(team='indigo', skin='#6E4128', hair='puffs', girl=True, h=1.44),
    'teal-captain': dict(team='teal', skin='#5E3720', hair='lowcut', girl=False, h=1.52),
    'teal-partner': dict(team='teal', skin='#9A6440', hair='braid', girl=True, h=1.45),
}

HAIR_COL = '#1C1412'
OUT = 0.010


def _bone(eb, name, head, tail, parent=None, connect=False):
    b = eb.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = eb[parent]
        b.use_connect = connect
    return b


def build(kid_id):
    cfg = KIDS[kid_id]
    team = TEAMS[cfg['team']]
    s = cfg['h'] / 1.48  # overall scale relative to the base build

    def v(x, y, z):
        return Vector((x * s, y * s, z * s))

    # ---- armature ---------------------------------------------------------
    arm_data = bpy.data.armatures.new(kid_id + '_rig')
    arm = bpy.data.objects.new(kid_id + '_rig', arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    _bone(eb, 'root', v(0, 0, 0), v(0, 0.2, 0))
    _bone(eb, 'pelvis', v(0, 0, 0.74), v(0, 0, 0.90), 'root')
    _bone(eb, 'spine', v(0, 0, 0.90), v(0, 0, 1.06), 'pelvis', True)
    _bone(eb, 'chest', v(0, 0, 1.06), v(0, 0, 1.24), 'spine', True)
    _bone(eb, 'neck', v(0, 0, 1.24), v(0, 0, 1.31), 'chest', True)
    _bone(eb, 'head', v(0, 0, 1.31), v(0, 0, 1.52), 'neck', True)
    for side, y in (('L', 1), ('R', -1)):
        # tiny forward bend at knees/elbows gives IK its bend direction
        _bone(eb, 'thigh_' + side, v(0.0, 0.088 * y, 0.75), v(0.022, 0.088 * y, 0.42), 'pelvis')
        _bone(eb, 'shin_' + side, v(0.022, 0.088 * y, 0.42), v(0.0, 0.088 * y, 0.085), 'thigh_' + side, True)
        _bone(eb, 'foot_' + side, v(0.0, 0.088 * y, 0.085), v(0.14, 0.088 * y, 0.04), 'root')
        _bone(eb, 'upperarm_' + side, v(0.0, 0.165 * y, 1.20), v(-0.012, 0.18 * y, 0.98), 'chest')
        _bone(eb, 'forearm_' + side, v(-0.012, 0.18 * y, 0.98), v(0.0, 0.18 * y, 0.78), 'upperarm_' + side, True)
        _bone(eb, 'hand_' + side, v(0.0, 0.18 * y, 0.78), v(0.0, 0.18 * y, 0.70), 'root')
    bpy.ops.object.mode_set(mode='POSE')
    for side in 'LR':
        ik = arm.pose.bones['shin_' + side].constraints.new('IK')
        ik.target = arm
        ik.subtarget = 'foot_' + side
        ik.chain_count = 2
        ik.use_tail = True
        ik = arm.pose.bones['forearm_' + side].constraints.new('IK')
        ik.target = arm
        ik.subtarget = 'hand_' + side
        ik.chain_count = 2
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.update()

    mats = dict(
        skin=T.toon('skin', cfg['skin'], 0.78, rim=0.05),
        skin_dark=T.toon('skin_dark', cfg['skin'], 0.62),
        jersey=T.toon('jersey', team['jersey'], 0.72, rim=0.06),
        jersey_dark=T.toon('jersey_dark', team['jersey_dark'], 0.75),
        trim=T.toon('trim', team['trim'], 0.84),
        pants=T.toon('pants', team['pants'], 0.70, rim=0.05),
        shoe=T.toon('shoe', '#F4F2EC', 0.82),
        sole=T.toon('sole', '#3B3946', 0.8),
        accent=T.toon('accent', team['shoe_accent'], 0.75),
        hair=T.toon('hair', HAIR_COL, 0.8, rim=0.07),
        band=T.toon('band', team['jersey'], 0.75),
        eye=T.flat('eye', '#16121E'),
        eye_white=T.flat('eyewhite', '#FFFFFF'),
        mouth=T.flat('mouth', '#3A1A1A'),
        teeth=T.flat('teeth', '#FFFFFF'),
        blush=T.flat('blush', '#C2584F', alpha=0.35),
    )
    parts = []  # (obj, bone)

    def add(ob, bone):
        parts.append((ob, bone))
        return ob

    # ---- body -------------------------------------------------------------
    # pants: hips block
    hips = T.lathe('hips', [(0.0, 0.11), (0.06, 0.138), (0.14, 0.142), (0.22, 0.13)],
                   mats['pants'], sx=0.86, sy=1.06, outline=OUT)
    T.place(hips, v(0, 0, 0.66))
    hips.scale = (s, s, s)
    add(hips, 'pelvis')
    # torso (jersey), slightly tapered, chest wider
    girl = cfg['girl']
    torso = T.lathe('torso', [(0.0, 0.128), (0.08, 0.13), (0.18, 0.136 if girl else 0.14),
                              (0.27, 0.152), (0.34, 0.15), (0.39, 0.12), (0.41, 0.06)],
                    mats['jersey'], sx=0.84, sy=1.0, outline=OUT)
    T.place(torso, v(0, 0, 0.85))
    torso.scale = (s, s, s)
    add(torso, 'spine')
    # jersey hem band and collar
    hem = T.lathe('hem', [(0, 0.132), (0.025, 0.134)], mats['jersey_dark'], sx=0.85, sy=1.0,
                  outline=0, close_top=False, close_bottom=False)
    T.place(hem, v(0, 0, 0.86))
    hem.scale = (s * 1.02, s * 1.02, s)
    add(hem, 'spine')
    collar = T.lathe('collar', [(0, 0.075), (0.02, 0.068), (0.03, 0.058)], mats['trim'],
                     sx=0.85, sy=1.0, outline=0.006)
    T.place(collar, v(0, 0, 1.235))
    collar.scale = (s, s, s)
    add(collar, 'chest')
    # neck
    neck = T.lathe('neck', T.capsule_profile(0.09, 0.042, 0.04), mats['skin_dark'], outline=OUT)
    T.place(neck, v(0, 0, 1.22), v(0, 0, 1.33))
    neck.scale = (s, s, s)
    add(neck, 'neck')

    # ---- head -------------------------------------------------------------
    hc = v(0.005, 0, 1.43)  # head centre
    head = T.ellipsoid('head', 0.112, 0.105, 0.125, mats['skin'], outline=OUT)
    T.place(head, hc)
    head.scale = (s, s, s)
    add(head, 'head')
    jaw = T.ellipsoid('jaw', 0.085, 0.08, 0.07, mats['skin'], outline=0)
    T.place(jaw, hc + v(0.025, 0, -0.06))
    jaw.scale = (s, s, s)
    add(jaw, 'head')
    nose = T.ellipsoid('nose', 0.02, 0.02, 0.018, mats['skin_dark'], outline=0.005)
    T.place(nose, hc + v(0.112, 0, -0.012))
    nose.scale = (s, s, s)
    add(nose, 'head')
    for side, y in (('L', 1), ('R', -1)):
        ear = T.ellipsoid('ear_' + side, 0.022, 0.012, 0.03, mats['skin'], outline=0.006)
        T.place(ear, hc + v(-0.005, 0.106 * y, -0.005))
        ear.scale = (s, s, s)
        add(ear, 'head')
        eye = T.ellipsoid('eye_' + side, 0.012, 0.017, 0.024, mats['eye'], outline=0, seg=16, rings=10)
        T.place(eye, hc + v(0.098, 0.043 * y, 0.012))
        eye.scale = (s, s, s)
        add(eye, 'head')
        hl = T.ellipsoid('eyehl_' + side, 0.006, 0.006, 0.007, mats['eye_white'], outline=0, seg=10, rings=6)
        T.place(hl, hc + v(0.109, 0.043 * y - 0.006, 0.022))
        hl.scale = (s, s, s)
        add(hl, 'head')
        brow = T.lathe('brow_' + side, T.capsule_profile(0.032, 0.006, 0.005), mats['eye'], seg=8, outline=0)
        T.place(brow, hc + v(0.1, 0.06 * y + 0.0, 0.052), hc + v(0.104, 0.028 * y, 0.056))
        brow.scale = (s, s, s)
        add(brow, 'head')
        if girl:
            lash = T.lathe('lash_' + side, T.capsule_profile(0.012, 0.004, 0.003), mats['eye'], seg=6, outline=0)
            T.place(lash, hc + v(0.1, 0.06 * y, 0.03), hc + v(0.105, 0.066 * y, 0.04))
            lash.scale = (s, s, s)
            add(lash, 'head')
        blush = T.ellipsoid('blush_' + side, 0.006, 0.022, 0.013, mats['blush'], outline=0, seg=12, rings=6)
        T.place(blush, hc + v(0.096, 0.064 * y, -0.022))
        blush.scale = (s, s, s)
        add(blush, 'head')

    # mouths: one per expression, toggled per state
    mouths = {}
    m = T.lathe('mouth_smile', T.capsule_profile(0.04, 0.007, 0.007), mats['mouth'], seg=8, outline=0)
    T.place(m, hc + v(0.103, -0.02, -0.06), hc + v(0.105, 0.02, -0.06))
    m.scale = (s, s, s)
    mouths['smile'] = add(m, 'head')
    m = T.ellipsoid('mouth_effort', 0.012, 0.032, 0.014, mats['mouth'], outline=0, seg=12, rings=8)
    T.place(m, hc + v(0.1, 0.0, -0.062))
    m.scale = (s, s, s)
    mouths['effort'] = add(m, 'head')
    t = T.ellipsoid('teeth_effort', 0.008, 0.026, 0.006, mats['teeth'], outline=0, seg=12, rings=6)
    T.place(t, hc + v(0.108, 0.0, -0.058))
    t.scale = (s, s, s)
    mouths['effort_t'] = add(t, 'head')
    m = T.ellipsoid('mouth_cheer', 0.014, 0.034, 0.026, mats['mouth'], outline=0, seg=12, rings=8)
    T.place(m, hc + v(0.098, 0.0, -0.066))
    m.scale = (s, s, s)
    mouths['cheer'] = add(m, 'head')
    t = T.ellipsoid('teeth_cheer', 0.008, 0.028, 0.007, mats['teeth'], outline=0, seg=12, rings=6)
    T.place(t, hc + v(0.107, 0.0, -0.05))
    t.scale = (s, s, s)
    mouths['cheer_t'] = add(t, 'head')
    m = T.lathe('mouth_tired', T.capsule_profile(0.03, 0.006, 0.006), mats['mouth'], seg=8, outline=0)
    T.place(m, hc + v(0.104, -0.015, -0.066), hc + v(0.104, 0.015, -0.062))
    m.scale = (s, s, s)
    mouths['tired'] = add(m, 'head')

    # ---- hair -------------------------------------------------------------
    style = cfg['hair']

    def hair_cap(scale=1.0, lift=0.0, bumps=0.0, cut=-0.02):
        cap = T.ellipsoid('haircap', 0.122 * scale, 0.115 * scale, 0.132 * scale, mats['hair'], outline=OUT, seg=32, rings=18)
        me = cap.data
        # trim the front/bottom so the face shows
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        kill = [vv for vv in bm.verts if (vv.co.z < cut * 1.0 and vv.co.x > -0.04) or vv.co.z < -0.075
                or (vv.co.x > 0.07 and vv.co.z < 0.055)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS')
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        if bumps:
            tex = bpy.data.textures.new('curl', 'CLOUDS')
            tex.noise_scale = 0.025
            d = cap.modifiers.new('curl', 'DISPLACE')
            d.texture = tex
            d.strength = bumps
            d.mid_level = 0.5
            cap.modifiers.move(len(cap.modifiers) - 1, 0)
        T.place(cap, hc + v(-0.008, 0, lift))
        cap.scale = (s, s, s)
        return add(cap, 'head')

    if style == 'afro':
        hair_cap(1.12, 0.02, bumps=0.0, cut=0.0)
        import random
        rnd = random.Random(3)
        n = 46
        for k in range(n):
            # golden-angle points on the upper back of the head
            zf = 1 - (k + 0.5) / n * 1.15
            if zf < -0.25:
                continue
            rr = math.sqrt(max(0, 1 - zf * zf))
            a = k * 2.39996
            dirv = Vector((math.cos(a) * rr, math.sin(a) * rr, zf))
            if dirv.x > 0.55 and dirv.z < 0.55:
                continue  # keep the forehead clear
            r = 0.045 + rnd.random() * 0.012
            curl = T.ellipsoid('curl', r, r, r, mats['hair'], outline=OUT * 0.8, seg=14, rings=8)
            T.place(curl, hc + v(-0.012, 0, 0.03) + dirv * 0.118 * s)
            curl.scale = (s, s, s)
            add(curl, 'head')
    elif style == 'lowcut':
        hair_cap(1.02, 0.008, bumps=0.004, cut=0.01)
        band = T.lathe('headband', [(0, 0.118), (0.03, 0.119)], mats['band'], seg=32,
                       sx=1.0, sy=0.95, outline=0.006, close_top=False, close_bottom=False)
        T.place(band, hc + v(-0.005, 0, 0.02))
        band.rotation_euler = (0, math.radians(-14), 0)
        band.scale = (s, s, s)
        add(band, 'head')
    elif style == 'puffs':
        hair_cap(1.05, 0.012, bumps=0.006, cut=0.012)
        for y in (1, -1):
            puff = T.ellipsoid('puff', 0.075, 0.075, 0.072, mats['hair'], outline=OUT, seg=24, rings=14)
            tex = bpy.data.textures.new('curl2', 'CLOUDS')
            tex.noise_scale = 0.03
            d = puff.modifiers.new('curl', 'DISPLACE')
            d.texture = tex
            d.strength = 0.02
            puff.modifiers.move(len(puff.modifiers) - 1, 0)
            T.place(puff, hc + v(-0.045, 0.1 * y, 0.1))
            puff.scale = (s, s, s)
            add(puff, 'head')
            tie = T.lathe('tie', [(0, 0.032), (0.018, 0.032)], mats['band'], seg=16, outline=0.005)
            T.place(tie, hc + v(-0.03, 0.065 * y, 0.075), hc + v(-0.04, 0.085 * y, 0.09))
            tie.scale = (s, s, s)
            add(tie, 'head')
    elif style == 'braid':
        hair_cap(1.04, 0.01, bumps=0.004, cut=0.012)
        # cornrow ridges
        for k in range(-2, 3):
            ridge = T.lathe('row', T.capsule_profile(0.2, 0.012, 0.012), mats['hair'], seg=8, outline=0.004)
            T.place(ridge, hc + v(0.085, 0.03 * k, 0.07), hc + v(-0.11, 0.025 * k, 0.04))
            ridge.scale = (s, s, s)
            add(ridge, 'head')
        prev = hc + v(-0.1, 0, 0.1)
        r = 0.045
        for k in range(7):
            nxt = prev + v(-0.04 + k * 0.006, 0, -0.04)
            bead = T.ellipsoid('braid', r, r, r * 1.15, mats['hair'], outline=OUT, seg=16, rings=10)
            T.place(bead, prev)
            bead.scale = (s, s, s)
            add(bead, 'head')
            prev = nxt
            r *= 0.88
        tie = T.ellipsoid('tie', 0.022, 0.03, 0.018, mats['band'], outline=0.005, seg=14, rings=8)
        T.place(tie, hc + v(-0.11, 0, 0.08))
        tie.scale = (s, s, s)
        add(tie, 'head')

    # ---- arms -------------------------------------------------------------
    pb = arm.pose.bones
    for side, y in (('L', 1), ('R', -1)):
        sh = v(0.0, 0.165 * y, 1.20)
        el = v(-0.012, 0.18 * y, 0.98)
        wr = v(0.0, 0.18 * y, 0.78)
        shoulder = T.ellipsoid('shoulder_' + side, 0.062, 0.062, 0.062, mats['jersey'], outline=OUT)
        T.place(shoulder, sh + v(0, 0, -0.01))
        shoulder.scale = (s, s, s)
        add(shoulder, 'chest')
        sleeve = T.lathe('sleeve_' + side, [(0, 0.06), (0.06, 0.058), (0.1, 0.055), (0.11, 0.052)],
                         mats['jersey'], outline=OUT, close_bottom=False)
        T.place(sleeve, sh, el)
        sleeve.scale = (s, s, s)
        add(sleeve, 'upperarm_' + side)
        cuff = T.lathe('cuff_' + side, [(0.1, 0.057), (0.12, 0.055)], mats['trim'], outline=0.004,
                       close_bottom=False, close_top=False)
        T.place(cuff, sh, el)
        cuff.scale = (s, s, s)
        add(cuff, 'upperarm_' + side)
        upper = T.lathe('upper_' + side, T.capsule_profile((el - sh).length / s, 0.04, 0.036),
                        mats['skin'], outline=OUT)
        T.place(upper, sh, el)
        upper.scale = (s, s, s)
        add(upper, 'upperarm_' + side)
        fore = T.lathe('fore_' + side, T.capsule_profile((wr - el).length / s, 0.036, 0.032),
                       mats['skin'], outline=OUT)
        T.place(fore, el, wr)
        fore.scale = (s, s, s)
        add(fore, 'forearm_' + side)
        fist = T.ellipsoid('fist_' + side, 0.045, 0.04, 0.05, mats['skin'], outline=OUT)
        T.place(fist, wr + v(0, 0, -0.035))
        fist.scale = (s, s, s)
        add(fist, 'hand_' + side)
        knuckles = T.ellipsoid('thumb_' + side, 0.016, 0.016, 0.026, mats['skin_dark'], outline=0.004)
        T.place(knuckles, wr + v(0.03, 0.025 * y * 0, -0.005))
        knuckles.scale = (s, s, s)
        add(knuckles, 'hand_' + side)

    # ---- legs -------------------------------------------------------------
    for side, y in (('L', 1), ('R', -1)):
        hp = v(0.0, 0.088 * y, 0.75)
        kn = v(0.022, 0.088 * y, 0.42)
        an = v(0.0, 0.088 * y, 0.085)
        thigh = T.lathe('thigh_' + side, T.capsule_profile((kn - hp).length / s, 0.084, 0.068),
                        mats['pants'], outline=OUT)
        T.place(thigh, hp, kn)
        thigh.scale = (s, s, s)
        add(thigh, 'thigh_' + side)
        knee = T.ellipsoid('knee_' + side, 0.07, 0.07, 0.07, mats['pants'], outline=OUT)
        T.place(knee, kn)
        knee.scale = (s, s, s)
        add(knee, 'shin_' + side)
        shin = T.lathe('shin_' + side, T.capsule_profile((an - kn).length / s, 0.066, 0.056),
                       mats['pants'], outline=OUT)
        T.place(shin, kn, an + v(0, 0, 0.02))
        shin.scale = (s, s, s)
        add(shin, 'shin_' + side)
        stripe = T.lathe('pstripe_' + side, T.capsule_profile((an - hp).length / s * 0.95, 0.01, 0.01),
                         mats['accent'], seg=8, outline=0)
        # side stripe on the outside of the leg (only meaningful at rest; tied to shin)
        stripe.hide_render = True
        shoe = T.lathe('shoe_' + side, [(0, 0.001), (0.01, 0.045), (0.06, 0.055), (0.16, 0.052), (0.2, 0.04), (0.215, 0.001)],
                       mats['shoe'], sx=0.62, sy=1.0, outline=OUT)
        # lathe along Z then lay it along +X
        shoe.matrix_world = (Matrix.Translation(an + v(-0.065, 0, -0.035))
                             @ Matrix.Rotation(math.radians(90), 4, 'Y')
                             @ Matrix.Rotation(math.radians(90), 4, 'Z'))
        shoe.scale = (s, s, s)
        add(shoe, 'foot_' + side)
        sole = T.lathe('sole_' + side, [(0, 0.001), (0.005, 0.047), (0.21, 0.044), (0.22, 0.001)],
                       mats['sole'], sx=0.3, sy=1.0, outline=0.006)
        sole.matrix_world = (Matrix.Translation(an + v(-0.07, 0, -0.068))
                             @ Matrix.Rotation(math.radians(90), 4, 'Y')
                             @ Matrix.Rotation(math.radians(90), 4, 'Z'))
        sole.scale = (s * 1.05, s * 1.05, s)
        add(sole, 'foot_' + side)
        swoosh = T.lathe('swoosh_' + side, T.capsule_profile(0.09, 0.012, 0.008), mats['accent'], seg=8, outline=0)
        T.place(swoosh, an + v(-0.02, 0.054 * y, -0.035), an + v(0.07, 0.05 * y, -0.02))
        swoosh.scale = (s, s, s)
        add(swoosh, 'foot_' + side)
        cuffp = T.lathe('pcuff_' + side, [(0, 0.06), (0.035, 0.06)], mats['pants'], outline=OUT,
                        close_bottom=True)
        T.place(cuffp, an + v(0, 0, -0.005))
        cuffp.scale = (s, s, s)
        add(cuffp, 'shin_' + side)

    # ---- parent everything to bones keeping world transforms --------------
    bpy.context.view_layer.update()
    pivot = v(0, 0, 1.30)
    grow = Matrix.Translation(pivot) @ Matrix.Scale(1.17, 4) @ Matrix.Translation(-pivot)
    for ob, bone in parts:
        mw = ob.matrix_world.copy()
        if bone == 'head':
            mw = grow @ mw
        p = arm.pose.bones[bone]
        ob.parent = arm
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
        tail = arm.matrix_world @ p.matrix @ Matrix.Translation((0, p.length, 0))
        ob.matrix_parent_inverse = tail.inverted()
        ob.matrix_world = mw
    bpy.context.view_layer.update()
    return arm, mouths, s
