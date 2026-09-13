#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageChops
import math, random, struct, wave

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'assets' / 'textures'
AUD = ROOT / 'assets' / 'audio'
TEX.mkdir(parents=True, exist_ok=True)
AUD.mkdir(parents=True, exist_ok=True)
SIZE = 1024


def rng_noise(seed, size=SIZE, scale=64, blur=1.6):
    r = random.Random(seed)
    small = Image.new('L', (scale, scale))
    p = small.load()
    for y in range(scale):
        for x in range(scale):
            p[x, y] = r.randrange(256)
    img = small.resize((size, size), Image.Resampling.BICUBIC)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def normal_from_height(height, strength=3.0):
    h = height.convert('L')
    left = ImageChops.offset(h, -1, 0)
    right = ImageChops.offset(h, 1, 0)
    up = ImageChops.offset(h, 0, -1)
    down = ImageChops.offset(h, 0, 1)
    lp, rp, upx, dp = left.load(), right.load(), up.load(), down.load()
    out = Image.new('RGB', h.size)
    op = out.load()
    w, hh = h.size
    for y in range(hh):
        for x in range(w):
            dx = (rp[x,y] - lp[x,y]) / 255.0 * strength
            dy = (dp[x,y] - upx[x,y]) / 255.0 * strength
            nx, ny, nz = -dx, -dy, 1.0
            l = math.sqrt(nx*nx + ny*ny + nz*nz) or 1.0
            nx, ny, nz = nx/l, ny/l, nz/l
            op[x,y] = (int((nx*.5+.5)*255), int((ny*.5+.5)*255), int((nz*.5+.5)*255))
    return out


def tint_gray(gray, low, high):
    return ImageOps.colorize(gray, black=low, white=high).convert('RGB')


