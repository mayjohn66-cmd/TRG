"""Generate the 8 special-victory law icons: python3 tools/generate_law_icons.py

Each icon is a Noto Color Emoji glyph (SIL Open Font License 1.1) on a dark warm backdrop with a golden glow,
sized like the painted illustrations (1254 px) so the draft card and rulebook slots treat them the same way.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1] / 'content_trickcal/illustrations/laws'
FONT = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'
SIZE = 1254
ICONS = {
    'LAW_01': '⚔️',      # 투기장의 지배자: 교차한 칼
    'LAW_02': '\U0001F3AB',        # 봉인된 에르핀의 식권: 티켓
    'LAW_03': '\U0001F3E8',        # 엘리아스 부동산 재벌: 호텔
    'LAW_04': '\U0001F3B2',        # 카이지의 한방 역전법: 주사위
    'LAW_05': '\U0001F578️',  # 사도 포위망: 거미줄
    'LAW_06': '\U0001F941',        # 해탈한 동네북의 역습: 북
    'LAW_07': '⚡',            # 초전도체 무한 동력: 번개
    'LAW_08': '\U0001F40E',        # 다크호스의 하극상: 말
}


def backdrop():
    image = Image.new('RGBA', (SIZE, SIZE), (24, 14, 8, 255))
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for radius, alpha in ((560, 40), (470, 70), (380, 110)):
        center = SIZE // 2
        draw.ellipse((center - radius, center - radius, center + radius, center + radius), fill=(255, 176, 64, alpha))
    return Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(120)))


def glyph(text):
    font = ImageFont.truetype(FONT, 109)
    canvas = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).text((80, 80), text, font=font, embedded_color=True, anchor='mm')
    box = canvas.getbbox()
    return canvas.crop(box).resize((760, round(760 * (box[3] - box[1]) / (box[2] - box[0]))), Image.LANCZOS)


for law_id, text in ICONS.items():
    image = backdrop()
    art = glyph(text)
    x, y = (SIZE - art.width) // 2, (SIZE - art.height) // 2
    halo = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    mask = art.split()[3].point(lambda a: 255 if a > 20 else 0)
    halo.paste((255, 214, 120, 255), (x, y), mask)
    image = Image.alpha_composite(image, halo.filter(ImageFilter.GaussianBlur(28)))
    image.alpha_composite(art, (x, y))
    image.convert('RGB').save(ROOT / f'{law_id}.png')
    print('wrote', law_id)
