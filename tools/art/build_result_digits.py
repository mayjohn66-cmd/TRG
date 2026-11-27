"""Build a tiny OFL-derived decimal-only font using the Python standard library.

Preserves the existing comic font, its metrics and unmodified decimal glyphs.
Only adds a crossbar to 7; every other digit keeps its exact source outline.
"""
from pathlib import Path
import struct, math, hashlib, json

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/fonts/result/bangers.ttf'
OUTPUT=ROOT/'assets/fonts/TRGComicResultDigits.ttf'
data=SOURCE.read_bytes()
u16=lambda b,o=0:struct.unpack_from('>H',b,o)[0]
s16=lambda b,o=0:struct.unpack_from('>h',b,o)[0]
u32=lambda b,o=0:struct.unpack_from('>I',b,o)[0]
tables={}
for i in range(u16(data,4)):
    tag,_,offset,length=struct.unpack_from('>4sIII',data,12+i*16)
    tables[tag]=data[offset:offset+length]

def char_gid(code):
    cmap=tables[b'cmap']
    for i in range(u16(cmap,2)):
        offset=u32(cmap,4+i*8+4)
        if u16(cmap,offset)!=4: continue
        t=cmap[offset:];n=u16(t,6)//2
        for j in range(n):
            end=u16(t,14+2*j);start=u16(t,16+2*n+2*j)
            if start<=code<=end:
                delta=s16(t,16+4*n+2*j)
                pos=16+6*n+2*j;distance=u16(t,pos)
                glyph=u16(t,pos+distance+2*(code-start)) if distance else code
                return (glyph+delta)&65535 if glyph else 0
    raise ValueError(f'No BMP mapping for {code}')

loca=tables[b'loca'];long=u16(tables[b'head'],50)==1
offsets=[u32(loca,i*4) if long else u16(loca,i*2)*2 for i in range(u16(tables[b'maxp'],4)+1)]
glyph=lambda g:tables[b'glyf'][offsets[g]:offsets[g+1]]

def components(blob):
    if len(blob)<10 or s16(blob)>=0:return []
    result=[];p=10
    while True:
        flags=u16(blob,p);result.append((p+2,u16(blob,p+2)));p+=4
        p+=4 if flags&1 else 2
        p+=2 if flags&8 else (4 if flags&64 else (8 if flags&128 else 0))
        if not flags&32:return result

def add_rect(blob, digit):
    n=s16(blob);assert n>0,'Expected a simple digit outline'
    ends=[u16(blob,10+2*i) for i in range(n)];count=ends[-1]+1
    p=10+2*n;instructions=u16(blob,p);p+=2+instructions
    flags=[]
    while len(flags)<count:
        f=blob[p];p+=1;repeat=blob[p]+1 if f&8 else 1
        if f&8:p+=1
        flags.extend([f]*repeat)
    coords=[]
    for short,same in ((2,16),(4,32)):
        at=0;values=[]
        for f in flags:
            if f&short:
                delta=blob[p] if f&same else -blob[p];p+=1
            elif f&same:delta=0
            else:delta=s16(blob,p);p+=2
            at+=delta;values.append(at)
        coords.append(values)
    points=list(zip(*coords));xmin,ymin,xmax,ymax=struct.unpack_from('>hhhh',blob,2)
    width=xmax-xmin;height=ymax-ymin
    if digit==1: x0,x1,y0,y1=xmin-65,xmax+85,ymin,ymin+70
    else:x0,x1,y0,y1=xmin+int(width*.12),xmin+int(width*.91),ymin+int(height*.44),ymin+int(height*.53)
    # Match the source exterior's winding so intersecting contours form a union.
    areas=[];begin=0
    for end in ends:
        contour=points[begin:end+1]
        areas.append(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(contour,contour[1:]+contour[:1])))
        begin=end+1
    tilt=int((x1-x0)*.12)
    rect=[(x0,y0),(x0,y1),(x1,y1+tilt),(x1,y0+tilt)]
    if max(areas,key=abs)>0:rect.reverse()
    points+=rect;flags=[f&1 for f in flags]+[1]*4;ends.append(len(points)-1)
    xs,ys=zip(*points)
    output=struct.pack('>hhhhh',n+1,min(xs),min(ys),max(xs),max(ys))
    output+=struct.pack('>'+str(len(ends))+'H',*ends)+b'\0\0'+bytes(flags)
    for axis in (xs,ys):
        previous=0
        for value in axis:output+=struct.pack('>h',value-previous);previous=value
    return output