def concrete():
    base = rng_noise(101, scale=96, blur=1.0)
    fine = rng_noise(102, scale=256, blur=.45)
    h = Image.blend(base, fine, .28)
    img = tint_gray(h, '#24282a', '#7d8586')
    d = ImageDraw.Draw(img, 'RGBA')
    r = random.Random(103)
    for _ in range(185):
        x, y = r.randrange(SIZE), r.randrange(SIZE)
        rad = r.randrange(2, 10)
        d.ellipse((x-rad,y-rad,x+rad,y+rad), fill=(10,11,12,r.randrange(15,55)))
    for _ in range(22):
        x,y=r.randrange(SIZE),r.randrange(SIZE)
        pts=[(x,y)]
        for _ in range(r.randrange(3,8)):
            x += r.randrange(-45,46); y += r.randrange(18,75)
            pts.append((x,y))
        d.line(pts, fill=(12,14,15,95), width=r.randrange(1,4))
    img.save(TEX/'wall_concrete_albedo.png', optimize=True)
    normal_from_height(h, 2.8).save(TEX/'wall_concrete_normal.png', optimize=True)
    rough = ImageOps.autocontrast(Image.blend(rng_noise(104,scale=100), h, .42)).point(lambda v: 150 + v*95//255)
    rough.save(TEX/'wall_concrete_rough.png', optimize=True)


def metal():
    h = rng_noise(201, scale=128, blur=.65)
    img = tint_gray(h, '#1e272b', '#68767a')
    d = ImageDraw.Draw(img, 'RGBA')
    panel = 256
    for x in range(0,SIZE,panel): d.line((x,0,x,SIZE), fill=(5,9,10,220), width=5)
    for y in range(0,SIZE,panel): d.line((0,y,SIZE,y), fill=(5,9,10,220), width=5)
    for y in range(48,SIZE,panel):
        for x in range(48,SIZE,panel):
            d.ellipse((x-12,y-12,x+12,y+12), fill=(90,98,95,255), outline=(14,18,19,255), width=4)
    for y in (190, 702):
        d.rectangle((0,y,SIZE,y+48), fill=(118,32,23,220))
        for x in range(-60,SIZE+60,90):
            d.polygon([(x,y+48),(x+28,y+48),(x+72,y),(x+44,y)], fill=(31,29,24,170))
    img.save(TEX/'wall_metal_albedo.png', optimize=True)
    normal_from_height(h, 1.8).save(TEX/'wall_metal_normal.png', optimize=True)
    rough = rng_noise(202, scale=96).point(lambda v: 70 + v*130//255)
    rough.save(TEX/'wall_metal_rough.png', optimize=True)


def floor_tex():
    h = rng_noise(301, scale=128, blur=.8)
    img = tint_gray(h, '#171c1e', '#596064')
    d = ImageDraw.Draw(img, 'RGBA')
    tile=128
    for x in range(0,SIZE,tile): d.line((x,0,x,SIZE), fill=(6,8,9,155), width=4)
    for y in range(0,SIZE,tile): d.line((0,y,SIZE,y), fill=(6,8,9,155), width=4)
    r=random.Random(302)
    for _ in range(80):
        x,y=r.randrange(SIZE),r.randrange(SIZE)
        d.ellipse((x-18,y-8,x+18,y+8), fill=(80,58,35,r.randrange(18,55)))
    img.save(TEX/'floor_albedo.png', optimize=True)
    normal_from_height(h, 2.2).save(TEX/'floor_normal.png', optimize=True)
    rng_noise(303,scale=128).point(lambda v: 105 + v*125//255).save(TEX/'floor_rough.png', optimize=True)


def ceiling_tex():
    h = rng_noise(401, scale=80, blur=1.2)
    img = tint_gray(h, '#202528', '#697074')
    d = ImageDraw.Draw(img, 'RGBA')
    for x in range(0,SIZE,256): d.line((x,0,x,SIZE), fill=(8,10,12,170), width=4)
    for y in range(0,SIZE,256): d.line((0,y,SIZE,y), fill=(8,10,12,170), width=4)
    img.save(TEX/'ceiling_albedo.png', optimize=True)
    normal_from_height(h, 1.5).save(TEX/'ceiling_normal.png', optimize=True)
    rng_noise(402,scale=72).point(lambda v: 130 + v*110//255).save(TEX/'ceiling_rough.png', optimize=True)


def decals():
    sign = Image.new('RGBA',(512,256),(8,12,14,255))
    d = ImageDraw.Draw(sign)
    d.rounded_rectangle((12,12,500,244), radius=24, outline=(40,255,145,255), width=8, fill=(8,18,17,255))
    d.polygon([(70,128),(155,64),(155,104),(300,104),(300,152),(155,152),(155,192)], fill=(60,255,150,255))
    d.rectangle((328,62,450,194), outline=(215,236,224,255), width=8)
    d.rectangle((362,93,415,168), fill=(215,236,224,255))
    sign = sign.filter(ImageFilter.GaussianBlur(.3))
    sign.save(TEX/'sign.png', optimize=True)

    g = Image.new('RGBA',(512,512),(0,0,0,0)); dg=ImageDraw.Draw(g)
    r=random.Random(501)
    for _ in range(220):
        x,y=r.randrange(512),r.randrange(512); rx=r.randrange(4,55); ry=r.randrange(2,24)
        dg.ellipse((x-rx,y-ry,x+rx,y+ry), fill=(5,6,6,r.randrange(5,50)))
    g=g.filter(ImageFilter.GaussianBlur(6.0))
    g.save(TEX/'grime.png', optimize=True)

    icon = Image.new('RGBA',(512,512),(8,10,14,255)); di=ImageDraw.Draw(icon)
    di.rounded_rectangle((34,34,478,478), radius=90, fill=(18,23,29,255), outline=(213,42,24,255), width=18)
    di.polygon([(150,126),(370,256),(150,386)], fill=(205,35,22,255))
    di.ellipse((196,202,308,314), fill=(15,18,22,255), outline=(255,118,32,255), width=12)
    icon.save(ROOT/'icon.png', optimize=True)


def wav_write(path, samples, sr=22050):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        buf=bytearray()
        for s in samples:
            s=max(-1.0,min(1.0,s))
            buf += struct.pack('<h', int(s*32767))
        w.writeframes(buf)


def env_noise(i, sr, seed=1):
    x=(i*1103515245 + seed*12345) & 0x7fffffff
    return (x/0x3fffffff)-1.0


def music():
    sr=22050; dur=48.0; n=int(sr*dur); bpm=126.0; beat=60.0/bpm
    out=[]
    for i in range(n):
        t=i/sr; phase=t%beat; b=int(t/beat)
        kick=0.0
        if phase<0.16:
            f=75.0-38.0*(phase/.16); kick=math.sin(2*math.pi*f*phase)*math.exp(-phase*20.0)
        sn=0.0
        if b%2==1 and phase<0.12:
            sn=env_noise(i,sr,17)*math.exp(-phase*24.0)
        sub=math.sin(2*math.pi*(41.2 if (b//4)%2==0 else 46.25)*t)*0.24
        saw=((t*82.4)%1.0*2.0-1.0)*0.06
        pulse=(1.0 if (t*164.8)%1.0<.28 else -1.0)*0.035
        drone=math.sin(2*math.pi*27.5*t)*0.06 + math.sin(2*math.pi*55*t)*0.025
        hat=0.0
        eighth=t%(beat/2)
        if eighth<0.035: hat=env_noise(i,sr,29)*math.exp(-eighth*90)*0.11
        s=kick*.52+sn*.18+sub+saw+pulse+drone+hat
        s*=0.75+0.25*math.sin(2*math.pi*t/(beat*16))**2
        out.append(s*.74)
    wav_write(AUD/'music.wav',out,sr)


def sfx(name, dur, fn, sr=22050):
    n=int(sr*dur); wav_write(AUD/name,[fn(i/sr,i,sr) for i in range(n)],sr)


def audio_sfx():
    sfx('shot.wav',.24,lambda t,i,sr: (env_noise(i,sr,2)*math.exp(-t*28)*.72 + math.sin(2*math.pi*(180-120*t)*t)*math.exp(-t*15)*.6))
    sfx('hit.wav',.18,lambda t,i,sr: math.sin(2*math.pi*(620-350*t)*t)*math.exp(-t*22)*.45 + env_noise(i,sr,3)*math.exp(-t*32)*.18)
    sfx('damage.wav',.34,lambda t,i,sr: env_noise(i,sr,4)*math.exp(-t*8)*.42 + math.sin(2*math.pi*92*t)*math.exp(-t*7)*.32)
    sfx('enemy_hurt.wav',.46,lambda t,i,sr: (math.sin(2*math.pi*(155-65*t)*t)+.45*math.sin(2*math.pi*(311-90*t)*t))*math.exp(-t*5.5)*.34)
    sfx('enemy_die.wav',.90,lambda t,i,sr: (math.sin(2*math.pi*(120-80*t)*t)+.5*env_noise(i,sr,8))*math.exp(-t*3.2)*.48)
    sfx('unlock.wav',1.20,lambda t,i,sr: (math.sin(2*math.pi*(220+180*t)*t)*.26 + math.sin(2*math.pi*(440+260*t)*t)*.16)*math.exp(-t*1.8))


if __name__ == '__main__':
    concrete(); metal(); floor_tex(); ceiling_tex(); decals(); music(); audio_sfx()
    print('Generated textures, icon and audio assets.')
