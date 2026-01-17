const API_BASE = "https://m1k1npi660.execute-api.ap-northeast-1.amazonaws.com";

function $(id) { return document.getElementById(id); }

function setText(id, text, cls) {
  const el = $(id);
  el.className = cls || el.className;
  el.textContent = text;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function api(path, opts = {}) {
  const url = `${API_BASE}${path}`;
  const res = await fetch(url, opts);
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text }; }
  if (!res.ok) {
    const msg = json?.message ? json.message : `${res.status} ${res.statusText}`;
    throw new Error(msg);
  }
  return json;
}

function renderItems(items) {
  const tbody = $("itemsTbody");
  tbody.innerHTML = "";

  for (const it of items) {
    const tr = document.createElement("tr");

    const created = document.createElement("td");
    created.textContent = it.created_at || "";
    created.className = "mono small";

    const title = document.createElement("td");
    const a = document.createElement("a");
    a.href = "#";
    a.textContent = it.title || "(no title)";
    a.addEventListener("click", (e) => {
      e.preventDefault();
      loadDetail(it.id);
    });
    title.appendChild(a);

    const category = document.createElement("td");
    category.innerHTML = it.category ? `<span class="pill">${escapeHtml(it.category)}</span>` : "";

    const priority = document.createElement("td");
    priority.innerHTML = it.priority ? `<span class="pill">${escapeHtml(it.priority)}</span>` : "";

    tr.appendChild(created);
    tr.appendChild(title);
    tr.appendChild(category);
    tr.appendChild(priority);
    tbody.appendChild(tr);
  }
}

async function refreshList() {
  setText("listError", "");
  setText("listStatus", "読み込み中…");
  const limit = $("limit").value;

  try {
    const data = await api(`/items?limit=${encodeURIComponent(limit)}`, { method: "GET" });
    renderItems(data.items || []);
    setText("listStatus", `取得件数: ${data.count ?? (data.items || []).length}`);
  } catch (e) {
    setText("listStatus", "");
    setText("listError", `一覧取得に失敗: ${e.message}`);
  }
}

async function loadDetail(id) {
  setText("detailError", "");
  setText("detail", "読み込み中…", "small muted");

  try {
    const data = await api(`/items/${encodeURIComponent(id)}`, { method: "GET" });
    const it = data.item;
    const html = `
      <div><strong>${escapeHtml(it.title)}</strong></div>
      <div class="muted mono small" style="margin-top:6px;">id: ${escapeHtml(it.id)} / ${escapeHtml(it.created_at)}</div>
      <div style="margin-top:8px;">
        ${it.category ? `<span class="pill">${escapeHtml(it.category)}</span>` : ""}
        ${it.priority ? `<span class="pill" style="margin-left:6px;">${escapeHtml(it.priority)}</span>` : ""}
        ${it.author ? `<span class="pill" style="margin-left:6px;">${escapeHtml(it.author)}</span>` : ""}
      </div>
      <pre style="white-space:pre-wrap; margin-top:10px;">${escapeHtml(it.body)}</pre>
    `;
    $("detail").className = "";
    $("detail").innerHTML = html;
  } catch (e) {
    setText("detail", "");
    setText("detailError", `詳細取得に失敗: ${e.message}`);
  }
}

async function createItem() {
  setText("createStatus", "", "small");
  const payload = {
    title: $("title").value,
    category: $("category").value,
    priority: $("priority").value,
    body: $("body").value,
    author: $("author").value,
  };

  // 必須チェック（フロント側の最小）
  if (!payload.title.trim()) {
    setText("createStatus", "タイトルは必須です", "err small");
    return;
  }
  if (!payload.body.trim()) {
    setText("createStatus", "本文は必須です", "err small");
    return;
  }

  try {
    setText("createStatus", "送信中…", "small muted");
    const data = await api("/items", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });

    setText("createStatus", "登録しました", "ok small");
    // 入力リセット（好みで）
    $("title").value = "";
    $("body").value = "";
    // 一覧更新
    await refreshList();
    // 登録したものを詳細表示
    if (data?.item?.id) await loadDetail(data.item.id);
  } catch (e) {
    setText("createStatus", `登録に失敗: ${e.message}`, "err small");
  }
}

function init() {
  $("apiBase").textContent = API_BASE;
  $("btnRefresh").addEventListener("click", refreshList);
  $("btnCreate").addEventListener("click", createItem);
  refreshList();
}

init();
