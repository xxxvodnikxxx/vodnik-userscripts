// ==UserScript==
// @name         Wedos chmod helper CZ, net2ftp chmod helper
// @name:cs      Wedos chmod helper CZ, net2ftp chmod helper
// @namespace    cz.vodnikovo.wedos
// @version      1.0
// @description  Adds quick chmod 644/755 buttons on Wedos WebFTP chmod page
// @description:cs  Přidá tlačítka pro rychlé nastavení práv 644/755 na stránce Wedos WebFTP
// @license      CC-BY-NC-4.0
// @match        https://webftp.wedos.net/index.php*
// @grant        none
// @icon         https://vedos.cz/wp-content/uploads/2025/07/favicon_VEDOS-150x150.png
// @homepageURL  https://github.com/xxxvodnikxxx/vodnik-userscripts
// @downloadURL  https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/scripts/vedos-webFTP-chownEnhancer.js
// @updateURL    https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/scripts/vedos-webFTP-chownEnhancer.js
// ==/UserScript==

/*
    Last revision: 07.05.2026
    Tento skript přidává dvě tlačítka pro rychlé nastavení práv 644 a 755 na stránce Wedos WebFTP.
    -   Tlačítko pro 755 nastaví práva rwxr-xr-x pro všechny adresáře a zatrhne možnost "Změnit práva také všem podadresářům".
    -   Tlačítko pro 644 nastaví práva rw-r--r-- pro všechny položky (adresáře i soubory) a zatrhne obě možnosti "Změnit práva také všem podadresářům" i "…souborům".
    -   Skript je primárně určen pro české prostředí, ale měl by fungovat i v jiných jazykových verzích, pokud se nezmění struktura stránky.
*/

(function () {
    'use strict';

    // Spustí se pouze na chmod stránce (musí existovat formulář ChmodForm)
    const form = document.getElementById('ChmodForm');
    if (!form) return;

    /**
     * Načte všechny položky formuláře (adresáře i soubory).
     * @returns {{ index: string, isDir: boolean }[]}
     */
    function getItems() {
        const items = [];
        const inputs = form.querySelectorAll('input[type="hidden"][name$="[dirorfile]"]');
        inputs.forEach(function (input) {
            const match = input.name.match(/list\[(\d+)\]\[dirorfile\]/);
            if (match) {
                items.push({
                    index: match[1],
                    isDir: input.value === 'd'
                });
            }
        });
        return items;
    }

    /**
     * Nastaví checkbox podle jména v formuláři.
     */
    function setCheckbox(name, checked) {
        const cb = form.querySelector('input[name="' + name + '"]');
        if (cb) cb.checked = checked;
    }

    /**
     * Přímá aktualizace zobrazeného chmod čísla v inputu.
     */
    function setChmodInput(index, value) {
        const el = document.getElementById('chmod' + index);
        if (el) el.value = value;
    }

    /**
     * Nastaví práva 755 (rwxr-xr-x) pro daný index.
     * Zatrhne chmod_subdirectories, NEZATRHNE chmod_subfiles.
     */
    function applyChmod755(index) {
        setCheckbox('list[' + index + '][owner_read]',    true);
        setCheckbox('list[' + index + '][owner_write]',   true);
        setCheckbox('list[' + index + '][owner_execute]', true);
        setCheckbox('list[' + index + '][group_read]',    true);
        setCheckbox('list[' + index + '][group_write]',   false);
        setCheckbox('list[' + index + '][group_execute]', true);
        setCheckbox('list[' + index + '][other_read]',    true);
        setCheckbox('list[' + index + '][other_write]',   false);
        setCheckbox('list[' + index + '][other_execute]', true);
        setChmodInput(index, '755');
        setCheckbox('list[' + index + '][chmod_subdirectories]', true);
        setCheckbox('list[' + index + '][chmod_subfiles]',       false);
    }

    /**
     * Nastaví práva 644 (rw-r--r--) pro daný index.
     * Zatrhne chmod_subdirectories i chmod_subfiles (platí pro adresáře).
     */
    function applyChmod644(index) {
        setCheckbox('list[' + index + '][owner_read]',    true);
        setCheckbox('list[' + index + '][owner_write]',   true);
        setCheckbox('list[' + index + '][owner_execute]', false);
        setCheckbox('list[' + index + '][group_read]',    true);
        setCheckbox('list[' + index + '][group_write]',   false);
        setCheckbox('list[' + index + '][group_execute]', false);
        setCheckbox('list[' + index + '][other_read]',    true);
        setCheckbox('list[' + index + '][other_write]',   false);
        setCheckbox('list[' + index + '][other_execute]', false);
        setChmodInput(index, '644');
        setCheckbox('list[' + index + '][chmod_subdirectories]', true);
        setCheckbox('list[' + index + '][chmod_subfiles]',       true);
    }

    // --- Obsluha tlačítek ---

    function handleBtn755() {
        getItems().forEach(function (item) {
            if (item.isDir) {
                applyChmod755(item.index);
            }
        });
    }

    function handleBtn644() {
        getItems().forEach(function (item) {
            applyChmod644(item.index);
        });
    }

    // --- Vytvoření UI ---

    const container = document.createElement('div');
    container.style.cssText = [
        'margin: 10px 0',
        'padding: 8px 12px',
        'background: #e8f0fe',
        'border: 1px solid #7a9fd4',
        'border-radius: 5px',
        'display: inline-flex',
        'align-items: center',
        'gap: 8px'
    ].join(';');

    const label = document.createElement('span');
    label.textContent = 'Rychlé nastavení práv:';
    label.style.cssText = 'font-weight: bold; font-size: 13px; color: #333;';

    const btn755 = document.createElement('button');
    btn755.type = 'button';
    btn755.textContent = '755 – adresáře (+ podadresáře)';
    btn755.style.cssText = [
        'padding: 5px 14px',
        'background: #3a6bc4',
        'color: white',
        'border: none',
        'border-radius: 4px',
        'cursor: pointer',
        'font-size: 13px',
        'font-weight: bold'
    ].join(';');
    btn755.title = 'Nastaví 755 všem adresářům a zatrhne „Změnit práva také všem podadresářům"';
    btn755.addEventListener('click', handleBtn755);

    const btn644 = document.createElement('button');
    btn644.type = 'button';
    btn644.textContent = '644 – vše (+ podadresáře + soubory)';
    btn644.style.cssText = [
        'padding: 5px 14px',
        'background: #2e8a2e',
        'color: white',
        'border: none',
        'border-radius: 4px',
        'cursor: pointer',
        'font-size: 13px',
        'font-weight: bold'
    ].join(';');
    btn644.title = 'Nastaví 644 všem položkám a zatrhne „Změnit práva také všem podadresářům" i „…souborům"';
    btn644.addEventListener('click', handleBtn644);

    container.appendChild(label);
    container.appendChild(btn755);
    container.appendChild(btn644);

    // Vložení za nadpis h1
    const h1 = document.querySelector('h1');
    if (h1 && h1.parentNode) {
        h1.parentNode.insertBefore(container, h1.nextSibling);
    } else {
        // Záložní umístění – na začátek formuláře
        form.insertBefore(container, form.firstChild);
    }

})();
