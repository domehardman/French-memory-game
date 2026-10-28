from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from zipfile import ZipFile, ZIP_DEFLATED

SOURCE = Path('assets/ui')
OUT = SOURCE / 'blank_backgrounds'
OUT.mkdir(parents=True, exist_ok=True)

ORANGE = ['#810000','#A20000','#C2340B','#E15C0F','#F48925','#F7AC38','#FACE43','#FFEF57','#F3FA75','#F8FCCA']
PALETTES = {
    'orange': ORANGE,
    'blue':  ['#240553','#291A72','#2F4091','#2C6FAF','#28ADCF','#4DD1DD','#92E5E8','#D2F9FA','#F5FAFA','#FFFFFF'],
    'green': ['#00292A','#004538','#006045','#007B46','#009644','#50B04A','#94C952','#C7E26E','#DBED98','#ECF5CB'],
    'pink':  ['#47094D','#7A0475','#A41588','#C4398B','#DC5D86','#F48D8A','#FFB6A5','#FAC5BE','#FAD9D9','#FFF2F2'],
    'red':   ['#450018','#780021','#AF1734','#D83848','#E94B59','#F26067','#FF9E9D','#FFD5BA','#FFE9D8','#FFF6ED'],
}

def rgb(color):
    return tuple(bytes.fromhex(color[1:]))

def mapping(source_palette, target_palette):
    return {rgb(a):rgb(b) for a,b in zip(source_palette,target_palette)}

orange_wide = Image.open(SOURCE/'campaign.png').convert('RGBA')
green_wide = Image.open(SOURCE/'play.png').convert('RGBA')
pink_wide = Image.open(SOURCE/'sets.png').convert('RGBA')
orange_square = Image.open(SOURCE/'power.png').convert('RGBA')
assert orange_wide.size == green_wide.size == pink_wide.size == (50,25)
assert orange_square.size == (27,25)

# The three wide buttons share the same original frame pixels. Their different
# lettering reveals the unpainted background behind nearly every text pixel.
green_to_orange = mapping(PALETTES['green'], ORANGE)
pink_to_orange = mapping(PALETTES['pink'], ORANGE)
blank_wide = orange_wide.copy()
for y in range(9,16):
    for x in range(10,40):
        candidates=[]
        for image, ink, remap in [
            (orange_wide, rgb('#651415'), None),
            (green_wide, rgb('#00292A'), green_to_orange),
            (pink_wide, rgb('#47094D'), pink_to_orange),
        ]:
            pixel=image.getpixel((x,y))
            if pixel[3] and pixel[:3] != ink:
                candidates.append(pixel[:3] if remap is None else remap[pixel[:3]])
        color=Counter(candidates).most_common(1)[0][0] if candidates else rgb('#F7AC38')
        blank_wide.putpixel((x,y),color+(255,))
# Any original dark lettering outside the central region is also replaced.
for y in range(7,18):
    for x in range(9,41):
        if blank_wide.getpixel((x,y))[:3] == rgb('#651415'):
            blank_wide.putpixel((x,y),rgb('#F7AC38')+(255,))

# Keep the exact square frame; restore only the center covered by its power icon
# from the now-clean, same-palette interior of the wide original.
blank_square = orange_square.copy()
for y in range(7,18):
    for x in range(8,20):
        blank_square.putpixel((x,y),blank_wide.getpixel((x+12,y)))

# The square original has three extra pale highlight colors.
EXTRA_SQUARE = {
    rgb('#FFF387'): 8,
    rgb('#FCF6C0'): 9,
    rgb('#ECF5CB'): 9,
}

outputs=[]
for name,palette in PALETTES.items():
    recolor = mapping(ORANGE,palette)
    for shape,source in [('wide',blank_wide),('square',blank_square)]:
        result=Image.new('RGBA',source.size,(0,0,0,0))
        for y in range(source.height):
            for x in range(source.width):
                pixel=source.getpixel((x,y))
                if pixel[3]:
                    index=EXTRA_SQUARE.get(pixel[:3])
                    target=rgb(palette[index]) if index is not None else recolor.get(pixel[:3],pixel[:3])
                    result.putpixel((x,y),target+(pixel[3],))
        output=OUT/f'{shape}_{name}.png'
        result.save(output)
        outputs.append(output)

# Preview only: enlargement uses nearest neighbor; source files stay at 1:1.
scale=6
sheet=Image.new('RGB',(760,900),'#17191e')
draw=ImageDraw.Draw(sheet)
font=ImageFont.load_default()
for i,name in enumerate(PALETTES):
    y=20+i*175
    draw.text((20,y+30),name.upper(),font=font,fill='white')
    wide=Image.open(OUT/f'wide_{name}.png')
    square=Image.open(OUT/f'square_{name}.png')
    for im,x in [(wide,140),(square,520)]:
        enlarged=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        sheet.paste(enlarged,(x,y),enlarged)
sheet.save(OUT/'uebersicht.png')
with ZipFile(OUT/'leere_button_hintergruende.zip','w',ZIP_DEFLATED) as archive:
    for output in outputs:
        archive.write(output,output.name)
print('Created',len(outputs),'exact-resolution blank backgrounds')
