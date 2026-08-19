/**
 * A per-cell Run button for RISE slideshows.
 *
 * Why this exists
 * ---------------
 * RISE renders the notebook itself, but it does not ship JupyterLab's cell
 * toolbar (`@jupyterlab/cell-toolbar-extension` is absent from the Rise app
 * bundle), so a slideshow has no clickable way to run a cell -- only the
 * keyboard. During a lecture that is awkward.
 *
 * Why a real extension rather than injected JavaScript
 * ---------------------------------------------------
 * The Rise app does not expose JupyterLab's command registry on `window`, so
 * page-level scripts can only *simulate* a keystroke and hope Lumino resolves
 * it. Running as an extension gives us the genuine `commands.execute`.
 *
 * Why the slide does not jump when you click
 * ------------------------------------------
 * RISE keeps the deck in sync with the active cell:
 *
 *     panel.content.activeCellChanged.connect((sender, cell) => {
 *       const slide = Reveal.getSlides().find(s => s.contains(cell.node));
 *       if (slide) { Reveal.slide(...) }
 *     });
 *
 * That is what made Shift+Enter (`run-cell-and-select-next`) advance the deck.
 * Here we set the active cell to the one whose button was clicked -- a cell that
 * is by definition already on the visible slide -- so the handler navigates to
 * the slide it is already on, which is a no-op. We then run
 * `notebook:run-cell`, which does not move the selection.
 */

import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';
import { Cell, CodeCell } from '@jupyterlab/cells';
import { INotebookTracker, NotebookPanel } from '@jupyterlab/notebook';

const BUTTON_CLASS = 'dma-run-button';
const RUNNING_CLASS = 'dma-run-button-busy';

/** `notebook:run-cell` runs the active cell and leaves the selection alone. */
const RUN_COMMAND = 'notebook:run-cell';

const PLAY_ICON =
  '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true" ' +
  'focusable="false"><path d="M8 5.5v13l11-6.5z" fill="currentColor"/></svg>';

function addButton(
  app: JupyterFrontEnd,
  panel: NotebookPanel,
  cell: Cell
): void {
  if (!(cell instanceof CodeCell)) {
    return;
  }
  // Cell widgets are reused as RISE moves their nodes between slides, so a
  // button added once travels with the cell. Never add a second one.
  if (cell.node.querySelector(`.${BUTTON_CLASS}`)) {
    return;
  }

  const button = document.createElement('button');
  button.className = BUTTON_CLASS;
  button.type = 'button';
  button.title = 'Run this cell';
  button.setAttribute('aria-label', 'Run this cell');
  button.innerHTML = PLAY_ICON;

  button.addEventListener('click', async (event: MouseEvent) => {
    event.preventDefault();
    event.stopPropagation();

    const index = panel.content.widgets.indexOf(cell);
    if (index < 0) {
      return;
    }
    panel.content.activeCellIndex = index;

    // The button replaces the `[ ]:` prompt in slideshow mode, so it also has
    // to carry the "this is running" signal the prompt would have given.
    button.classList.add(RUNNING_CLASS);
    try {
      await app.commands.execute(RUN_COMMAND);
    } finally {
      button.classList.remove(RUNNING_CLASS);
    }
  });

  cell.node.appendChild(button);
}

function decorate(app: JupyterFrontEnd, panel: NotebookPanel): void {
  panel.content.widgets.forEach(cell => addButton(app, panel, cell));
}

const plugin: JupyterFrontEndPlugin<void> = {
  id: 'dma-rise-run-button:plugin',
  description: 'Adds a Run button to every code cell in a RISE slideshow.',
  autoStart: true,
  requires: [INotebookTracker],
  activate: (app: JupyterFrontEnd, tracker: INotebookTracker): void => {
    const track = (panel: NotebookPanel): void => {
      void panel.revealed.then(() => {
        decorate(app, panel);
        // Cells added or removed later (including while presenting) still get
        // a button. Deferred so the widget exists by the time we look for it.
        panel.content.model?.cells.changed.connect(() => {
          window.setTimeout(() => decorate(app, panel), 0);
        });
      });
    };

    tracker.forEach(track);
    tracker.widgetAdded.connect((_, panel) => track(panel));
  }
};

export default plugin;
