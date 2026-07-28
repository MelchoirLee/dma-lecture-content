# CS 0479 — Data Management and Analysis

Lecture notebooks for the course. Each lecture is a Jupyter notebook you can
**read, run, and watch as a slideshow**.

```
notebooks/lecture-01-overview-of-tooling-for-data-management-and-analysis.ipynb
notebooks/lecture-02-python-fundamentals.ipynb
…
notebooks/lecture-33-graph-databases-neo4j.ipynb
```

---

## 1. Getting started

Click **Code → Codespaces → Create codespace on main**.

The codespace installs everything for you — Python, JupyterLab, and the
libraries the lectures use. It takes a couple of minutes the first time.
**You never need to install anything or run a `pip` command.**

When it finishes, the terminal prints a box like this:

```
  ┌──────────────────────────────────────────────────────────────┐
  │  DMA lecture decks — JupyterLab + RISE                       │
  └──────────────────────────────────────────────────────────────┘

  Open:  http://127.0.0.1:8888/?token=…
```

**Click that link.** JupyterLab opens in a new browser tab. Open any lecture
from the `notebooks/` folder in the file browser on the left.

> **Lost the link?** Run `bash .devcontainer/start-jupyter.sh` in the terminal.
> You can also find it under the **Ports** tab (port 8888).

---

## 2. Turning a lecture into a slideshow

### Step 1 — press `Esc`

This puts the notebook in *command mode*. If your cursor is blinking inside a
code cell, keyboard shortcuts get typed into the cell instead of running.

### Step 2 — press `Option` + `R`  &nbsp;(Windows/Linux: `Alt` + `R`)

The slideshow opens in a panel beside the notebook. Use the **⛶ fullscreen
button** in that panel's toolbar to fill the screen.

To close it, click the **×** on the slideshow panel's tab.

---

## 3. Moving around a slideshow

| Key | What it does |
| --- | --- |
| `Space` or `→` | Next slide |
| `Shift`+`Space` or `←` | Previous slide |
| `↓` / `↑` | Move **within** a live example — its steps stack vertically under one slide |

If a slide has more content than fits on screen, just **scroll** — the slide
scrolls on its own.

### Running code during a lecture

Many slides hold real, runnable Python. Click a code cell, then:

| Key | What it does |
| --- | --- |
| `Shift`+`Enter` | Run the cell and **stay on the current slide** |
| `Ctrl`+`Enter` or `Cmd`+`Enter` | Same thing |

Edit the code and re-run it as much as you like; it's your own copy and
you can't affect anyone else.

---

## 4. What you'll see in a lecture

**Content slides** — the material itself: explanations, diagrams, formulas, and
code you can run.

**Live examples** — a teal banner marked 📈 `LIVE EXAMPLE`, followed by a working
notebook. These are meant to be run. Use `↓` to step through them.

**In-class exercises** — an amber card marked 🧪 `IN-CLASS EXERCISE`:

```
🧪 IN-CLASS EXERCISE
Finding Primes

Exercise link:  <PraireLearn URL here>
```

These are **signposts, not the exercise**. The exercise itself lives in PraireLearn,
Don't try to do it inside the notebook.

---

## 5. If something goes wrong

**The slideshow is blank / white.**
Give it a few seconds — a deck takes a moment to build. Also click inside the
browser tab: browsers don't draw tabs you haven't focused yet.

**`Option+R` does nothing.**
Either you're in edit mode (press `Esc` first — see step 1), or you're in the
**VS Code notebook editor** rather than JupyterLab. The slideshow is a
JupyterLab feature; VS Code cannot run it. Editing in VS Code is fine, but
presenting needs the JupyterLab link from the terminal.

**A plot didn't appear.**
Run that example's cells in order from the top — later cells usually depend on
variables defined in earlier ones.

**I broke a notebook.**
`git checkout -- notebooks/` restores every lecture to its original state.

---

## 6. Running on your own machine instead

You don't have to use Codespaces:

```bash
pip install -r requirements.txt
jupyter lab
```

One catch: your JupyterLab **must not** have the `jupyter-widgets`,
`pyviz`/`panel`, `plotly`, or `variableinspector` extensions installed. RISE
can't load alongside them and the slideshow comes up blank. Anaconda installs
ship these by default — which is exactly why the codespace uses a clean Python
image instead. If you're on Anaconda and hit a blank slideshow, use the
codespace.

---

*How these notebooks are generated and rebuilt: [MAINTAINING.md](MAINTAINING.md).*
