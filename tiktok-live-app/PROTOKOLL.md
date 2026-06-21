# Historical TikTok Test Protocol

This file previously mixed dated test observations with operational
instructions. Those observations are historical and have been retired from
the active documentation.

Current regression cases use runtime-supplied handles only:

- `@example_creator` and `example_creator` normalize identically;
- unrelated sidebar `LIVE` text is not a positive signal;
- offline/restricted URL extraction has empty stdout and exit `1`;
- overload exits `75` before Playwright starts;
- gateway/node results use the same normalized contract;
- signed URLs are represented by placeholders and are re-resolved for each
  playback test.

See `../skills/tiktok-live/references/TIKTOK.md` for the current contract.
