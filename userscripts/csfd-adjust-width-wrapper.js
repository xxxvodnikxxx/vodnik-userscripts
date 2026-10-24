// ==UserScript==
// @name         ČSFD - Adjustable Content Width
// @namespace    cz.vodnikovo.csfd
// @version      2.0.0
// @description  Add a floating slider to adjust the content width on CSFD.cz, relatively in percent screen width
// @author       xxxvodnikxxx
// @match        https://www.csfd.cz/*
// @icon         https://www.csfd.cz/favicon.ico
// @homepageURL  https://github.com/xxxvodnikxxx/vodnik-userscripts
// @downloadURL  https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/userscripts/csfd-adjust-width-wrapper.js
// @updateURL    https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/userscripts/csfd-adjust-width-wrapper.js
// @run-at       document-idle
// @grant        GM_getValue
// @grant        GM_setValue
// @license MIT 
// ==/UserScript==

(function () {
    'use strict';

    const STORAGE_KEY = 'csfd-width-adjuster-percent';
    const DEFAULT_PERCENT = 80;
    const MIN_PERCENT = 50;
    const MAX_PERCENT = 100;

    let currentPercent = DEFAULT_PERCENT;
    let widthOverrideActive = false;

    console.info('[CSFD Width] Userscript loaded.');

    function createSlider() {
        if (document.getElementById('csfd-width-adjuster')) {
            return;
        }

        const panel = document.createElement('div');
        panel.id = 'csfd-width-adjuster';

        panel.style.cssText = `
            position: fixed;
            right: 15px;
            bottom: 15px;
            z-index: 99999;
            width: 230px;
            padding: 12px 14px;
            background: rgba(25, 25, 25, 0.95);
            color: #fff;
            border: 1px solid #555;
            border-radius: 8px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.35);
            font: 13px/1.4 Arial, sans-serif;
        `;

        const header = document.createElement('div');
        header.style.cssText = `
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
            font-weight: bold;
        `;

        const title = document.createElement('span');
        title.textContent = 'Šířka stránky';

        const valueLabel = document.createElement('span');
        valueLabel.textContent = 'Původní';

        header.append(title, valueLabel);

        const slider = document.createElement('input');
        slider.type = 'range';
        slider.min = String(MIN_PERCENT);
        slider.max = String(MAX_PERCENT);
        slider.step = '1';
        slider.value = String(DEFAULT_PERCENT);
        slider.style.cssText = `
            display: block;
            width: 100%;
            margin: 8px 0;
            cursor: pointer;
        `;

        const scale = document.createElement('div');
        scale.style.cssText = `
            display: flex;
            justify-content: space-between;
            color: #ccc;
            font-size: 11px;
        `;

        const minLabel = document.createElement('span');
        minLabel.textContent = `${MIN_PERCENT} %`;

        const maxLabel = document.createElement('span');
        maxLabel.textContent = `${MAX_PERCENT} %`;

        scale.append(minLabel, maxLabel);

        const resetButton = document.createElement('button');
        resetButton.type = 'button';
        resetButton.textContent = 'Obnovit původní šířku';
        resetButton.style.cssText = `
            width: 100%;
            margin-top: 10px;
            padding: 6px;
            border: 1px solid #777;
            border-radius: 4px;
            background: #383838;
            color: #fff;
            cursor: pointer;
        `;

        panel.append(header, slider, scale, resetButton);
        document.body.appendChild(panel);

        // Load the saved value for the slider only.
        // Do not apply it automatically on page load.
        const savedValue = Number(localStorage.getItem(STORAGE_KEY));

        if (
            Number.isFinite(savedValue) &&
            savedValue >= MIN_PERCENT &&
            savedValue <= MAX_PERCENT
        ) {
            slider.value = String(savedValue);
        }

        slider.addEventListener('input', function () {
            currentPercent = Number(slider.value);
            widthOverrideActive = true;

            valueLabel.textContent = `${currentPercent} %`;
            localStorage.setItem(STORAGE_KEY, String(currentPercent));

            applyWidth();
        });

        resetButton.addEventListener('click', function () {
            restoreOriginalWidth();

            slider.value = String(DEFAULT_PERCENT);
            valueLabel.textContent = 'Původní';
        });
    }

    function applyWidth() {
        const pageWrapper = document.querySelector('#page-wrapper');

        if (!pageWrapper) {
            console.warn('[CSFD Width] #page-wrapper not found.');
            return;
        }

        // Calculate the target width from the current viewport.
        const viewportWidth = document.documentElement.clientWidth;
        const targetWidth = Math.floor(
            viewportWidth * currentPercent / 100
        );

        // Expand and center the main wrapper.
        pageWrapper.style.setProperty('width', `${targetWidth}px`, 'important');
        pageWrapper.style.setProperty('max-width', `${targetWidth}px`, 'important');
        pageWrapper.style.setProperty('min-width', '0', 'important');
        pageWrapper.style.setProperty('box-sizing', 'border-box', 'important');
        pageWrapper.style.setProperty('margin-left', 'auto', 'important');
        pageWrapper.style.setProperty('margin-right', 'auto', 'important');

        // Ensure the outer page container can accommodate the wrapper.
        const bodyWrapper = document.querySelector('.body');

        if (bodyWrapper) {
            bodyWrapper.style.setProperty('width', '100%', 'important');
            bodyWrapper.style.setProperty('max-width', 'none', 'important');
            bodyWrapper.style.setProperty('box-sizing', 'border-box', 'important');
        }

        // Let the main content containers use the available wrapper width.
        const innerSelectors = [
            '.page-content',
            '.tv-main',
            '#tabs',
            '.tab-content',
            '.row',
            '.column-minus-300'
        ];

        innerSelectors.forEach(function (selector) {
            pageWrapper.querySelectorAll(selector).forEach(function (element) {
                element.style.setProperty('width', '100%', 'important');
                element.style.setProperty('max-width', '100%', 'important');
                element.style.setProperty('min-width', '0', 'important');
                element.style.setProperty('box-sizing', 'border-box', 'important');
            });
        });

        console.info(
            '[CSFD Width] Requested:',
            `${currentPercent}% (${targetWidth}px)`,
            '| Applied:',
            `${Math.round(pageWrapper.getBoundingClientRect().width)}px`
        );
    }

    function restoreOriginalWidth() {
        widthOverrideActive = false;

        const pageWrapper = document.querySelector('#page-wrapper');
        const bodyWrapper = document.querySelector('.body');

        // Remove only the inline overrides created by this script.
        if (pageWrapper) {
            [
                'width',
                'max-width',
                'min-width',
                'box-sizing',
                'margin-left',
                'margin-right'
            ].forEach(function (property) {
                pageWrapper.style.removeProperty(property);
            });

            const innerSelectors = [
                '.page-content',
                '.tv-main',
                '#tabs',
                '.tab-content',
                '.row',
                '.column-minus-300'
            ];

            innerSelectors.forEach(function (selector) {
                pageWrapper.querySelectorAll(selector).forEach(function (element) {
                    [
                        'width',
                        'max-width',
                        'min-width',
                        'box-sizing'
                    ].forEach(function (property) {
                        element.style.removeProperty(property);
                    });
                });
            });
        }

        if (bodyWrapper) {
            [
                'width',
                'max-width',
                'box-sizing'
            ].forEach(function (property) {
                bodyWrapper.style.removeProperty(property);
            });
        }

        console.info('[CSFD Width] Original page width restored.');
    }

    window.addEventListener('resize', function () {
        if (widthOverrideActive) {
            applyWidth();
        }
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createSlider);
    } else {
        createSlider();
    }
})();
