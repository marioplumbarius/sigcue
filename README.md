# sigcue

`sigcue` is a minimal, system-level notification layer for macOS engineered specifically for professionals with ADHD. It acts as an **External Salience Network**, transforming abstract upcoming commitments into un-ignorable visual triggers to minimize time blindness, hyperfocus lock, and prospective memory failures.

Unlike traditional apps that bury notifications inside passive trays, `sigcue` runs as a high-priority system interrupt layer that forces your brain to register critical real-time events.

## Components

|Component|Role|
|-|-|
|The Passive Salience Anchor (Floating Countdown)|A zero-overhead, terminal-style widget that floats permanently above all active workspaces—including native full-screen IDEs and browsers. It tracks your next high-priority event, dynamically shifting colors (Blue → Amber → Red) as the deadline nears to anchor your perception of time.|
|The Active System Interrupt (Forced Screen Takeover)|When an event is imminent, `sigcue` triggers a native `NSPanel` screen override. It dims your active workspace to gracefully break hyperfocus and blocks input until you explicitly choose a path: **Action Now** (instantly launches the relevant app or URL with zero friction), **Snooze** (strictly capped at 2 max), or **Dismiss** (requires an intentional confirmation hold to prevent impulsive bypassing).|

## Local Development

Build and run locally:

```bash
make dev
```

This builds the Debug variant and installs it to `/Applications/sigcue.app`. See the [Makefile](Makefile) for other targets (`make help` shows all available commands).

## The Science Behind It

### Working Memory Deficit

People with ADHD experience lower dopamine signaling in the prefrontal cortex, shrinking their mental workspace [[1]](https://www.adxs.org/en/page/150/organizational-and-executive-function-problems-in-adhd-neurophysiological-correlates). `sigcue` offloads temporary tracking tasks from your highly limited biological "RAM" into a persistent piece of external cognitive scaffolding [[2]](https://chadd.org/attention-article/remembering-the-future-how-adhd-affects-prospective-memory-and-how-to-work-with-it/).

### Time Blindness

Chronic dysfunction in the dopamine-regulated timing circuit of the basal ganglia and cerebellum prevents ADHD brains from accurately reproducing or pacing time intervals [[3]](https://www.reachlink.com/advice/adhd/russell-barkley-time-blindness/). `sigcue` replaces weak internal chronological awareness with an active, ticking, color-coded countdown.

### Synthetic Salience

The ADHD brain displays aberrant functional connectivity within the Salience Network (the anterior insula and anterior cingulate cortex), making it highly difficult to segregate critical future events from background noise [[4]](https://pmc.ncbi.nlm.nih.gov/articles/PMC3998750/)[[5]](https://pmc.ncbi.nlm.nih.gov/articles/PMC2899886/). `sigcue` forces your brain to process transitions by physically taking over the UI layer when it matters most.
