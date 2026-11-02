import json
from PIL import Image
CELL=448; COLS=8
order=['idle','pull','slip','win','lose']
manifest={'cell':CELL,'cols':COLS,'kids':{}}
for k in ['indigo-captain','indigo-partner','teal-captain','teal-partner']:
    meta=json.load(open(f'/root/rp/full/{k}/meta.json'))
    import math
    ppm=meta['frame']/1.9; p=math.radians(9.0)
    meta['anchor']=[meta['frame']/2+0.04*ppm, meta['frame']/2+0.9*math.cos(p)*ppm]
    sc=CELL/meta['frame']
    frames=[]; states={}
    for st in order:
        idx=[]
        for i,fr in enumerate(meta['states'][st]):
            idx.append(len(frames))
            frames.append((f'/root/rp/full/{k}/{st}_{i:02d}.png',fr))
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
    q=sheet.quantize(colors=256,method=Image.FASTOCTREE,dither=Image.NONE)
    q.save(f'/root/rp/out/{k}.png',optimize=True)
    manifest['kids'][k]={'anchor':[round(meta['anchor'][0]*sc,1),round(meta['anchor'][1]*sc,1)],'states':states,'frames':data}
json.dump(manifest,open('/root/rp/out/kids.json','w'),separators=(',',':'))
