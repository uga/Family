## 1.4.3 — 2026-09-03

### Fixed

- **A salt shaker said it was ready in 49 days.** Its cooldown is three. At login the client
  can answer a cooldown question with a start time that has not settled yet, and Family wrote
  down what it was told. It now refuses an answer that says a cooldown has more time left than
  it lasts, and the next scan records the real one.

- **Miners were shown a mining cooldown that does not exist.** A Gold Bar is smelted by a miner
  and transmuted by an alchemist, and only the alchemist waits — but Family could not tell the
  two apart, so any miner who could smelt gold or truesilver grew a Mining column on the
  Crafting panel that said *ready* for ever. It now asks which profession made the thing, not
  only what was made. The wrong mark already on your characters clears itself the next time
  that profession's window is opened.
