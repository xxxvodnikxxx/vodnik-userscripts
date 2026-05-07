// ==UserScript==
// @name         CSFD Notify Cleaner
// @namespace    cz.vodnikovo.csfd
// @version      2.2
// @description  Removes "watch later" notifications older than X days on CSFD (with progress bar)
// @match        *://*.csfd.cz/soukrome/chci-videt*
// @grant        none
// @author       xxxvodnikxxx
// @icon         https://www.csfd.cz/favicon.ico
// @homepage
// ==/UserScript==

/*
    Last revision: 07.05.2026

    Primary implemented for TV notifications, probably will work for any kind of notification 
    Be aware there might be an issue with parsing date in another format than CZ
*/

(function () {
  "use strict";

  // Configuration - adjust as needed
  // ignore notifications newer than this many days
  const DAYS_LIMIT = 5;
  // delay between deletions to avoid server overload (in milliseconds)
  const DELAY_MS = 1500;
  // Configuration end - do not edit below unless you know what you are doing

  const sleep = (ms) => new Promise(r => setTimeout(r, ms));

  function createUI() {
    const panel = document.createElement("div");
    panel.style.position = "fixed";
    panel.style.top = "20px";
    panel.style.right = "20px";
    panel.style.zIndex = "999999";
    panel.style.background = "#222";
    panel.style.padding = "15px";
    panel.style.borderRadius = "8px";
    panel.style.boxShadow = "0 0 10px rgba(0,0,0,0.5)";
    panel.style.color = "white";
    panel.style.width = "220px";
    panel.id = "vodnik-cleaner-panel";

    const button = document.createElement("button");
    button.textContent = "Clean Notifications";
    button.style.width = "100%";
    button.style.padding = "8px";
    button.style.cursor = "pointer";
    button.style.marginBottom = "10px";

    const progress = document.createElement("div");
    progress.style.height = "8px";
    progress.style.background = "#444";
    progress.style.borderRadius = "5px";
    progress.style.overflow = "hidden";

    const bar = document.createElement("div");
    bar.style.height = "100%";
    bar.style.width = "0%";
    bar.style.background = "#4caf50";
    bar.id = "vodnik-progress-bar";

    progress.appendChild(bar);
    panel.appendChild(button);
    panel.appendChild(progress);
    document.body.appendChild(panel);

    button.addEventListener("click", cleanNotifications);

    printLoadedHeader();
  }

  function printLoadedHeader(){
      console.log("************************************");
      console.log("### ✅ Vodnik cleaner UI loaded ###");
      console.log("************************************");
  }

  function parseDate(str) {
    const [d, m, y] = str.split(".");
    return new Date(`${y}-${m}-${d}`);
  }

  function daysBetween(d1, d2) {
    return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
  }

  async function cleanNotifications() {

  const rows = document.querySelectorAll(".watchlist-table-row");
  if (!rows.length) {
    alert("No watchlist rows found.");
    return;
  }

  const form = document.querySelector("#frm-reminderDismiss-form");
  if (!form) {
    alert("Delete form not found.");
    return;
  }

  const token = form.querySelector('input[name="_token_"]').value;
  const doValue = form.querySelector('input[name="_do"]').value;

  const now = new Date();
  let deletions = [];

  rows.forEach(row => {
    const movieTitleElement = row.querySelector("h3 a");
    const movieTitle = movieTitleElement ? movieTitleElement.textContent.trim() : "Unknown movie";

    const trs = row.querySelectorAll("table.modal-table-watchlist tr");

    trs.forEach(tr => {
      const text = tr.textContent.trim();

      const dateMatch = text.match(/(\d{2}\.\d{2}\.\d{4})/);
      if (!dateMatch) return;

      const timeMatch = text.match(/(\d{2}:\d{2})/);
      const channelMatch = text.match(/\b([A-Za-z0-9\s\+\-]+)\b(?=\s*\d{2}:\d{2})/);

      const notificationDate = parseDate(dateMatch[0]);
      const age = daysBetween(notificationDate, now);
      if (age <= DAYS_LIMIT) return;

      const link = tr.querySelector('a[href*="secureHandle"]');
      if (!link) return;

      const value = link.href.split("=").pop();

      deletions.push({
        value,
        movieTitle,
        date: dateMatch[0],
        time: timeMatch ? timeMatch[0] : "??:??",
        channel: channelMatch ? channelMatch[0].trim() : "Unknown",
        age
      });
    });
  });

  const total = deletions.length;
  if (!total) {
    alert("No old notifications found.");
    return;
  }

  const bar = document.getElementById("vodnik-progress-bar");

  console.log("🧹 Starting notification cleanup...");
  console.log("📊 Total to delete:", total);

  for (let i = 0; i < total; i++) {

    const item = deletions[i];

    console.groupCollapsed(`🗑 Deleting ${i + 1}/${total} — ${item.movieTitle}`);
    console.log("🎬 Movie:", item.movieTitle);
    console.log("📅 Date:", item.date);
    console.log("🕒 Time:", item.time);
    console.log("📺 Channel:", item.channel);
    console.log("⏳ Age (days):", item.age);
    console.log("🧾 _value_:", item.value);

    const formData = new URLSearchParams();
    formData.append("_token_", token);
    formData.append("_do", doValue);
    formData.append("_value_", item.value);

    const response = await fetch(form.action, {
      method: "POST",
      body: formData.toString(),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      credentials: "include"
    });

    console.log("📡 Response status:", response.status);
    console.groupEnd();

    bar.style.width = `${((i + 1) / total) * 100}%`;

    await sleep(DELAY_MS);
  }

  console.log("✅ Cleaning finished.");
  alert("Cleaning finished.");
  location.reload();
}

  window.addEventListener("load", () => {
    setTimeout(createUI, 1000);
  });

})();