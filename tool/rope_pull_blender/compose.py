import json, math, sys
from PIL import Image, ImageDraw
kids=json.load(open('/root/rp/out/kids.json')); court=json.load(open('/root/rp/scn/court.json'))
BG=Image.open('/root/rp/scn/court.png').convert('RGBA')
sheets={k:Image.open(f'/root/rp/out/{k}.png').convert('RGBA') for k in kids['kids']}
CELL=kids['cell']; COLS=kids['cols']; PPM_C=CELL/1.9
WMIN,HMIN=5.6,3.4; VC=0.9
VBOT=(court['ground'][1]-court['height'])/court['px_per_m']*-1  # bottom v (negative)
VBOT=-(court['height']-court['ground'][1])/court['px_per_m']; VTOP=court['ground'][1]/court['px_per_m']
ROOTS={'indigo-partner':-1.75,'indigo-captain':-0.72,'teal-captain':0.72,'teal-partner':1.75}
def render(W,H,state='pull',fi=0,pull=0.0,out='x.png'):
    k=min(W/WMIN,H/HMIN)
    vc=min(max(VC,VBOT+H/(2*k)),VTOP-H/(2*k))
    def S(x,v): return (W/2+x*k, H/2-(v-vc)*k)
    img=Image.new('RGBA',(W,H))
    sb=k/court['px_per_m']
    bw,bh=BG.size
    bgs=BG.resize((round(bw*sb),round(bh*sb)),Image.LANCZOS)
    gx,gy=S(0,0)
    img.alpha_composite(bgs,(round(gx-court['ground'][0]*sb),round(gy-court['ground'][1]*sb)))
    sc=k/PPM_C; grips=[]
    d=ImageDraw.Draw(img)
    order=['indigo-partner','teal-partner','indigo-captain','teal-captain']
    for kid in order:
        meta=kids['kids'][kid]; flip=kid.startswith('teal')
        idx=meta['states'][state][fi%len(meta['states'][state])]
        fr=meta['frames'][idx]
        cell=sheets[kid].crop(((idx%COLS)*CELL,(idx//COLS)*CELL,(idx%COLS+1)*CELL,(idx//COLS+1)*CELL))
        ax,ay=meta['anchor']
        if flip: cell=cell.transpose(Image.FLIP_LEFT_RIGHT); ax=CELL-ax
        cs=cell.resize((max(1,round(CELL*sc)),max(1,round(CELL*sc))),Image.LANCZOS)
        rx,ry=S(ROOTS[kid]+pull*0.6,0)
        # shadow
        fx=[ (CELL-p[0] if flip else p[0]) for p in fr['f']]
        x0=rx+(min(fx)-ax)*sc-10*sc; x1=rx+(max(fx)-ax)*sc+10*sc
        d.ellipse((x0,ry-6*sc,x1,ry+6*sc),fill=(90,50,20,70))
        img.alpha_composite(cs,(round(rx-ax*sc),round(ry-ay*sc)))
        if fr['g']:
            for p in fr['g']:
                px=CELL-p[0] if flip else p[0]
                grips.append((rx+(px-ax)*sc, ry+(p[1]-ay)*sc))
    grips.sort()
    if grips:
        d=ImageDraw.Draw(img)
        pts=[(grips[0][0]-0.3*k,grips[0][1]+0.05*k)]+grips+[(grips[-1][0]+0.3*k,grips[-1][1]+0.05*k)]
        d.line(pts,fill=(214,180,120,255),width=max(2,round(0.035*k)))
    img.convert('RGB').save(out)
for W,H,n in [(360,300,'phone'),(720,400,'tablet'),(1400,620,'desk')]:
    render(W,H,'pull',3,0.0,f'/tmp/c_{n}.png')
render(720,400,'win',10,-0.6,'/tmp/c_win.png')
