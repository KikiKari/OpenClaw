# skill-python-hardener (container package)

Distribution image for the **python-hardener** Claude skill — it hardens Python
scripts (security review, `shell=True`/SQL-injection/bare-`except` fixes, logging,
atomic state writes, docstrings & type hints) and emits a companion Markdown doc.
Development complete, eval-backed (11/11 assertions).

> The skill is a `SKILL.md` prompt (no runtime code). This image simply carries the
> packaged `python-hardener.skill` (zip) and prints `SKILL.md`.

## Pull
```bash
docker pull ghcr.io/kikikari/skill-python-hardener:latest
```

## Use
```bash
# Print the skill definition
docker run --rm ghcr.io/kikikari/skill-python-hardener:latest

# Extract the packaged .skill (a zip with python-hardener/SKILL.md)
id=$(docker create ghcr.io/kikikari/skill-python-hardener:latest)
docker cp "$id":/skill/python-hardener.skill .
docker rm "$id"
```

Or install it directly through ClawHub:
```bash
openclaw skills install python-hardener
```

Source: [`abstraction-manager/python-hardener.skill`](https://github.com/KikiKari/OpenClaw/blob/gateway1/abstraction-manager/python-hardener.skill) ·
docs: [main README → Skill: python-hardener](https://github.com/KikiKari/OpenClaw#skill-python-hardener--✅-fertiggestellt)
