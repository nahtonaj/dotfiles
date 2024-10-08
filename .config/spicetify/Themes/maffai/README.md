# text

## Screenshots

#### Display Images

##### with images

![withimg](maffai/screenshots/Maffai.png)

-   **IMPORTANT:** Add the following to your `config-xpui.ini` file. Details as to why are explained [here](https://github.com/JulienMaille/spicetify-dynamic-theme#important). Run `spicetify apply` after adding these lines.

```ini
[Patch]
xpui.js_find_0880 = COLLAPSED\?64:32
xpui.js_repl_0880 = COLLAPSED?32:32
xpui.js_find_8008 = ,(\w+=)56,
xpui.js_repl_8008 = ,${1}32,
```

-   **SUGGESTION:** Feel free to edit `color.ini` to swap the accent color (it's green for most of them) into your preferred color based from the color pallete.

    -   https://github.com/catppuccin/catppuccin
    -   https://github.com/dracula/dracula-theme
    -   https://github.com/morhetz/gruvbox/
    -   https://github.com/rebelot/kanagawa.nvim
    -   https://github.com/nordtheme/nord
    -   https://github.com/Rigellute/rigel/
    -   https://github.com/rose-pine/rose-pine-theme
    -   https://github.com/altercation/solarized
    -   https://github.com/enkia/tokyo-night-vscode-theme

-   **SUGGESTION:** Check the very top of `user.css` for user settings

    -   If you use the Marketplace, go to `Marketplace > Snippets > + Add CSS` and then paste the variables found in `user.css` (also below). Edit these as you wish. If you're following this method, don't forget to add `!important` at the end of each property.

```css
/* user settings */
:root {
    --font-family: "DM Mono", monospace !important;
    /*
    --font-family: 'Anonymous Pro', monospace !important;
    --font-family: 'Courier Prime', monospace !important;
    --font-family: 'Cousine', monospace !important;
    --font-family: 'Cutive Mono', monospace !important;
    --font-family: 'DM Mono', monospace !important;
    --font-family: 'Fira Mono', monospace !important;
    --font-family: 'IBM Plex Mono', monospace !important;
    --font-family: 'Inconsolata', monospac !important;
    --font-family: 'Nanum Gothic Coding', monospace !important;
    --font-family: 'PT Mono', monospace !important;
    --font-family: 'Roboto Mono', monospace !important;
    --font-family: 'Share Tech Mono', monospace !important;
    --font-family: 'Source Code Pro', monospace !important;
    --font-family: 'Space Mono', monospace !important;
    --font-family: 'Ubuntu Mono', monospace !important;
    --font-family: 'VT323', monospace !important;
    */
    --font-size: 14px !important;
    --font-size-lyrics: 14px; /* 1.5em (default) */
    --font-weight: 400 !important; /* 200 : 900 */
    --line-height: 1.2 !important;

    --display-card-image: block !important; /* none | block */
    --display-coverart-image: none !important; /* none | block */
    --display-header-image: none !important; /* none | block */
    --display-library-image: block !important; /* none | block */
    --display-tracklist-image: none !important; /* none | block */

    --border-radius: 0px !important;
    --border-width: 1px !important;
    --border-style: solid !important; /* dotted | dashed | solid | double | groove | ridge | inset | outset */
}
```

-   **SUGGESTION:** For Windows users, here's how to make the window controls' background match with the topbar background

    -   Put this snippet into your `user.css` (or through the Marketplace's `+ Add CSS` feature)

```css
/* transparent window controls background */
body::after {
    content: "";
    position: absolute;
    right: 0;
    z-index: 999;
    backdrop-filter: brightness(2.12);
    /* page zoom [ctrl][+] or [ctrl][-]
       edit width and height accordingly
       this size is set for 100% zoom
    */
    width: 135px;
   /* depending on what global status bar 
      style is enabled height need to be 
      changed accordingly. */
    height: 64px;
}
```

![winctrl](screenshots/winctrl.png)
