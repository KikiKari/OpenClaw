# Distribution image for the "python-hardener" Claude skill.
# The skill itself is a SKILL.md prompt (no runtime code); this image carries
# the packaged .skill (zip) and prints SKILL.md by default.
# Build context: repository root.
FROM alpine:3.20

LABEL org.opencontainers.image.source="https://github.com/KikiKari/OpenClaw" \
      org.opencontainers.image.description="python-hardener — Claude skill that hardens Python scripts (security review, error handling, logging, docstrings) and emits companion docs. Install via: openclaw skills install python-hardener" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /skill
COPY packages/skill-python-hardener/python-hardener.skill packages/skill-python-hardener/SKILL.md ./

# Default: print the skill definition. Packaged skill: /skill/python-hardener.skill
CMD ["cat", "/skill/SKILL.md"]
