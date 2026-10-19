# NPC cast v3 generation record

- Created: 2026-10-13
- Tool: Codex built-in image generation
- License/status: project-generated media
- References: `assets/production/hero/idle/idle-1.png` for the sole style standard; each character's `cast_v2/*/idle-transparent.png` for identity and costume only.
- Output contract: transparent 4x2 atlas; cell 1 neutral right-facing idle; cells 2-7 a complete right-facing six-frame walk cycle; cell 8 empty.
- Runtime processing: every atlas was normalized into 128x128 cells with a shared 88px visible body height and y=112 feet line. Dialogue portraits were derived exclusively from the neutral idle frame.

## Shared prompt

Redraw the named NPC for the Godot side-scrolling pixel game “渝见”. The protagonist reference is the only art-style standard; the NPC reference preserves identity only. Produce a transparent 4x2 sprite sheet: one natural right-facing idle frame, six coherent right-facing walk frames, and one empty cell. Keep identity, age, body type, hairstyle, costume, and Chongqing regional traits. Match the protagonist's crisp low-resolution pixel clusters, restrained dark-brown outline, simplified natural facial features, approximately 1:5.5 adult proportions, warm low-saturation palette, limited shading ramps, consistent body center, height, and feet line. No chibi proportions, anime portrait rendering, painterly realism, text, border, floor shadow, extra people, or props.

## Characters

- `flyer_lady`: flower headscarf, dark-red top, navy apron, cloth shoes, cross-body cloth bag.
- `old_artisan`: late-Qing/early-Republic artisan, brown short jacket and apron.
- `aming`: young workshop helper in a practical dark short jacket and trousers.
- `old_shopkeeper`: grey-haired elder shopkeeper in a traditional dark gown.
- `fat_teahouse`: stocky teahouse keeper in Republic-era short jacket and cloth trousers.
- `helper`: young porter in rolled-sleeve coarse work clothes.
- `laozhou`: weathered waterside fisherman in old cloth garments.
- `old_man`: gentle Chongqing elder in plain Chinese clothes.
- `tourist`: modern tourist in a light jacket, trousers, and small backpack.
- `vendor`: Chongqing street vendor in apron and everyday clothes.
- `refugee`: wartime Chongqing civilian with worn clothes and a light bundle.
