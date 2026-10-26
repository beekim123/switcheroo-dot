"""Optional font maintenance: python3 tools/resources/subset-font.py ORIGINAL.ttf.
Requires fontTools; the normal offline build uses the committed, licensed subset.
"""
from pathlib import Path
import sys, hashlib, json
from fontTools import subset
from fontTools.ttLib import TTFont
root=Path(__file__).resolve().parents[2]
source=Path(sys.argv[1])
chars=set(chr(i) for i in range(32,127))|set('→←↔↑↓①②③♪！…？·「」【】（）—–×倍音试掀杯再锣声继续结束返回')
for folder in ['docs','content','godot/scripts']:
 for path in (root/folder).rglob('*'):
  if path.suffix in ['.md','.json','.gd']: chars.update(path.read_text())
font=TTFont(source,recalcTimestamp=False)
original_cmap=font.getBestCmap()
# Preserve all present text glyphs. Decorative Markdown emoji are not game text.
codepoints=sorted(ord(c) for c in chars if ord(c) in original_cmap)
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*'];options.recalc_timestamp=False
s=subset.Subsetter(options=options);s.populate(unicodes=codepoints);s.subset(font)
for record in font['name'].names:
 if record.nameID in (1,4,6,16):
  name='SwitcherooPixel12' if record.nameID==6 else 'Switcheroo Pixel 12'
  record.string=name.encode(record.getEncoding())
out=root/'third_party/fonts/fusion-pixel-12px/switcheroo-pixel-12.ttf';font.save(out)
assert out.stat().st_size<2_000_000
report={'format':'font-provenance/1','upstream':'https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25','upstream_filename':source.name,'upstream_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'modification':'Subset to project text plus ASCII; renamed Switcheroo Pixel 12; glyph outlines unchanged','glyph_codepoints':len(codepoints),'file':out.name,'size_bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'license':'OFL-1.1; all bundled notices preserved'}
(out.parent/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
