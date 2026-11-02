"""Pose + render one kid's animation states to individual PNG frames and a
JSON of per-frame projected hand/foot positions.

usage: python render_kid.py <kid_id> <out_dir> [states] [--preview]
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
import kid as K  # noqa: E402
import toon as T  # noqa: E402

FRAME = 512
ORTHO = 1.9
PITCH = 9.0  # degrees the camera looks down
CENTER = (-0.04, 0.9)  # world x, z at frame centre

STATES = {
    'idle': 8,
    'pull': 12,
    'slip': 8,
    'win': 14,
    'lose': 10,
}


def ease(t):
    return 0.5 - 0.5 * math.cos(math.pi * t)


def lerp(a, b, t):
    return a + (b - a) * t


class Rig:
    def __init__(self, arm, s):
        self.arm = arm
        self.s = s
        self.pb = arm.pose.bones
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}

    def reset(self):
        for p in self.pb:
            p.rotation_mode = 'QUATERNION'
            p.location = (0, 0, 0)
            p.rotation_quaternion = (1, 0, 0, 0)
            p.scale = (1, 1, 1)

    def place(self, bone, pos, rot=None):
        """Put bone head at armature-space pos with extra world rotation."""
        rest = self.rest[bone]
        r = rest.to_quaternion()
        if rot is not None:
            r = rot @ r
        m = Matrix.Translation(Vector(pos) * 1.0) @ r.to_matrix().to_4x4()
        self.pb[bone].matrix = m
        bpy.context.view_layer.update()

    def turn(self, bone, x=0.0, y=0.0, z=0.0):
        """Rotate bone relative to parent, about armature axes (degrees)."""
        q = Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ').to_quaternion()
        rr = self.rest[bone].to_quaternion()
        self.pb[bone].rotation_quaternion = rr.inverted() @ q @ rr

    def hand(self, side, pos, rot=None):
        """Place a hand, pulled in toward the shoulder if out of reach."""
        bpy.context.view_layer.update()
        sh = self.world('upperarm_' + side)
        reach = (self.pb['upperarm_' + side].length + self.pb['forearm_' + side].length) * 0.97
        target = self.arm.matrix_world @ Vector(pos)
        d = target - sh
        if d.length > reach:
            target = sh + d.normalized() * reach
        self.place('hand_' + side, self.arm.matrix_world.inverted() @ target, rot)

    def hand_dir(self, side, direction, frac=0.96, rot=None):
        bpy.context.view_layer.update()
        sh = self.world('upperarm_' + side)
        reach = self.pb['upperarm_' + side].length + self.pb['forearm_' + side].length
        target = sh + Vector(direction).normalized() * reach * frac
        self.place('hand_' + side, self.arm.matrix_world.inverted() @ target, rot)

    def world(self, bone, tail=False):
        p = self.pb[bone]
        v = p.tail if tail else p.head
        return self.arm.matrix_world @ v


def v3(s, x, y, z):
    return Vector((x * s, y * s, z * s))


def pose_frame(rig, state, t):
    """t in [0,1) across the clip. Returns mouth key and whether hands grip."""
    s = rig.s
    rig.reset()
    bpy.context.view_layer.update()
    yaw = -36  # cheat the upper body toward the camera (-Y)
    grip = True
    mouth = 'effort'
    if state == 'idle':
        b = math.sin(2 * math.pi * t)
        rig.place('pelvis', v3(s, -0.03, 0, 0.7 + 0.006 * b),
                  Euler((0, math.radians(-4), math.radians(-10)), 'XYZ').to_quaternion())
        rig.turn('spine', 0, -2, yaw * 0.3)
        rig.turn('chest', 0, -2 + b, yaw * 0.4)
        rig.turn('neck', 0, 4, yaw * 0.3)
        rig.turn('head', 0, 6, -16 + 2 * b)
        rig.place('foot_L', v3(s, 0.12, 0.1, 0.085))
        rig.place('foot_R', v3(s, -0.14, -0.1, 0.085),
                  Euler((0, 0, math.radians(-18)), 'XYZ').to_quaternion())
        rz = 0.72 + 0.006 * b
        rig.hand('R', v3(s, 0.3, -0.05, rz))
        rig.hand('L', v3(s, 0.14, -0.03, rz + 0.005))
        mouth = 'smile'
    elif state in ('pull', 'slip'):
        # Classic tug-of-war brace: feet ahead of the hips, front leg near
        # straight and dug in, back leg bent, body leaning back.
        if state == 'pull':
            h = ease(t / 0.6) if t < 0.6 else ease(1 - (t - 0.6) / 0.4)
            lean = lerp(-22, -34, h)
            px = lerp(-0.26, -0.32, h)
            pz = lerp(0.54, 0.51, h)
            hand_front = lerp(0.3, 0.24, h)
            step = min(1, max(0, (t - 0.15) / 0.4))
            back_lift = math.sin(math.pi * step) * 0.03
            back_x = lerp(-0.14, -0.2, ease(step))
            if t >= 0.6:
                back_x = lerp(-0.2, -0.14, ease((t - 0.6) / 0.4))
            front_x = lerp(0.2, 0.17, h)
            toe = -10
        else:
            h = ease(t)
            lean = lerp(-14, -10, math.sin(math.pi * t))
            px = lerp(-0.16, -0.1, h)
            pz = 0.56
            hand_front = 0.4
            back_lift = math.sin(math.pi * t) * 0.02
            back_x = lerp(-0.1, -0.04, h)
            front_x = lerp(0.2, 0.28, h)  # heels skid toward the middle
            toe = -16
        rig.place('pelvis', v3(s, px, 0, pz),
                  Euler((0, math.radians(lean * 0.5), math.radians(-12)), 'XYZ').to_quaternion())
        rig.turn('spine', 0, lean * 0.3, yaw * 0.3)
        rig.turn('chest', 0, lean * 0.2, yaw * 0.45)
        rig.turn('neck', 0, -lean * 0.55, yaw * 0.2)
        rig.turn('head', 0, -lean * 0.45 + 4, -14)
        # front foot: heel down, toes up; back foot flat
        rig.place('foot_L', v3(s, front_x, 0.1, 0.085),
                  Euler((0, math.radians(toe), 0), 'XYZ').to_quaternion())
        rig.place('foot_R', v3(s, back_x, -0.1, 0.085 + back_lift),
                  Euler((0, 0, math.radians(-14)), 'XYZ').to_quaternion())
        rope_z = pz + 0.16
        rig.hand('R', v3(s, hand_front, -0.06, rope_z),
                 Euler((math.radians(90), 0, 0), 'XYZ').to_quaternion())
        rig.hand('L', v3(s, hand_front - 0.15, -0.05, rope_z - 0.01),
                 Euler((math.radians(90), 0, 0), 'XYZ').to_quaternion())
        mouth = 'effort'
    elif state == 'win':
        grip = False
        mouth = 'cheer'
        # crouch 0-0.2, jump 0.2-0.6, land 0.6-0.75, then hold with a fist up
        if t < 0.2:
            k = ease(t / 0.2)
            z, crouch, up = 0.0, k, 0.0
        elif t < 0.6:
            k = (t - 0.2) / 0.4
            z, crouch, up = math.sin(math.pi * k) * 0.2, 0.0, ease(min(1, k * 2))
        elif t < 0.75:
            k = ease((t - 0.6) / 0.15)
            z, crouch, up = 0.0, 0.6 * (1 - k), 1.0
        else:
            k = (t - 0.75) / 0.25
            z, crouch, up = 0.0, 0.0, 1.0
        pz = 0.72 - 0.1 * crouch + z
        rig.place('pelvis', v3(s, 0.0, 0, pz),
                  Euler((0, math.radians(4 * crouch), math.radians(-20)), 'XYZ').to_quaternion())
        rig.turn('spine', 0, 6 * crouch - 4 * up, yaw * 0.5)
        rig.turn('chest', 0, -3 * up, yaw * 0.6)
        rig.turn('neck', 0, -6 * up, 0)
        rig.turn('head', 0, -8 * up, -10)
        fz = 0.085 + z * 0.85
        tuck = math.sin(math.pi * max(0, min(1, (t - 0.2) / 0.4))) * 0.08
        rig.place('foot_L', v3(s, 0.12, 0.1, fz + tuck))
        rig.place('foot_R', v3(s, -0.14, -0.1, fz + tuck * 0.7),
                  Euler((0, 0, math.radians(-15)), 'XYZ').to_quaternion())
        sh_z = pz + 0.44
        # both fists swing up into a V, near one stays high
        lowR = Vector((0.5, -0.25, -0.75))
        lowL = Vector((0.45, 0.2, -0.8))
        upR = Vector((-0.5, -0.12, 1.0))
        upL = Vector((0.5, 0.12, 1.0))
        rig.hand_dir('R', lowR.lerp(upR, up), frac=lerp(0.8, 0.97, up),
                     rot=Euler((0, math.radians(lerp(0, 160, up)), 0), 'XYZ').to_quaternion())
        rig.hand_dir('L', lowL.lerp(upL, up), frac=lerp(0.8, 0.97, up),
                     rot=Euler((0, math.radians(lerp(0, 200, up)), 0), 'XYZ').to_quaternion())
    elif state == 'lose':
        grip = False
        mouth = 'tired'
        k = ease(min(1, t / 0.4))
        b = math.sin(2 * math.pi * max(0, t - 0.4) / 0.3) * (1 if t > 0.4 else 0)
        pz = lerp(0.66, 0.6, k)
        rig.place('pelvis', v3(s, lerp(-0.06, -0.12, k), 0, pz + 0.004 * b),
                  Euler((0, math.radians(lerp(0, 22, k)), math.radians(-14)), 'XYZ').to_quaternion())
        rig.turn('spine', 0, lerp(-6, 14, k), yaw * 0.3)
        rig.turn('chest', 0, lerp(-4, 8, k) + 1.5 * b, yaw * 0.4)
        rig.turn('neck', 0, lerp(0, -18, k), 0)
        rig.turn('head', 0, lerp(4, -12, k), -8)
        rig.place('foot_L', v3(s, 0.16, 0.11, 0.085))
        rig.place('foot_R', v3(s, -0.12, -0.11, 0.085),
                  Euler((0, 0, math.radians(-10)), 'XYZ').to_quaternion())
        knee_z = 0.45
        rig.hand('R', v3(s, lerp(0.34, 0.12, k), -0.14, lerp(0.8, knee_z + 0.05, k)))
        rig.hand('L', v3(s, lerp(0.2, 0.18, k), 0.1, lerp(0.79, knee_z + 0.05, k)))
    bpy.context.view_layer.update()
    return mouth, grip


def setup_camera():
    s = bpy.context.scene
    cam_data = bpy.data.cameras.new('cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ORTHO
    cam = bpy.data.objects.new('cam', cam_data)
    s.collection.objects.link(cam)
    p = math.radians(PITCH)
    # look along +Y tilted down; place so CENTER sits mid-frame on the y=0 plane
    d = Vector((0, math.cos(p), -math.sin(p)))
    target = Vector((CENTER[0], 0, CENTER[1]))
    cam.location = target - d * 12
    cam.rotation_euler = (math.radians(90) - p, 0, 0)
    s.camera = cam
    return cam


def project(cam, pt):
    s = bpy.context.scene
    c = world_to_camera_view(s, cam, pt)
    return [round(c.x * FRAME, 2), round((1 - c.y) * FRAME, 2)]


def main():
    args = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else sys.argv[1:]
    preview = '--preview' in args
    args = [a for a in args if a != '--preview']
    kid_id, out_dir = args[0], args[1]
    states = args[2].split(',') if len(args) > 2 else list(STATES)
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    T.setup_render(FRAME, FRAME, samples=6 if preview else 8)
    arm, mouths, s = K.build(kid_id)
    rig = Rig(arm, s)
    cam = setup_camera()
    bpy.context.view_layer.update()
    meta = {'frame': FRAME, 'anchor': project(cam, Vector((0, 0, 0))),
            'px_per_m': FRAME / ORTHO, 'states': {}}
    for state in states:
        n = STATES[state]
        frames = []
        idxs = [0, n // 2] if preview else range(n)
        for i in idxs:
            mouth, grip = pose_frame(rig, state, i / n)
            for key, ob in mouths.items():
                ob.hide_render = not key.startswith(mouth)
            hands = []
            for side in ('R', 'L'):
                fist = rig.world('hand_' + side) + Vector((0, 0, -0.035 * s))
                hands.append(project(cam, fist))
            feet = [project(cam, rig.world('foot_' + side) + Vector((0, 0, -0.085 * s))) for side in ('R', 'L')]
            path = os.path.join(out_dir, f'{state}_{i:02d}.png')
            bpy.context.scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            frames.append({'grip': hands if grip else None, 'feet': feet})
            print('rendered', path, flush=True)
        meta['states'][state] = frames
    with open(os.path.join(out_dir, 'meta.json'), 'w') as f:
        json.dump(meta, f)


if __name__ == '__main__':
    main()
