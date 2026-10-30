"""Generate emoji-based icons: python3 tools/generate_emoji_icons.py

All glyphs come from Noto Color Emoji (SIL Open Font License 1.1).
- laws/LAW_0N.png: the 8 special-victory law icons on a dark warm backdrop with a golden glow,
  sized like the painted illustrations (1254 px) so the draft card and rulebook slots treat them the same way.
- pawns/<SUBTYPE>.png: transparent 256 px board tokens for the arcade pawn set, with a white sticker outline.
- assets/cards/<CARD>.png: 4:3 card illustrations (1448 x 1086, like the painted cards) for the v4.0 cards without a painting,
  on a soft backdrop tinted by the card type.
- assets/board/traps/<TRAP>.png: transparent 128 px tile stickers drawn on a purple trap tile (HIDDEN = an opponent's face-down trap).

Pass group names (laws pawns cards traps) to write only those groups.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1] / 'content_trickcal/illustrations'
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
PAWNS = {
    'CHECKERS_KING': '\U0001F451',     # 체커 킹: 왕관
    'LUDO_AVENGER': '\U0001F525',      # 루도 복수자: 불꽃
    'POOL_8BALL': '\U0001F3B1',        # 8번 공
    'KART_STAR': '\U0001F3CE\ufe0f',  # 스타 카트: 경주차
    'MINESWEEPER_FLAG': '\U0001F6A9',  # 지뢰찾기 공병: 깃발
}
TOKEN = 256
CARD_ROOT = Path(__file__).resolve().parents[1] / 'assets/cards'
CARD_SIZE = (1448, 1086)
# card id -> (glyph, backdrop tint)
COUNTER, INSTANT, TRAP, CORNER = (92, 124, 250), (255, 168, 76), (176, 120, 214), (120, 80, 170)
CARDS = {
    'CNT_04': ('\U0001F4A8', COUNTER),        # 빗나감!: 휙
    'CNT_05': ('\U0001F32A\ufe0f', COUNTER),  # 싸이크론: 회오리
    'CNT_06': ('\U0001F4DC', COUNTER),        # 왕궁의 포고령: 두루마리
    'CNT_07': ('\u26CF\ufe0f', COUNTER),      # 도굴꾼: 곡괭이
    'ACT_10': ('\U0001F528', INSTANT),        # 빠루: 망치
    'ACT_11': ('\U0001F0CF', INSTANT),        # 밑장빼기: 조커
    'ACT_12': ('\u23F1\ufe0f', INSTANT),      # 더 월드: 스톱워치
    'ACT_13': ('\U0001F6AA', INSTANT),        # 어디로든 문
    'ACT_14': ('\U0001F6AB', INSTANT),        # 알고리즘 밴
    'ACT_15': ('\u23ED\ufe0f', INSTANT),      # 우노 스킵
    'TRP_06': ('\U0001F34C', TRAP),           # 바나나 껍질
    'TRP_07': ('\U0001F335', TRAP),           # 스파이크: 선인장 가시
    'TRP_08': ('\U0001F300', TRAP),           # 강제 환승 포탈: 소용돌이
    'TRP_C02': ('\U0001F998', CORNER),        # 피아식별 점프대: 캥거루
    'TRP_C03': ('\U0001F4B0', CORNER),        # 톨게이트: 돈 자루
    'TRP_C04': ('\U0001F6E2\ufe0f', CORNER),  # 타르: 기름통
}

TRAP_ROOT = Path(__file__).resolve().parents[1] / 'assets/board/traps'
TRAP_SIZE = 128
TRAPS = {
    'TRP_01': '\U0001FA9E',        # 거울의 힘: 거울
    'TRP_02': '\U0001F573\ufe0f',  # 나락: 구멍
    'TRP_03': '\U0001F4A3',        # 지뢰: 폭탄
    'TRP_05': '\U0001F938',        # 스프링 인간 대포: 재주넘기
    'TRP_06': '\U0001F34C',        # 바나나 껍질
    'TRP_07': '\U0001F335',        # 스파이크: 선인장
    'TRP_08': '\U0001F300',        # 강제 환승 포탈: 소용돌이
    'TRP_C01': '\U0001F3DD\ufe0f', # 무인도 감옥
    'TRP_C02': '\U0001F998',       # 피아식별 점프대: 캥거루
    'TRP_C03': '\U0001F4B0',       # 톨게이트: 돈 자루
    'TRP_C04': '\U0001F6E2\ufe0f', # 타르: 기름통
    'HIDDEN': '\u2753',            # 정체를 모르는 상대 함정
}


def card_art(text, tint):
    width, height = CARD_SIZE
    image = Image.new('RGBA', CARD_SIZE, (*[min(255, 200 + c // 5) for c in tint], 255))
    glow = Image.new('RGBA', CARD_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for radius, alpha in ((620, 90), (480, 120), (340, 150)):
        draw.ellipse((width // 2 - radius, height // 2 - radius, width // 2 + radius, height // 2 + radius), fill=(*tint, alpha))
    image = Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(110)))
    art = glyph(text, 620)
    if art.height > 720:
        art = art.resize((round(art.width * 720 / art.height), 720), Image.LANCZOS)
    x, y = (width - art.width) // 2, (height - art.height) // 2
    halo = Image.new('RGBA', CARD_SIZE, (0, 0, 0, 0))
    halo.paste((255, 255, 255, 230), (x, y), art.split()[3].point(lambda a: 255 if a > 20 else 0))
    image = Image.alpha_composite(image, halo.filter(ImageFilter.GaussianBlur(22)))
    image.alpha_composite(art, (x, y))
    return image.convert('RGB')


def backdrop():
    image = Image.new('RGBA', (SIZE, SIZE), (24, 14, 8, 255))
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for radius, alpha in ((560, 40), (470, 70), (380, 110)):
        center = SIZE // 2
        draw.ellipse((center - radius, center - radius, center + radius, center + radius), fill=(255, 176, 64, alpha))
    return Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(120)))


def glyph(text, width=760):
    font = ImageFont.truetype(FONT, 109)
    canvas = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).text((80, 80), text, font=font, embedded_color=True, anchor='mm')
    box = canvas.getbbox()
    return canvas.crop(box).resize((width, round(width * (box[3] - box[1]) / (box[2] - box[0]))), Image.LANCZOS)


def token(text):
    art = glyph(text, 216)
    image = Image.new('RGBA', (TOKEN, TOKEN), (0, 0, 0, 0))
    x, y = (TOKEN - art.width) // 2, TOKEN - art.height - 12
    outline = Image.new('RGBA', (TOKEN, TOKEN), (0, 0, 0, 0))
    mask = art.split()[3].point(lambda a: 255 if a > 40 else 0)
    outline.paste((255, 255, 255, 255), (x, y), mask)
    outline = outline.filter(ImageFilter.MaxFilter(9))
    image = Image.alpha_composite(image, outline)
    image.alpha_composite(art, (x, y))
    return image


def sticker(text):
    art = glyph(text, 104)
    if art.height > 104:
        art = art.resize((round(art.width * 104 / art.height), 104), Image.LANCZOS)
    image = Image.new('RGBA', (TRAP_SIZE, TRAP_SIZE), (0, 0, 0, 0))
    x, y = (TRAP_SIZE - art.width) // 2, (TRAP_SIZE - art.height) // 2
    outline = Image.new('RGBA', (TRAP_SIZE, TRAP_SIZE), (0, 0, 0, 0))
    outline.paste((255, 255, 255, 255), (x, y), art.split()[3].point(lambda a: 255 if a > 40 else 0))
    image = Image.alpha_composite(image, outline.filter(ImageFilter.MaxFilter(7)))
    image.alpha_composite(art, (x, y))
    return image


GROUPS = set(sys.argv[1:]) or {'laws', 'pawns', 'cards', 'traps'}

for law_id, text in (ICONS.items() if 'laws' in GROUPS else []):
    image = backdrop()
    art = glyph(text)
    x, y = (SIZE - art.width) // 2, (SIZE - art.height) // 2
    halo = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    mask = art.split()[3].point(lambda a: 255 if a > 20 else 0)
    halo.paste((255, 214, 120, 255), (x, y), mask)
    image = Image.alpha_composite(image, halo.filter(ImageFilter.GaussianBlur(28)))
    image.alpha_composite(art, (x, y))
    image.convert('RGB').save(ROOT / 'laws' / f'{law_id}.png')
    print('wrote', law_id)

for subtype, text in (PAWNS.items() if 'pawns' in GROUPS else []):
    token(text).save(ROOT / 'pawns' / f'{subtype}.png')
    print('wrote', subtype)

for card_id, (text, tint) in (CARDS.items() if 'cards' in GROUPS else []):
    card_art(text, tint).save(CARD_ROOT / f'{card_id}.png')
    print('wrote', card_id)

if 'traps' in GROUPS:
    TRAP_ROOT.mkdir(parents=True, exist_ok=True)
    for trap_id, text in TRAPS.items():
        sticker(text).save(TRAP_ROOT / f'{trap_id}.png', optimize=True)
        print('wrote', trap_id)
