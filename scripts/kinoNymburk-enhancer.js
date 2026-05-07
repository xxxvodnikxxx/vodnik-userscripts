// ==UserScript==
// @name         Kino Nymburk Enhancer
// @namespace    cz.vodnikovo.kinonymburk
// @version      2.4
// @description  Adds CSFD + ICS export buttons to movie listings
// @author       xxxvodnikxxx
// @match        https://www.kinonymburk.cz/*
// @icon         https://www.kinonymburk.cz/favicon.ico
// @grant        none
// ==/UserScript==

/*
    Last revision: 07.05.2026

    Scripts currently adds csfd search link + iCS export button to each movie listing on Kino Nymburk website. 
    It parses date from the listing and adds it to the calendar event, 
    so you can easily add it to your calendar with correct time. 
    
    It also tries to find link to the movie details page and adds it to the calendar event and CSFD search.
 */
(function () {
    "use strict";

    const DEFAULT_DURATION_MINUTES = 120;
    const CINEMA_NAME = "Městské Kino Sokol";
    const CINEMA_URL = "https://www.kinonymburk.cz/";
    const SUMMARY_PREFIX = "Kino NBK- ";
    const FILENAME_PREFIX = "Kino NBK- ";

    function encodeForCSFD(text) {
        return encodeURIComponent(text.trim());
    }

    function sanitizeFileName(text) {
        return text.replace(/[<>:"/\\|?*]/g, "").replace(/\s+/g, "_");
    }

    function escapeICS(text) {
        return (text || "")
            .replace(/\\/g, "\\\\")
            .replace(/\n/g, "\\n")
            .replace(/,/g, "\\,")
            .replace(/;/g, "\\;");
    }

    function formatICSDate(date) {
        const pad = n => String(n).padStart(2, "0");
        return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}T${pad(date.getHours())}${pad(date.getMinutes())}00`;
    }

    function parseDate(text) {
        const match = text.match(/(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4}).*?(\d{1,2}):(\d{2})/);
        if (!match) return null;

        return new Date(
            parseInt(match[3], 10),
            parseInt(match[2], 10) - 1,
            parseInt(match[1], 10),
            parseInt(match[4], 10),
            parseInt(match[5], 10)
        );
    }

    function getMovieURL(titleEl) {
        const movieLink = titleEl.closest("a") || titleEl.parentElement?.closest("a");

        if (!movieLink) return CINEMA_URL;

        const href = movieLink.getAttribute("href");
        if (!href) return CINEMA_URL;

        return href.startsWith("http")
            ? href
            : new URL(href, window.location.origin).href;
    }

    function createICS(title, description, startDate, movieURL = CINEMA_URL) {
        const endDate = new Date(startDate.getTime() + DEFAULT_DURATION_MINUTES * 60000);

        return [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//vodnikovo//Kino Nymburk//CZ",
            "BEGIN:VEVENT",
            `UID:${Date.now()}@kinonymburk.cz`,
            `DTSTAMP:${formatICSDate(new Date())}`,
            `DTSTART:${formatICSDate(startDate)}`,
            `DTEND:${formatICSDate(endDate)}`,
            `SUMMARY:${escapeICS(SUMMARY_PREFIX + title)}`,
            `DESCRIPTION:${escapeICS(description || title)}`,
            `LOCATION:${escapeICS(CINEMA_NAME)}`,
            `URL:${movieURL}`,
            "END:VEVENT",
            "END:VCALENDAR"
        ].join("\r\n");
    }

    function downloadICS(filename, content) {
        const blob = new Blob([content], { type: "text/calendar;charset=utf-8" });
        const url = URL.createObjectURL(blob);

        const a = document.createElement("a");
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();

        URL.revokeObjectURL(url);
    }

    function addButtons() {
        const movieTitles = [...document.querySelectorAll("h6")];

        movieTitles.forEach(titleEl => {
            const movieName = titleEl.textContent.trim();

            if (!movieName || movieName.length < 2) return;
            if (titleEl.dataset.enhanced === "true") return;

            const card = titleEl.closest("div");
            if (!card) return;

            const containerText = card.parentElement ? card.parentElement.innerText : card.innerText;
            const startDate = parseDate(containerText);

            if (!startDate) return;

            const movieURL = getMovieURL(titleEl);

            const controls = document.createElement("div");
            controls.style.display = "flex";
            controls.style.gap = "10px";
            controls.style.marginTop = "6px";
            controls.style.alignItems = "center";

            // CSFD link
            const csfdLink = document.createElement("a");
            csfdLink.href = `https://www.csfd.cz/hledat/?q=${encodeForCSFD(movieName)}`;
            csfdLink.target = "_blank";
            csfdLink.textContent = "CSFD";
            csfdLink.style.color = "#1877f2";
            csfdLink.style.fontWeight = "bold";
            csfdLink.style.textDecoration = "none";

            // ICS button
            const icsButton = document.createElement("button");
            icsButton.textContent = "📅 ICS";
            icsButton.style.padding = "4px 10px";
            icsButton.style.border = "none";
            icsButton.style.borderRadius = "6px";
            icsButton.style.background = "#28a745";
            icsButton.style.color = "white";
            icsButton.style.cursor = "pointer";
            icsButton.style.fontWeight = "bold";

            icsButton.onclick = (e) => {
                e.preventDefault();
                e.stopPropagation();

                const icsContent = createICS(
                    movieName,
                    `Film v kině ${CINEMA_NAME}\nWeb: ${movieURL}`,
                    startDate,
                    movieURL
                );

                downloadICS(
                    `${sanitizeFileName(FILENAME_PREFIX + movieName)}_${formatICSDate(startDate)}.ics`,
                    icsContent
                );
            };

            controls.appendChild(csfdLink);
            controls.appendChild(icsButton);

            titleEl.insertAdjacentElement("afterend", controls);

            titleEl.dataset.enhanced = "true";
        });
    }

    const observer = new MutationObserver(() => {
        addButtons();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    window.addEventListener("load", () => {
        setTimeout(addButtons, 1500);
    });

})();