#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import math, random, struct, wave

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'assets' / 'textures'
AUD = ROOT / 'assets' / 'audio'
TEX.mkdir(parents=True, exist_ok=True)
AUD.mkdir(parents=True, exist_ok=True)
SIZE = 1024


def noise(seed, size=SIZE, coarse=96, blur=1.0):
    r = random.Random(seed)
    small = Image.new('L', (coarse, coarse))
    px = small.load()
    for y in range(coarse):
        for x in range(coarse):
            px[x, y] = r.randrange(256)
    img = small.resize((size, size), Image.Resampling.BICUBIC)
    return img.filter(ImageFilter.GaussianBlur(blur)) if blur else img


def make_wood():
    n = noise(201, coarse=160, blur=.45)
    img = Image.new('RGB', (SIZE, SIZE), (126, 88, 55))
    p = img.load(); q = n.load()
    for y in range(SIZE):
        plank = (y // 128) % 8
        for x in range(SIZE):
            grain = 18 * math.sin((x * .055) + math.sin(x * .012 + y * .019) * 2.0)
            v = q[x,y] - 128
            base = 105 + plank * 3 + int(grain * .55) + int(v * .10)
            p[x,y] = (max(55,min(170,base+28)), max(38,min(135,base)), max(25,min(100,base-28)))
    d = ImageDraw.Draw(img)
    for y in range(0, SIZE, 128):
        d.line((0,y,SIZE,y), fill=(55,37,25), width=5)
    for row,y in enumerate(range(0,SIZE,128)):
        offset = 0 if row % 2 == 0 else 256
        for x in range(offset, SIZE, 512):
            d.line((x,y,x,y+128), fill=(69,45,29), width=3)
    img = img.filter(ImageFilter.GaussianBlur(.18))
    img.save(TEX/'wood_color.jpg', quality=91, optimize=True)

    normal = Image.new('RGB',(SIZE,SIZE),(128,128,255)); dn=ImageDraw.Draw(normal)
    for y in range(0,SIZE,128):
        dn.line((0,y,SIZE,y), fill=(128,94,247), width=4)
        dn.line((0,y+4,SIZE,y+4), fill=(128,158,247), width=3)
    normal.save(TEX/'wood_normal.jpg', quality=90, optimize=True)
    rough = noise(202, coarse=140, blur=.5).point(lambda v: 105 + int(v*.30))
    rough.save(TEX/'wood_rough.jpg', quality=90, optimize=True)


def make_tile():
    img = Image.new('RGB',(SIZE,SIZE),(202,205,201)); d=ImageDraw.Draw(img)
    n=noise(301,coarse=120,blur=.6); np=n.load(); p=img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v=int((np[x,y]-128)*.08)
            p[x,y]=(max(180,min(222,202+v)),max(182,min(224,205+v)),max(180,min(222,201+v)))
    for x in range(0,SIZE,256): d.line((x,0,x,SIZE),fill=(120,125,122),width=8)
    for y in range(0,SIZE,256): d.line((0,y,SIZE,y),fill=(120,125,122),width=8)
    img.save(TEX/'tile_color.jpg',quality=92,optimize=True)
    normal=Image.new('RGB',(SIZE,SIZE),(128,128,255)); dn=ImageDraw.Draw(normal)
    for x in range(0,SIZE,256):
        dn.line((x,0,x,SIZE),fill=(98,128,245),width=6)
        dn.line((x+6,0,x+6,SIZE),fill=(158,128,245),width=5)
    for y in range(0,SIZE,256):
        dn.line((0,y,SIZE,y),fill=(128,98,245),width=6)
        dn.line((0,y+6,SIZE,y+6),fill=(128,158,245),width=5)
    normal.save(TEX/'tile_normal.jpg',quality=90,optimize=True)
    Image.new('L',(SIZE,SIZE),170).save(TEX/'tile_rough.jpg',quality=90,optimize=True)


def make_rug_and_icon():
    rug=Image.new('RGB',(1024,512),(52,67,87)); d=ImageDraw.Draw(rug)
    for i in range(10,500,38):
        d.rectangle((i,i//2,1024-i,max(i//2+8,512-i//2)),outline=(137,108,72),width=4)
    d.rectangle((20,20,1004,492),outline=(205,177,126),width=14)
    rug=Image.blend(rug,ImageOps.colorize(noise(401,size=1024,coarse=180,blur=.3).resize((1024,512)),'#18202a','#88909b').convert('RGB'),.12)
    rug.save(TEX/'rug.jpg',quality=91,optimize=True)

    icon=Image.new('RGBA',(512,512),(232,228,216,255)); di=ImageDraw.Draw(icon)
    di.rounded_rectangle((40,40,472,472),radius=96,fill=(41,48,58,255))
    di.polygon([(118,355),(118,207),(256,112),(394,207),(394,355)],fill=(224,218,200,255))
    di.rectangle((230,260,282,355),fill=(70,92,113,255))
    di.ellipse((344,96,430,182),fill=(201,55,42,255))
    icon.save(ROOT/'icon.png',optimize=True)


def write_mono(path, samples, sr=22050):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        buf=bytearray()
        for s in samples:
            s=max(-1.0,min(1.0,s)); buf+=struct.pack('<h',int(s*32767))
        w.writeframes(buf)


def write_stereo(path, left, right, sr=22050):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
        buf=bytearray()
        for l,r in zip(left,right):
            l=max(-1.0,min(1.0,l)); r=max(-1.0,min(1.0,r))
            buf+=struct.pack('<hh',int(l*32767),int(r*32767))
        w.writeframes(buf)


def make_music():
    # Clean, quiet 32-second loop: soft sine/triangle pads, bass and low percussion.
    sr=22050; dur=32.0; n=int(sr*dur)
    chords=[(110.00,164.81,220.00),(98.00,146.83,196.00),(130.81,164.81,261.63),(87.31,130.81,174.61)]
    left=[]; right=[]
    for i in range(n):
        t=i/sr; bar=int(t/8.0)%4; a,b,c=chords[bar]
        fade=min(1.0,(t%8.0)/1.3, (8.0-(t%8.0))/1.3)
        pad=(math.sin(2*math.pi*a*t)*.105 + math.sin(2*math.pi*b*t+.7)*.075 + math.sin(2*math.pi*c*t+1.3)*.055)*fade
        bass=math.sin(2*math.pi*(a/2.0)*t)*.085
        beat=t%1.0
        kick=math.sin(2*math.pi*(62-24*min(beat,.16)/.16)*beat)*math.exp(-beat*20)*.11 if beat<.18 else 0.0
        shimmer=math.sin(2*math.pi*(c*2)*t + math.sin(t*.6)*.4)*.014
        l=(pad+bass+kick+shimmer)*.72
        r=(pad+bass+kick-math.sin(2*math.pi*(b*2)*t)*.012)*.72
        left.append(l); right.append(r)
    write_stereo(AUD/'music.wav',left,right,sr)


def make_sfx():
    sr=22050
    def mk(name,dur,fn):
        write_mono(AUD/name,[fn(i/sr,i) for i in range(int(sr*dur))],sr)
    mk('hit.wav',.12,lambda t,i: math.sin(2*math.pi*(720-320*t)*t)*math.exp(-t*25)*.34)
    mk('damage.wav',.32,lambda t,i: (math.sin(2*math.pi*92*t)+.35*math.sin(2*math.pi*138*t))*math.exp(-t*7)*.24)
    mk('enemy_hurt.wav',.30,lambda t,i: (math.sin(2*math.pi*(165-40*t)*t)+.45*math.sin(2*math.pi*245*t))*math.exp(-t*8)*.27)
    mk('enemy_die.wav',.65,lambda t,i: (math.sin(2*math.pi*(112-58*t)*t)+.35*math.sin(2*math.pi*(170-80*t)*t))*math.exp(-t*4)*.34)
    mk('unlock.wav',.75,lambda t,i: (math.sin(2*math.pi*(330+210*t)*t)+.5*math.sin(2*math.pi*(495+260*t)*t))*math.exp(-t*2.8)*.18)


if __name__ == '__main__':
    make_wood(); make_tile(); make_rug_and_icon(); make_music(); make_sfx()
    print('Generated v2 house textures, clean music and local SFX.')
