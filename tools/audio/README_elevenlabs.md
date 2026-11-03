# ElevenLabs sound-effect generation

Files here:
- `sfx_prompts_en.csv` - 228 ready-to-use English prompts. Columns: file, section, priority, duration_s, loop, prompt.
- `sfx_prompts_en.md` - the same prompts, readable.
- `sfx_list_ko.md` - Korean list of existing sounds, where they are used, and the proposed new ones.

How to generate (needs a new session so the environment picks up the key and the network allow-list):
1. Environment has `ELEVENLABS_API_KEY` set and `api.elevenlabs.io` allowed. Verify with
   `npx -y @elevenlabs/cli@latest onboard check --env-path .env.local`. Never paste the key in chat or commit `.env.local` (it is git-ignored).
2. Call the sound-generation API per row (text = prompt, duration_seconds = duration_s, loop = true for loop rows; the API caps duration, so the 2 BGM rows cannot be generated this way).
3. Save as `content_trickcal/audio/sfx/<file>`. Files named like an existing event (e.g. `hop_01.ogg`) replace the old sound with no code change. New names need wiring in `scenes/sfx.gd` EVENTS plus a `Sfx.play(&"name")` call.
4. Start with rows marked `high` priority, listen, then do the rest (generation spends ElevenLabs credits).
