from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path('assets/ui/remaining')
OUT.mkdir(parents=True, exist_ok=True)

GLYPHS = {
'A':['010','101','111','101','101'], 'B':['110','101','110','101','110'],
'C':['011','100','100','100','011'], 'D':['110','101','101','101','110'],
'E':['111','100','110','100','111'], 'F':['111','100','110','100','100'],
'G':['011','100','101','101','011'], 'H':['101','101','111','101','101'],
'I':['111','010','010','010','111'], 'J':['001','001','001','101','010'],
'K':['101','101','110','101','101'], 'L':['100','100','100','100','111'],
'M':['101','111','111','101','101'], 'N':['101','111','111','111','101'],
'O':['010','101','101','101','010'], 'P':['110','101','110','100','100'],
'Q':['010','101','101','011','001'], 'R':['110','101','110','101','101'],
'S':['011','100','010','001','110'], 'T':['111','010','010','010','010'],
'U':['101','101','101','101','111'], 'V':['101','101','101','101','010'],
'W':['101','101','111','111','101'], 'X':['101','101','010','101','101'],
'Y':['101','101','010','010','010'], 'Z':['111','001','010','100','111'],
' ':['000','000','000','000','000'],
'Ü':['101','101','101','101','111'],
}

PALETTES = {
    'blue':  ['#240553','#291a72','#2f4091','#2c6faf','#4dd1dd','#92e5e8','#d2f9fa','#f5fafa','#240553'],
    'orange':['#810000','#a20000','#c2340b','#e15c0f','#f7ac38','#face43','#ffef57','#f8fcca','#651415'],
    'pink':  ['#47094d','#7a0475','#a41588','#c4398b','#f48d8a','#ffb6a5','#fac5be','#fff2f2','#47094d'],
    'green': ['#00292a','#004538','#006045','#007b46','#50b04a','#94c952','#c7e26e','#ecf5cb','#00292a'],
    'red':   ['#450018','#780021','#af1734','#d83848','#f26067','#ff9e9d','#ffd5ba','#fff2e6','#450018'],
}

BUTTONS = [
    ('zurueck', 'ZURÜCK', 'blue', 50),
    ('weiter', 'WEITER', 'blue', 50),
    ('menue', 'MENÜ', 'blue', 50),
    ('manuell_eingeben', 'MANUELL\nEINGEBEN', 'orange', 50),
    ('leeres_feld', 'LEERES\nFELD', 'orange', 50),
    ('neues_set', '+', 'orange', 27),
    ('wortpaar_hinzufuegen', '+ WORT\nPAAR', 'orange', 50),
    ('set_speichern', 'SET\nSPEICHERN', 'green', 50),
    ('beispielset', 'BEISPIEL\nSET', 'pink', 50),
    ('set_vorlage', '', 'pink', 50),
    ('entfernen', 'X', 'red', 27),
    ('abbrechen', 'ABBRECHEN', 'blue', 50),
]

def make_button(label, palette_name, width):
    dark, shadow, edge, shade, main, light, bright, white, ink = PALETTES[palette_name]
    height = 25
    im = Image.new('RGBA', (width,height), (0,0,0,0))
    d = ImageDraw.Draw(im)
    # Pixel-stepped silhouette and dark cast shadow.
    d.rectangle((3,1,width-5,23), fill=dark)
    d.rectangle((1,3,width-3,21), fill=dark)
    d.rectangle((0,5,width-2,19), fill=dark)
    d.rectangle((3,2,width-5,22), fill=shadow)
    d.rectangle((2,4,width-4,20), fill=edge)
    # Bevel frame, with deliberately blocky highlights and corners.
    d.rectangle((4,3,width-6,21), fill=shade)
    d.rectangle((5,4,width-7,19), fill=main)
    d.rectangle((5,4,width-8,5), fill=bright)
    d.rectangle((5,6,6,17), fill=light)
    d.rectangle((7,6,7,17), fill=white)
    d.rectangle((width-8,6,width-7,17), fill=shadow)
    d.rectangle((8,19,width-9,20), fill=edge)
    d.rectangle((9,18,width-11,18), fill=light)
    d.rectangle((9,7,width-11,17), fill=main)
    # Angular color patches echo the five supplied originals.
    d.polygon([(8,6),(width//3,6),(width//3+4,9),(width//2,9),(width//2,10),(11,10),(11,14),(8,14)], fill=shade)
    d.polygon([(width//2,6),(width-10,6),(width-10,9),(width-15,9),(width-15,8),(width//2+5,8)], fill=light)
    d.polygon([(width//2+4,14),(width-11,14),(width-11,17),(width//2+8,17)], fill=light)
    d.rectangle((8,21,width//2,21), fill=shade)
    d.rectangle((width//2+1,21,width-9,21), fill=light)
    d.point((5,5),fill=white)
    d.point((width-7,5),fill=white)
    d.point((5,18),fill=bright)
    d.point((width-7,18),fill=bright)
    if label == '+':
        d.rectangle((7, 7, width-8, 17), fill=main)
        cx = width // 2
        d.rectangle((cx-1, 7, cx+1, 17), fill=ink)
        d.rectangle((cx-5, 11, cx+5, 13), fill=ink)
    elif label == 'X':
        d.rectangle((7, 7, width-8, 17), fill=main)
        cx = width // 2
        for offset in range(4):
            d.rectangle((cx-5+offset*2, 8+offset*2, cx-4+offset*2, 9+offset*2), fill=ink)
            d.rectangle((cx+3-offset*2, 8+offset*2, cx+4-offset*2, 9+offset*2), fill=ink)
    elif label:
        lines = label.split('\n')
        for index, original_line in enumerate(lines):
            has_plus = original_line.startswith('+ ')
            text = original_line[2:] if has_plus else original_line
            step = 5 if len(text) <= 6 else 4
            text_width = len(text) * step - (step - 3)
            x = (width - text_width) // 2 + (5 if has_plus else 0)
            y = 10 if len(lines) == 1 else 7 + index * 7
            if has_plus:
                d.rectangle((x-7, y, x-7, y+4), fill=ink)
                d.rectangle((x-9, y+2, x-5, y+2), fill=ink)
            for char in text:
                for dy, row in enumerate(GLYPHS.get(char, GLYPHS[' '])):
                    for dx, pixel in enumerate(row):
                        if pixel == '1':
                            d.point((x+dx, y+dy), fill=ink)
                if char == 'Ü':
                    d.point((x, y-2), fill=ink)
                    d.point((x+2, y-2), fill=ink)
                x += step
    return im

previews=[]
for name,label,palette,width in BUTTONS:
    im=make_button(label,palette,width)
    im.save(OUT/f'{name}.png')
    previews.append((name,im))

# Preview sheet; original sprite PNGs above remain at native pixel resolution.
scale=4
cell_w,cell_h=220,130
sheet=Image.new('RGB',(cell_w*3+40,cell_h*4+30),'#17191e')
for i,(name,im) in enumerate(previews):
    col,row=i%3,i//3
    enlarged=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
    x=20+col*cell_w+(cell_w-enlarged.width)//2
    y=15+row*cell_h+(cell_h-enlarged.height)//2
    sheet.paste(enlarged,(x,y),enlarged)
sheet.save(OUT/'uebersicht.png')
print(f'Created {len(previews)} buttons and overview in {OUT}')
