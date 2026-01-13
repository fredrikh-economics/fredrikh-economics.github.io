import { publications, currentWritings } from "../data/publications.js";

const $ = (sel) => document.querySelector(sel);

function normalize(s){
  return (s ?? "").toString().toLowerCase().normalize("NFKD");
}

function renderLinks(links = []){
  if(!links.length) return "";
  return `<div class="links">
    ${links.map(l => `<a class="link" href="${l.url}" target="_blank" rel="noreferrer">${l.label}</a>`).join("")}
  </div>`;
}

function renderItem(p){
  const pill = p.category ? `<span class="pill">${p.category}</span>` : "";
  const year = p.year ? `<span class="pill">${p.year}</span>` : "";
  const right = `<div style="display:flex;gap:8px;flex-wrap:wrap">${year}${pill}</div>`;
  const meta = [p.authors, p.venue].filter(Boolean).join(" · ");
  return `
    <div class="item">
      <div class="top">
        <div class="title">${p.title}</div>
        ${right}
      </div>
      <div class="meta">${meta}</div>
      ${renderLinks(p.links)}
    </div>
  `;
}

function initCurrent(){
  const el = $("#current-writings");
  el.innerHTML = currentWritings.map(renderItem).join("");
}

function initFilters(){
  const categories = ["All", ...Array.from(new Set(publications.map(p => p.category))).sort()];
  const sel = $("#category");
  sel.innerHTML = categories.map(c => `<option value="${c}">${c}</option>`).join("");
}

function applyFilters(){
  const q = normalize($("#search").value);
  const cat = $("#category").value;

  const filtered = publications
    .filter(p => cat === "All" ? true : p.category === cat)
    .filter(p => {
      if(!q) return true;
      const hay = normalize([p.title, p.authors, p.venue, p.category, p.year].join(" "));
      return hay.includes(q);
    })
    .sort((a,b) => (b.year ?? 0) - (a.year ?? 0));

  $("#pub-list").innerHTML = filtered.map(renderItem).join("");
}

initCurrent();
initFilters();
applyFilters();

$("#search").addEventListener("input", applyFilters);
$("#category").addEventListener("change", applyFilters);
