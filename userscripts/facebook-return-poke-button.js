// ==UserScript==
// @name         Facebook Poke Button
// @name:cs      Facebook Šťouchnutí tlačítko
// @namespace    cz.vodnikovo.facebook
// @version      1.6
// @description  Adds a "Poke" button in the Facebook left sidebar
// @description:cs  Přidává tlačítko „Šťouchnout“ do levého menu Facebooku
// @license      CC-BY-NC-4.0
// @author       xxxvodnikxxx
// @match        https://www.facebook.com/*
// @grant        none
// @icon         https://static.xx.fbcdn.net/rsrc.php/v4/ye/r/e0VzA17WKp6.png
// @homepageURL  https://github.com/xxxvodnikxxx/vodnik-userscripts
// @downloadURL  https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/userscripts/facebook-return-poke-button.js
// @updateURL    https://github.com/xxxvodnikxxx/vodnik-userscripts/raw/main/userscripts/facebook-return-poke-button.js
// ==/UserScript==

/*
    Last revision: 07.05.2026
*/

(function () {
    'use strict';

    const config = {
        pokeButtonText: "Poke",
        pokeButtonLink: "https://www.facebook.com/pokes",
    };

    function createPokeButton() {
        const existing = document.querySelector('#poke-button-div');
        if (existing) return;

        const pokeDiv = document.createElement('div');
        pokeDiv.id = 'poke-button-div';
        pokeDiv.setAttribute('data-visualcompletion', 'ignore-dynamic');
        pokeDiv.style.marginTop = '4px';
        pokeDiv.style.marginLeft = '8px';

        const pokeLink = document.createElement('a');
        pokeLink.href = config.pokeButtonLink;
        pokeLink.role = 'link';
        pokeLink.tabIndex = '0';
        pokeLink.textContent = config.pokeButtonText;
        pokeLink.style.display = 'flex';
        pokeLink.style.alignItems = 'center';
        pokeLink.style.gap = '8px';
        pokeLink.style.padding = '8px';
        pokeLink.style.borderRadius = '6px';
        pokeLink.style.color = 'white';
        pokeLink.style.backgroundColor = '#1877f2';
        pokeLink.style.fontWeight = '500';
        pokeLink.style.textDecoration = 'none';
        pokeLink.onmouseover = () => pokeLink.style.backgroundColor = '#165ec9';
        pokeLink.onmouseout = () => pokeLink.style.backgroundColor = '#1877f2';

        pokeDiv.appendChild(pokeLink);
        return pokeDiv;
    }

    function insertPokeButton() {
        // Try to find “Vzpomínky” span
        const spans = Array.from(document.querySelectorAll('span'))
            .filter(el => el.textContent.trim() === "Vzpomínky");

        if (spans.length === 0) return;

        const memoriesSpan = spans[0];
        const targetDiv = memoriesSpan.closest('div[role="link"], a[role="link"]');
        if (!targetDiv) return;

        if (!document.querySelector('#poke-button-div')) {
            const pokeButton = createPokeButton();
            targetDiv.parentNode.insertBefore(pokeButton, targetDiv.nextSibling);
            console.log("✅ Poke button added");
        }
    }

    // Observe DOM changes to handle SPA navigation
    const observer = new MutationObserver(() => {
        insertPokeButton();
    });

    observer.observe(document.body, { childList: true, subtree: true });

    // Try initial insertion
    insertPokeButton();

})();