digits=[char_gid(c) for c in range(48,58)]
order=list(dict.fromkeys([0]+digits))
for gid in order:
    for _,child in components(glyph(gid)):
        if child not in order:order.append(child)
mapping={old:new for new,old in enumerate(order)}
body=bytearray();positions=[];metrics=bytearray()
metric_count=u16(tables[b'hhea'],34)
for gid in order:
    positions.append(len(body));blob=bytearray(glyph(gid))
    if gid==digits[7]:blob=bytearray(add_rect(blob,7))
    for pos,child in components(blob):struct.pack_into('>H',blob,pos,mapping[child])
    body+=blob;body+=b'\0'*(-len(body)%4)
    advance=u16(tables[b'hmtx'],min(gid,metric_count-1)*4)
    bearing=s16(tables[b'hmtx'],gid*4+2 if gid<metric_count else metric_count*4+(gid-metric_count)*2)
    metrics+=struct.pack('>Hh',advance,bearing)
positions.append(len(body))
assert [mapping[g] for g in digits]==list(range(1,11))
keep={tag:tables[tag] for tag in (b'head',b'hhea',b'maxp',b'OS/2',b'gasp',b'cvt ',b'fpgm',b'prep') if tag in tables}
keep[b'head']=bytearray(keep[b'head']);struct.pack_into('>I',keep[b'head'],8,0);struct.pack_into('>h',keep[b'head'],50,1)
keep[b'hhea']=bytearray(keep[b'hhea']);struct.pack_into('>H',keep[b'hhea'],34,len(order))
keep[b'maxp']=bytearray(keep[b'maxp']);struct.pack_into('>H',keep[b'maxp'],4,len(order))
keep[b'glyf']=bytes(body);keep[b'loca']=struct.pack('>'+str(len(positions))+'I',*positions);keep[b'hmtx']=bytes(metrics)
sub=struct.pack('>7H',4,32,0,4,4,1,0)+struct.pack('>5H',57,65535,0,48,65535)+struct.pack('>2h',-47,1)+b'\0'*4
keep[b'cmap']=struct.pack('>HHHHI',0,1,3,1,12)+sub
names={0:'Copyright 2010 The Bangers Project Authors',1:'TRG Comic Result Digits',2:'Regular',3:'TRG Comic Result Digits 1.0',4:'TRG Comic Result Digits',5:'Version 1.0',6:'TRGComicResultDigits',13:'SIL Open Font License 1.1; derived from Bangers.'}
strings=b'';records=b''
for key,value in names.items():
    encoded=value.encode('utf-16-be');records+=struct.pack('>6H',3,1,0x409,key,len(encoded),len(strings));strings+=encoded
keep[b'name']=struct.pack('>3H',0,len(names),6+12*len(names))+records+strings
keep[b'post']=struct.pack('>I',0x30000)+tables[b'post'][4:32]
def checksum(blob):
    blob=bytes(blob)+b'\0'*(-len(blob)%4)
    return sum(struct.unpack('>'+str(len(blob)//4)+'I',blob))&0xffffffff
n=len(keep);power=2**int(math.log2(n));directory=b'';payload=b'';offset=12+16*n;head_at=0
for tag,blob in sorted(keep.items()):
    blob=bytes(blob);directory+=struct.pack('>4sIII',tag,checksum(blob),offset,len(blob))
    if tag==b'head':head_at=offset
    payload+=blob+b'\0'*(-len(blob)%4);offset=12+16*n+len(payload)
font=bytearray(struct.pack('>I4H',0x10000,n,power*16,int(math.log2(power)),n*16-power*16)+directory+payload)
struct.pack_into('>I',font,head_at+8,(0xb1b0afba-checksum(font))&0xffffffff)
assert checksum(font)==0xb1b0afba
OUTPUT.write_bytes(font)
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(data).hexdigest(),'output':str(OUTPUT.relative_to(ROOT)),'bytes':len(font),'glyphs':len(order),'digits':'0123456789','modified_digits':['7 crossbar'],'unchanged_digits':'012345689','sha256':hashlib.sha256(font).hexdigest()}
(ROOT/'assets/fonts/TRGComicResultDigits-manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
