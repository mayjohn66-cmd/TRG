import numpy as np, math, sys
from PIL import Image, ImageDraw, ImageFilter
S=1024
y,x=np.mgrid[0:S,0:S].astype(np.float32)
def lerp(a,b,t): return a+(b-a)*t
def hexc(h): return np.array([int(h[i:i+2],16) for i in (0,2,4)],np.float32)
# sky gradient
top,bot=hexc('07142e'),hexc('0f3d52')
t=(y/S)[...,None]
img=lerp(top,bot,t)
# radial glow behind orb
cx,cy=512,430
d=np.sqrt((x-cx)**2+(y-cy)**2)[...,None]
glow=np.clip(1-d/620,0,1)**2.2
img=img+glow*hexc('2cc7c2')*0.55
img=np.clip(img,0,255)
base=Image.fromarray(img.astype(np.uint8),'RGB')
dr=ImageDraw.Draw(base)
rng=np.random.default_rng(7)
for i in range(140):
    sx,sy=rng.uniform(0,S),rng.uniform(0,S*0.62); r=rng.uniform(0.8,2.6)
    a=int(rng.uniform(120,255)); dr.ellipse([sx-r,sy-r,sx+r,sy+r],fill=(a,a,min(255,a+20)))
# mountains (two layers)
def ridge(seed,base_y,amp,col):
    g=np.random.default_rng(seed); pts=[(0,S)]
    xs=np.linspace(0,S,13); ys=base_y+g.uniform(-amp,amp,13)
    ys[5]=base_y-amp*1.6; ys[8]=base_y-amp*1.2
    for X,Y in zip(xs,ys): pts.append((X,Y))
    pts.append((S,S)); dr.polygon(pts,fill=col)
ridge(3,760,60,(18,64,78)); ridge(11,840,45,(10,38,50))
# glow layer for droplets & orb
layer=Image.new('RGBA',(S,S),(0,0,0,0)); ld=ImageDraw.Draw(layer)
cols=['ff7a3d','38bdf8','c89b54','52e5b7','ff7a3d','38bdf8']
srcs=[(-60,120),(1090,90),(-80,620),(1100,600),(150,1080),(880,1090)]
def bez(a,b,c,t): return ((1-t)**2*a[0]+2*(1-t)*t*b[0]+t*t*c[0],(1-t)**2*a[1]+2*(1-t)*t*b[1]+t*t*c[1])
for i,(sx,sy) in enumerate(srcs):
    col=tuple(int(cols[i][k:k+2],16) for k in (0,2,4))
    mx,my=(sx+cx)/2,(sy+cy)/2; nx,ny=-(cy-sy),(cx-sx); n=math.hypot(nx,ny)
    ctrl=(mx+nx/n*160*(1 if i%2==0 else -1),my+ny/n*160*(1 if i%2==0 else -1))
    for k in range(60):
        tt=k/60*0.62; px,py=bez((sx,sy),ctrl,(cx,cy),tt)
        r=4+12*(k/60); a=int(40+180*(k/60))
        ld.ellipse([px-r*1.8,py-r*1.8,px+r*1.8,py+r*1.8],fill=col+(a//4,))
        ld.ellipse([px-r,py-r,px+r,py+r],fill=col+(a,))
    px,py=bez((sx,sy),ctrl,(cx,cy),0.62)
    ld.ellipse([px-26,py-26,px+26,py+26],fill=col+(255,))
    ld.ellipse([px-11,py-11,px+11,py+11],fill=(255,255,240,255))
blur=layer.filter(ImageFilter.GaussianBlur(14))
base=Image.alpha_composite(base.convert('RGBA'),blur)
base=Image.alpha_composite(base,layer.filter(ImageFilter.GaussianBlur(2)))
# orb with radial gradient
R=250
od=np.sqrt((x-cx)**2+(y-cy)**2)
tt=np.clip(od/R,0,1)
core=hexc('ffffff'); mid=hexc('aef5ff'); edge=hexc('2cc7c2')
c=np.where((tt<0.45)[...,None],lerp(core,mid,(tt/0.45)[...,None]),lerp(mid,edge,((tt-0.45)/0.55)[...,None]))
alpha=np.clip((R-od)/3,0,1)*255
orb=np.dstack([c,alpha]).astype(np.uint8)
orbimg=Image.fromarray(orb,'RGBA')
halo=Image.new('RGBA',(S,S),(0,0,0,0)); hd=ImageDraw.Draw(halo)
hd.ellipse([cx-R-40,cy-R-40,cx+R+40,cy+R+40],fill=(120,240,250,150))
base=Image.alpha_composite(base,halo.filter(ImageFilter.GaussianBlur(40)))
base=Image.alpha_composite(base,orbimg)
# swirling element streaks inside orb + highlight + arcs
inner=Image.new('RGBA',(S,S),(0,0,0,0)); idr=ImageDraw.Draw(inner)
top_=Image.new('RGBA',(S,S),(0,0,0,0)); td=ImageDraw.Draw(top_)
for i in range(4):
    col=tuple(int(cols[i][k:k+2],16) for k in (0,2,4))
    a0=i*90+20
    idr.arc([cx-R*0.70,cy-R*0.70,cx+R*0.70,cy+R*0.70],a0,a0+70,fill=col+(70,),width=40)
idr.ellipse([cx-R*0.62,cy-R*0.66,cx-R*0.12,cy-R*0.28],fill=(255,255,255,170))
g=np.random.default_rng(5)
for a in range(7):
    ang=a*2*math.pi/7+0.3; pts=[]
    for s in range(7):
        rr=R*(0.98+0.045*s); w=g.uniform(-0.05,0.05)
        pts.append((cx+math.cos(ang+w)*rr,cy+math.sin(ang+w)*rr))
    td.line(pts,fill=(210,252,255,210),width=4,joint='curve')
base=Image.alpha_composite(base,inner.filter(ImageFilter.GaussianBlur(16)))
base=Image.alpha_composite(base,top_.filter(ImageFilter.GaussianBlur(8)))
base=Image.alpha_composite(base,top_.filter(ImageFilter.GaussianBlur(1.2)))
# sparkles
sp=Image.new('RGBA',(S,S),(0,0,0,0)); sd=ImageDraw.Draw(sp)
for (px,py,r) in [(220,250,22),(820,300,18),(760,140,14),(300,620,16),(700,640,20)]:
    sd.polygon([(px,py-r),(px+r*0.25,py-r*0.25),(px+r,py),(px+r*0.25,py+r*0.25),(px,py+r),(px-r*0.25,py+r*0.25),(px-r,py),(px-r*0.25,py-r*0.25)],fill=(255,255,235,230))
base=Image.alpha_composite(base,sp.filter(ImageFilter.GaussianBlur(1)))
base.convert('RGB').resize((512,512),Image.LANCZOS).save(sys.argv[1],optimize=True)
