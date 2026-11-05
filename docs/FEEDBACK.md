# Game sound and haptics

Build 30011 adds four original, locally bundled effects: card opening, correct
pair, mismatch and turn change. The reproducible sample-free WAV generator is
`scripts/synthesize-feedback.py`; only the WAV and provenance notice from
`app/assets/audio/` are bundled. There are no remote sound URLs,
recordings, advertisements or analytics. The web server serves WAV as `audio/wav`.

The game presentation drives feedback for local, online and Bluetooth play:

- An accepted visible opening starts the card cue. Invalid taps do not play it.
- A correct pair or mismatch plays only after both opening flips settle.
- A turn change plays after the mismatched cards finish closing.
- Repeated snapshots, initial/resumed boards and new-round baselines stay silent.
- Backgrounding or disposal stops playback and invalidates queued effects.

`GameFeedback` serializes effects through one player, with bounded queues and
generation checks. The sprite has at least one second of silence between audible
cues to tolerate delayed stop timers. Platform or browser permission failures
never block a move or affect the game result. A valid card tap primes web audio;
browsers may require that interaction before playing a remote move's sound.

Settings persist independently as `sound` and `haptics`, both enabled by default.
The pre-existing haptics preference is preserved. iOS uses an ambient audio
session, respecting Silent Mode and other audio; Android uses sonification without
requesting audio focus. Haptics use selection feedback for opening/turn, a light
impact for a correct pair and a medium impact for a mismatch. Browser haptics are
omitted because support is inconsistent.

Automated coverage includes effect ordering, queue cancellation, independent
preferences, errors, original asset integrity and the real presentation timeline
through opening/closing animations. Audibility and tactile strength still require
physical phone checks, including iOS Silent Mode, denied audio playback,
background/resume and both devices in a Bluetooth match.
