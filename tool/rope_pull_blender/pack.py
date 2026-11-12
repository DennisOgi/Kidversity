import os
WORK = os.environ.get('ROPE_PULL_WORK', 'rp_work')  # scratch folder for renders
import json
from PIL import Image
CELL=448; COLS=8
order=['idle','pull','slip','win','lose']
manifest={'cell':CELL,'cols':COLS,'kids':{}}
os.makedirs(f'{WORK}/out',exist_ok=True)
# ROPE_PULL_RGBA=1 writes full-colour PNGs. They are larger, but Flutter web's
# own image decoder accepts them (it rejects palette PNGs, so the app falls
# back to a slower browser decode for those).
RGBA=os.environ.get('ROPE_PULL_RGBA')=='1'
for k in ['indigo-captain','indigo-partner','teal-captain','teal-partner']:
    meta=json.load(open(f'{WORK}/full/{k}/meta.json'))
    import math
    ppm=meta['frame']/1.9; p=math.radians(9.0)
    meta['anchor']=[meta['frame']/2+0.04*ppm, meta['frame']/2+0.9*math.cos(p)*ppm]
    sc=CELL/meta['frame']
    frames=[]; states={}
    for st in order:
        idx=[]
        for i,fr in enumerate(meta['states'][st]):
            idx.append(len(frames))
            frames.append((f'{WORK}/full/{k}/{st}_{i:02d}.png',fr))
        states[st]=idx
    rows=(len(frames)+COLS-1)//COLS
    sheet=Image.new('RGBA',(CELL*COLS,CELL*rows),(0,0,0,0))
    data=[]
    for n,(f,fr) in enumerate(frames):
        im=Image.open(f).resize((CELL,CELL),Image.LANCZOS)
        sheet.alpha_composite(im,((n%COLS)*CELL,(n//COLS)*CELL))
        r=lambda p:[round(p[0]*sc,1),round(p[1]*sc,1)]
        data.append({'g':[r(p) for p in fr['grip']] if fr['grip'] else None,'f':[r(p) for p in fr['feet']]})
    # palette PNG keeps flat toon colours and shrinks the file a lot
    q=sheet if RGBA else sheet.quantize(colors=256,method=Image.FASTOCTREE,dither=Image.NONE)
    q.save(f'{WORK}/out/{k}.png',optimize=True)
    manifest['kids'][k]={'anchor':[round(meta['anchor'][0]*sc,1),round(meta['anchor'][1]*sc,1)],'states':states,'frames':data}
json.dump(manifest,open(f'{WORK}/out/kids.json','w'),separators=(',',':'))
