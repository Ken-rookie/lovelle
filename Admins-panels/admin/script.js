/* Lovelle Admin Studio
   Uses Supabase Auth + the project's publishable/anon key.
   Never place a service_role key in this file.
*/
(() => {
  "use strict";
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const state = {
    supabase: null, session: null, user: null, products: [], categories: [],
    orders: [], customers: [], currentPage: "overview", editingOrder: null,
    adminEmail: "", config: { url: "", key: "" }, selectedProductImage: null, productImageUrl: "", productImagePreviewUrl: null, dataErrors: {}
  };
  const CONFIG_KEY = "lovelle_admin_connection_v1";
  const DEFAULT_CONFIG = window.LOVELLE_ADMIN_CONFIG || {};
  const IMAGE_BUCKET = DEFAULT_CONFIG.imageBucket || "product-images";
  const MAX_IMAGE_SIZE = 5 * 1024 * 1024;
  const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[ch]));
  const money = value => "₱" + (Number(value) || 0).toLocaleString("en-PH", {minimumFractionDigits:2, maximumFractionDigits:2});
  const dateText = value => {
    if (!value) return "—";
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? "—" : date.toLocaleDateString("en-PH", {month:"short", day:"numeric", year:"numeric"});
  };
  const statusKey = value => String(value || "pending").toLowerCase().trim().replace(/\s+/g, "_");
  const statusLabel = value => ({
    pending:"Pending", confirmed:"Confirmed", preparing:"Being prepared", processing:"Processing",
    shipped:"Shipped", out_for_delivery:"Out for delivery", ready_for_pickup:"Ready for pickup",
    delivered:"Delivered", picked_up:"Picked up", cancelled:"Cancelled", pending_payment:"Pending payment",
    paid:"Paid", failed:"Failed", refunded:"Refunded"
  }[statusKey(value)] || String(value || "Pending").replace(/_/g," ").replace(/\b\w/g, c=>c.toUpperCase()));
  const icon = name => `<i data-lucide="${escapeHtml(name)}"></i>`;
  function refreshIcons(){ if (window.lucide) window.lucide.createIcons(); }
  function toast(message, type="success") {
    const region = $("#toast-region");
    const el = document.createElement("div");
    el.className = `toast toast-${type}`;
    el.innerHTML = `${icon(type==="error"?"alert-circle":"check-circle-2")}<span>${escapeHtml(message)}</span>`;
    region.appendChild(el); refreshIcons();
    setTimeout(()=>{el.classList.add("toast-out");setTimeout(()=>el.remove(),250)},3500);
  }
  function setLoginMessage(message, isError=true) {
    $("#login-message").textContent = message || "";
    $("#login-message").style.color = isError ? "#c44371" : "#4d9a70";
  }
  function loadConfig() {
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem(CONFIG_KEY) || "{}"); } catch {}
    state.config.url = saved.url || DEFAULT_CONFIG.url || "";
    state.config.key = saved.key || DEFAULT_CONFIG.key || "";
    state.adminEmail = (saved.adminEmail || DEFAULT_CONFIG.adminEmail || "").trim().toLowerCase();
    $("#config-url").value = state.config.url;
    $("#config-key").value = state.config.key;
    $("#config-admin-email").value = state.adminEmail;
  }
  function makeClient() {
    if (!window.supabase || !state.config.url || !state.config.key) {
      state.supabase = null; return null;
    }
    try {
      state.supabase = window.supabase.createClient(state.config.url, state.config.key, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      });
      return state.supabase;
    } catch (error) {
      console.error(error); state.supabase = null; return null;
    }
  }
  function showLogin() {
    $("#login-view").classList.remove("hidden"); $("#app-view").classList.add("hidden");
    refreshIcons();
  }
  function showApp() {
    $("#login-view").classList.add("hidden"); $("#app-view").classList.remove("hidden");
    const email = state.user?.email || "Administrator";
    const shortName = (email.split("@")[0] || "Admin").split(/[._-]/)[0];
    $("#admin-name").textContent = shortName.charAt(0).toUpperCase()+shortName.slice(1);
    $("#greeting-name").textContent = shortName.charAt(0).toUpperCase()+shortName.slice(1);
    $("#admin-avatar").textContent = shortName.charAt(0).toUpperCase();
    $("#session-email").textContent = email;
    $("#session-project").textContent = state.config.url ? new URL(state.config.url).hostname : "Not configured";
    $("#today-label").textContent = new Date().toLocaleDateString("en-PH",{weekday:"short",month:"short",day:"numeric"});
    refreshIcons();
    navigate("overview");
    refreshAll();
  }
  function adminAllowed(email) {
    // This is a UI guard only. Enforce admin permissions with database RLS policies too.
    return !!state.adminEmail && String(email || "").toLowerCase() === state.adminEmail;
  }
  async function handleLogin(event) {
    event.preventDefault();
    const email = $("#login-email").value.trim().toLowerCase();
    const password = $("#login-password").value;
    if (!state.config.url || !state.config.key) {
      setLoginMessage("Set your Supabase URL and publishable key in config.js.");
      return;
    }
    if (state.adminEmail && email !== state.adminEmail) {
      setLoginMessage("This email is not listed as the authorized admin email."); return;
    }
    const client = makeClient();
    if (!client) { setLoginMessage("Supabase could not be initialized. Check the project URL and key."); return; }
    const submit = $('#login-form button[type="submit"]');
    submit.disabled = true; submit.innerHTML = "Signing in…";
    try {
      const {data, error} = await client.auth.signInWithPassword({email,password});
      if (error) throw error;
      if (!adminAllowed(data.user?.email)) {
        await client.auth.signOut();
        throw new Error("Signed in, but this account is not authorized in the dashboard. Set the exact admin email in config.js.");
      }
      state.session = data.session; state.user = data.user;
      setLoginMessage("Signed in successfully.", false);
      showApp();
    } catch (error) {
      setLoginMessage(error.message || "Sign-in failed. Check your credentials.");
    } finally {
      submit.disabled = false; submit.innerHTML = "<span>Sign in</span>"+icon("arrow-right"); refreshIcons();
    }
  }
  async function signOut() {
    try { if (state.supabase) await state.supabase.auth.signOut(); } catch (e) { console.warn(e); }
    state.session=null; state.user=null; showLogin(); toast("You have signed out.");
  }
  function navigate(page) {
    state.currentPage = page;
    $$(".page-section").forEach(section=>section.classList.toggle("active", section.id === `page-${page}`));
    $$(".nav-item[data-page]").forEach(btn=>btn.classList.toggle("active",btn.dataset.page===page));
    const title = ({overview:"Overview",products:"Products",orders:"Orders",customers:"Customers",settings:"Settings & connection"})[page] || "Overview";
    $("#breadcrumb-page").textContent=title;
    $("#sidebar").classList.remove("open");
    refreshIcons();
    if (page==="products") renderProducts();
    if (page==="orders") renderOrders();
    if (page==="customers") renderCustomers();
  }
  function setConnectionError(message) {
    $("#connection-banner").classList.remove("hidden");
    $("#connection-message").textContent=message;
    $("#connection-status").textContent="Needs attention";
    $("#connection-status").className="status-pill status-pending";
  }
  function clearConnectionError() {
    $("#connection-banner").classList.add("hidden");
    $("#connection-status").textContent="Connected";
    $("#connection-status").className="status-pill status-available";
    $("#last-refreshed").textContent=new Date().toLocaleString("en-PH");
  }
  async function fetchTable(table, query) {
    const {data,error}=await state.supabase.from(table).select(query || "*");
    if (error) throw error;
    return data || [];
  }
  async function refreshAll() {
    if (!state.supabase || !state.user) { setConnectionError("Sign in after configuring Supabase."); return; }
    $("#recent-orders").innerHTML='<div class="loading-state">Loading your latest orders…</div>';
    $("#inventory-watch").innerHTML='<div class="loading-state">Checking stock…</div>';
    try {
      // Load each resource independently so a missing table/policy doesn't hide everything else.
      const results = await Promise.allSettled([
        fetchTable("products","id,name,description,price,image_url,stock_quantity,is_available,is_featured,category_id,created_at"),
        fetchTable("categories","id,name,is_active"),
        fetchTable("orders","*, order_items(*)"),
        fetchTable("profiles","id,full_name,email,phone,created_at")
      ]);
      const [p,c,o,u] = results;
      state.dataErrors = Object.fromEntries(
        ["products","categories","orders","profiles"]
          .flatMap((name,index)=>results[index].status==="rejected"?[[name,results[index].reason]]:[])
      );
      if (p.status==="fulfilled") state.products=p.value; else console.warn("products:",p.reason);
      if (c.status==="fulfilled") state.categories=c.value; else {state.categories=[];console.warn("categories:",c.reason);}
      if (o.status==="fulfilled") state.orders=o.value; else console.warn("orders:",o.reason);
      if (u.status==="fulfilled") state.customers=u.value; else console.warn("profiles:",u.reason);
      const failures=results.filter(r=>r.status==="rejected");
      if (failures.length) {
        const failedTables=Object.keys(state.dataErrors).join(", ");
        const details=Object.entries(state.dataErrors)
          .map(([table,error])=>`${table}: ${error?.message || "request failed"}`)
          .join("; ");
        setConnectionError(`Could not read ${failedTables}. Check table names, grants, and Supabase RLS policies. ${details}`);
      } else clearConnectionError();
      updateMetrics(); renderRecentOrders(); renderInventory(); renderProducts(); renderOrders(); renderCustomers(); populateCategories();
      $("#nav-product-count").textContent=state.products.length;
      $("#nav-order-count").textContent=state.dataErrors.orders?"—":state.orders.length;
      $("#metric-products").textContent=state.products.length;
      $("#metric-orders").textContent=state.dataErrors.orders?"—":state.orders.length;
      $("#metric-pending").textContent=state.orders.filter(o=>["pending","pending_payment","confirmed","preparing","processing"].includes(statusKey(o.status))).length;
      $("#metric-customers").textContent=state.customers.length;
      $("#last-refreshed").textContent=new Date().toLocaleString("en-PH");
      refreshIcons();
    } catch(error) {
      console.error(error); setConnectionError(error.message || "Could not load data.");
      toast("Could not refresh dashboard data. Check your connection and database permissions.","error");
    }
  }
  function updateMetrics() {
    $("#metric-products").textContent=state.products.length;
    $("#metric-orders").textContent=state.orders.length;
    $("#metric-pending").textContent=state.orders.filter(o=>["pending","pending_payment","confirmed","preparing","processing"].includes(statusKey(o.status))).length;
    $("#metric-customers").textContent=state.customers.length;
  }
  function productImage(product) {
    if (product.image_url) return `<img class="product-thumb" src="${escapeHtml(product.image_url)}" alt="" loading="lazy" onerror="this.outerHTML='<span class=&quot;product-thumb product-thumb-fallback&quot;>♡</span>'">`;
    return `<span class="product-thumb product-thumb-fallback">♡</span>`;
  }
  function emptyState(title, text) { return `<div class="empty-state"><strong>${escapeHtml(title)}</strong><p>${escapeHtml(text)}</p></div>`; }
  function renderRecentOrders() {
    if (state.dataErrors.orders) {
      $("#recent-orders").innerHTML=emptyState("Orders could not be loaded",state.dataErrors.orders.message||"Check the orders table grants and RLS policies.");
      return;
    }
    const rows=[...state.orders].sort((a,b)=>new Date(b.created_at||0)-new Date(a.created_at||0)).slice(0,5);
    if (!rows.length) {$("#recent-orders").innerHTML=emptyState("No orders yet","New customer orders will appear here when available.");return;}
    $("#recent-orders").innerHTML=`<table class="data-table"><thead><tr><th>Order</th><th>Date</th><th>Total</th><th>Status</th><th></th></tr></thead><tbody>${rows.map(o=>`<tr><td><b>${escapeHtml(String(o.id).slice(0,8))}</b></td><td>${dateText(o.created_at)}</td><td>${money(o.total_amount)}</td><td><span class="status-pill status-${statusKey(o.status)}">${escapeHtml(statusLabel(o.status))}</span></td><td><button class="tiny-action" data-order-id="${escapeHtml(o.id)}" title="View order">${icon("arrow-up-right")}</button></td></tr>`).join("")}</tbody></table>`;
    refreshIcons();
  }
  function renderInventory() {
    const low=state.products.filter(p=>Number(p.stock_quantity||0)<=5 || p.is_available===false).slice(0,5);
    if (!low.length) {$("#inventory-watch").innerHTML=emptyState("Stock looks good","No low-stock or unavailable products were found.");return;}
    $("#inventory-watch").innerHTML=low.map(p=>`<div class="inventory-item">${productImage(p)}<div class="inventory-info"><b>${escapeHtml(p.name)}</b><small>${p.is_available===false?"Unavailable":"Inventory level"}</small></div><span class="stock-number">${Number(p.stock_quantity||0)} left</span></div>`).join("");
  }
  function renderProducts() {
    if (!$("#products-table")) return;
    const search=($("#product-search")?.value||"").toLowerCase().trim();
    const filter=$("#product-status-filter")?.value||"all";
    const list=state.products.filter(p=>{
      const match=`${p.name||""} ${p.description||""}`.toLowerCase().includes(search);
      const stock=Number(p.stock_quantity||0);
      const status=filter==="available"?p.is_available!==false&&stock>0:filter==="unavailable"?p.is_available===false:filter==="low"?stock<=5:true;
      return match&&status;
    }).sort((a,b)=>String(a.name).localeCompare(String(b.name)));
    $("#products-count").textContent=`${list.length} product${list.length===1?"":"s"}`;
    if (!list.length) {$("#products-table").innerHTML=emptyState("No products found","Try a different search or add a new product.");return;}
    $("#products-table").innerHTML=`<table class="data-table"><thead><tr><th>Product</th><th>Price</th><th>Stock</th><th>Visibility</th><th>Featured</th><th>Actions</th></tr></thead><tbody>${list.map(p=>`<tr><td><div class="product-cell">${productImage(p)}<span><b>${escapeHtml(p.name)}</b><small>${escapeHtml(categoryName(p.category_id))}</small></span></div></td><td><b>${money(p.price)}</b></td><td>${Number(p.stock_quantity||0)<=5?`<span class="status-pill status-pending">${Number(p.stock_quantity||0)} left</span>`:Number(p.stock_quantity||0)}</td><td><span class="status-pill ${p.is_available===false?"status-unavailable":"status-available"}">${p.is_available===false?"Unavailable":"Available"}</span></td><td>${p.is_featured?"Yes":"—"}</td><td><div class="row-actions"><button class="tiny-action" data-edit-product="${escapeHtml(p.id)}" title="Edit product">${icon("pencil")}</button><button class="tiny-action" data-toggle-product="${escapeHtml(p.id)}" title="${p.is_available===false?"Make available":"Mark unavailable"}">${icon(p.is_available===false?"eye":"eye-off")}</button></div></td></tr>`).join("")}</tbody></table>`;
    refreshIcons();
  }
  function renderOrders() {
    if (!$("#orders-table")) return;
    if (state.dataErrors.orders) {
      $("#orders-count").textContent="Unavailable";
      $("#orders-table").innerHTML=emptyState("Orders could not be loaded",state.dataErrors.orders.message||"Check the orders table grants and RLS policies.");
      return;
    }
    const search=($("#order-search")?.value||"").toLowerCase().trim();
    const filter=$("#order-status-filter")?.value||"all";
    const list=[...state.orders].filter(o=>{
      const customer=state.customers.find(c=>c.id===o.customer_id);
      const text=`${o.id||""} ${o.customer_id||""} ${customer?.full_name||""} ${customer?.email||""}`.toLowerCase();
      return text.includes(search)&&(filter==="all"||statusKey(o.status)===filter||(filter==="shipped"&&statusKey(o.status)==="out_for_delivery")||(filter==="out_for_delivery"&&statusKey(o.status)==="shipped"));
    }).sort((a,b)=>new Date(b.created_at||0)-new Date(a.created_at||0));
    $("#orders-count").textContent=`${list.length} order${list.length===1?"":"s"}`;
    if (!list.length) {$("#orders-table").innerHTML=emptyState("No orders found","Orders will appear here when the orders table is accessible.");return;}
    $("#orders-table").innerHTML=`<table class="data-table"><thead><tr><th>Order ID</th><th>Customer</th><th>Date</th><th>Fulfillment</th><th>Total</th><th>Status</th><th>Action</th></tr></thead><tbody>${list.map(o=>{const c=state.customers.find(c=>c.id===o.customer_id);return `<tr><td><b>#${escapeHtml(String(o.id).slice(0,8))}</b></td><td>${escapeHtml(c?.full_name||o.recipient_name||"Customer")}<small style="display:block;color:#ad9aa6;margin-top:4px">${escapeHtml(c?.email||"")}</small></td><td>${dateText(o.created_at)}</td><td>${escapeHtml(String(o.fulfillment_method||"—").replace(/_/g," "))}</td><td><b>${money(o.total_amount)}</b></td><td><span class="status-pill status-${statusKey(o.status)}">${escapeHtml(statusLabel(o.status))}</span></td><td><button class="btn btn-soft" style="padding:8px 10px" data-order-id="${escapeHtml(o.id)}">View / update</button></td></tr>`}).join("")}</tbody></table>`;
    refreshIcons();
  }
  function renderCustomers() {
    if (!$("#customers-table")) return;
    const search=($("#customer-search")?.value||"").toLowerCase().trim();
    const list=state.customers.filter(c=>`${c.full_name||""} ${c.email||""} ${c.phone||""}`.toLowerCase().includes(search));
    $("#customers-count").textContent=`${list.length} customer${list.length===1?"":"s"}`;
    if (!list.length) {$("#customers-table").innerHTML=emptyState("No customer profiles found","Check that the profiles table is readable under your admin RLS policies.");return;}
    $("#customers-table").innerHTML=`<table class="data-table"><thead><tr><th>Customer</th><th>Email</th><th>Phone</th><th>Joined</th><th>Orders</th><th>Total spend</th></tr></thead><tbody>${list.map(c=>{const orders=state.orders.filter(o=>o.customer_id===c.id);const spend=orders.reduce((sum,o)=>sum+Number(o.total_amount||0),0);const initials=(c.full_name||c.email||"C").split(/\s+/).map(s=>s[0]).join("").slice(0,2).toUpperCase();return `<tr><td><div class="product-cell"><span class="customer-avatar">${escapeHtml(initials)}</span><span><b>${escapeHtml(c.full_name||"Customer")}</b><small>${escapeHtml(String(c.id).slice(0,8))}</small></span></div></td><td>${escapeHtml(c.email||"—")}</td><td>${escapeHtml(c.phone||"—")}</td><td>${dateText(c.created_at)}</td><td>${orders.length}</td><td><b>${money(spend)}</b></td></tr>`}).join("")}</tbody></table>`;
  }
  function categoryName(id) { return state.categories.find(c=>String(c.id)===String(id))?.name || "Uncategorized"; }
  function populateCategories() {
    const select=$("#product-category"); if (!select) return;
    const current=select.value;
    select.innerHTML='<option value="">No category</option>'+state.categories.map(c=>`<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)}</option>`).join("");
    if (current) select.value=current;
  }
  function setProductImagePreview(url) {
    const preview=$("#product-image-preview");
    if (state.productImagePreviewUrl) URL.revokeObjectURL(state.productImagePreviewUrl);
    state.productImagePreviewUrl=url?.startsWith("blob:")?url:null;
    preview.replaceChildren();
    if (!url) {
      const placeholder=document.createElement("span");
      placeholder.textContent="Image preview";
      preview.appendChild(placeholder);
      return;
    }
    const image=document.createElement("img");
    image.src=url;
    image.alt="Selected product";
    preview.appendChild(image);
  }
  function openProductModal(product=null) {
    $("#product-form").reset(); $("#product-error").textContent="";
    $("#product-id").value=product?.id||"";
    $("#product-modal-title").textContent=product?"Edit product":"Add a product";
    $("#product-name").value=product?.name||"";
    $("#product-price").value=product?.price??1;
    state.selectedProductImage=null;
    state.productImageUrl=product?.image_url||"";
    setProductImagePreview(state.productImageUrl);
    $("#product-image-name").textContent=state.productImageUrl?"Current image · choose a file to replace":"JPG, PNG, WebP, or GIF · up to 5 MB";
    $("#product-description").value=product?.description||"";
    $("#product-stock").value=product?.stock_quantity??10;
    $("#product-available").checked=product?.is_available!==false;
    $("#product-featured").checked=product?.is_featured===true;
    populateCategories(); $("#product-category").value=product?.category_id||"";
    $("#product-modal").classList.remove("hidden"); refreshIcons();
  }
  function closeModals() { $$(".modal-backdrop").forEach(m=>m.classList.add("hidden")); }
  async function saveProduct(event) {
    event.preventDefault();
    if (!state.supabase) return;
    const id=$("#product-id").value;
    const payload={
      name:$("#product-name").value.trim(),
      price:Number($("#product-price").value),
      image_url:state.productImageUrl||null,
      description:$("#product-description").value.trim(),
      stock_quantity:Number($("#product-stock").value),
      is_available:$("#product-available").checked,
      is_featured:$("#product-featured").checked,
      category_id:$("#product-category").value||null
    };
    if (!payload.name || !Number.isFinite(payload.price)||payload.price<0||!Number.isInteger(payload.stock_quantity)||payload.stock_quantity<0) {
      $("#product-error").textContent="Enter a product name, a valid price, and a whole-number stock quantity.";return;
    }
    const btn=$("#save-product-btn"); btn.disabled=true; btn.textContent="Saving…";
    try {
      if (state.selectedProductImage) {
        const file=state.selectedProductImage;
        const extension={ "image/jpeg":"jpg", "image/png":"png", "image/webp":"webp", "image/gif":"gif" }[file.type];
        const path=`products/${crypto.randomUUID()}.${extension}`;
        const {error:uploadError}=await state.supabase.storage.from(IMAGE_BUCKET).upload(path,file,{
          cacheControl:"3600",
          contentType:file.type,
          upsert:false
        });
        if (uploadError) throw uploadError;
        payload.image_url=state.supabase.storage.from(IMAGE_BUCKET).getPublicUrl(path).data.publicUrl;
      }
      const result=id?await state.supabase.from("products").update(payload).eq("id",id):await state.supabase.from("products").insert(payload);
      if (result.error) throw result.error;
      closeModals(); toast(id?"Product updated.":"Product added."); await refreshAll();
    } catch(error) {
      $("#product-error").textContent=`Could not save product: ${error.message||"Database permission denied."}`;
    } finally {btn.disabled=false;btn.innerHTML=`${icon("check")} Save product`;refreshIcons();}
  }
  async function toggleProduct(id) {
    const product=state.products.find(p=>String(p.id)===String(id)); if(!product)return;
    try {
      const {error}=await state.supabase.from("products").update({is_available:product.is_available===false}).eq("id",id);
      if(error)throw error;
      toast(product.is_available===false?"Product is available again.":"Product marked unavailable.");
      await refreshAll();
    } catch(error) {toast(`Could not update product: ${error.message||"Check admin RLS policies."}`,"error");}
  }
  function openOrderModal(id) {
    const order=state.orders.find(o=>String(o.id)===String(id));if(!order)return;
    state.editingOrder=order;
    const customer=state.customers.find(c=>c.id===order.customer_id);
    const items=Array.isArray(order.order_items)?order.order_items:[];
    const itemDetails=items.length?`<div class="order-detail-items"><b>Items</b>${items.map(item=>`<div class="order-detail-item"><span>${escapeHtml(item.product_name||"Product")}${item.rose_type?` · ${escapeHtml(item.rose_type==="fresh"?"Fresh":"Artificial")}`:""}</span><span>× ${Number(item.quantity)||0} · ${money(item.line_total)}</span></div>`).join("")}</div>`:`<div class="order-detail-items"><b>Items</b><span>Item details are not available for this order.</span></div>`;
    $("#order-modal-title").textContent=`Order #${String(order.id).slice(0,8)}`;
    $("#order-modal-subtitle").textContent=`Placed ${dateText(order.created_at)}`;
    $("#order-modal-body").innerHTML=`<div class="order-detail-list">
      <div class="order-detail-row"><span>Customer</span><b>${escapeHtml(customer?.full_name||order.recipient_name||"Customer")}</b></div>
      <div class="order-detail-row"><span>Email</span><b>${escapeHtml(customer?.email||"Not available")}</b></div>
      <div class="order-detail-row"><span>Contact</span><b>${escapeHtml(order.contact_number||customer?.phone||"—")}</b></div>
      <div class="order-detail-row"><span>Fulfillment</span><b>${escapeHtml(String(order.fulfillment_method||"—").replace(/_/g," "))}</b></div>
      <div class="order-detail-row"><span>Address</span><b>${escapeHtml(order.delivery_address||"Pickup / not provided")}</b></div>
      <div class="order-detail-row"><span>Payment</span><b>${escapeHtml(order.payment_method||"—")} · ${escapeHtml(order.payment_status||"status unavailable")}</b></div>
      <div class="order-detail-row"><span>Total</span><b>${money(order.total_amount)}</b></div>
      ${itemDetails}
      ${order.greeting_message?`<div class="order-detail-row"><span>Gift message</span><b>${escapeHtml(order.greeting_message)}</b></div>`:""}
    </div><label class="order-status-edit">Update order status<select id="edit-order-status">${["pending","confirmed","preparing","processing","shipped","out_for_delivery","ready_for_pickup","delivered","picked_up","cancelled"].map(s=>`<option value="${s}" ${statusKey(order.status)===s?"selected":""}>${statusLabel(s)}</option>`).join("")}</select></label>`;
    $("#order-error").textContent="";$("#order-modal").classList.remove("hidden");refreshIcons();
  }
  async function saveOrderStatus() {
    const order=state.editingOrder;if(!order)return;
    const status=$("#edit-order-status").value;
    const btn=$("#save-order-status");btn.disabled=true;btn.textContent="Saving…";
    try {
      const {error}=await state.supabase.from("orders").update({status}).eq("id",order.id);
      if(error)throw error;
      closeModals();toast("Order status updated.");await refreshAll();
    } catch(error) {
      $("#order-error").textContent=`Could not update order status: ${error.message||"Check the orders table and admin RLS policies."}`;
    } finally {btn.disabled=false;btn.innerHTML=`${icon("check")} Save status`;refreshIcons();}
  }
  async function saveConfig() {
    const url=$("#config-url").value.trim().replace(/\/+$/,"");
    const key=$("#config-key").value.trim();
    const adminEmail=$("#config-admin-email").value.trim().toLowerCase();
    if (!url.startsWith("https://")||!key||!adminEmail.includes("@")) {toast("Enter a valid Supabase URL, publishable key, and admin email.","error");return;}
    state.config={url,key};state.adminEmail=adminEmail;
    localStorage.setItem(CONFIG_KEY,JSON.stringify({url,key,adminEmail}));
    const client=makeClient();
    if (client) {
      const {data,error}=await client.auth.getSession();
      if(error)toast(`Settings saved, but session check failed: ${error.message}`,"error");
      else {state.session=data.session;state.user=data.session?.user||null;toast("Connection settings saved.");$("#session-project").textContent=new URL(url).hostname;if(state.user&&adminAllowed(state.user.email))showApp();}
    }
    $("#connection-status").textContent="Configured";$("#connection-status").className="status-pill status-available";
  }
  async function testConnection() {
    if(!state.config.url||!state.config.key){toast("Add your Supabase URL and publishable key first.","error");return;}
    makeClient();
    try {
      const {data,error}=await state.supabase.auth.getSession();if(error)throw error;
      $("#session-email").textContent=data.session?.user?.email||"No active session";
      $("#session-project").textContent=new URL(state.config.url).hostname;
      $("#connection-status").textContent="Reachable";$("#connection-status").className="status-pill status-available";
      toast("Supabase client initialized successfully.");
    } catch(error) {toast(`Connection test failed: ${error.message}`,"error");}
  }
  function bindEvents() {
    $("#login-form").addEventListener("submit",handleLogin);
    $("#toggle-password").addEventListener("click",()=>{const input=$("#login-password");input.type=input.type==="password"?"text":"password";$("#toggle-password").innerHTML=icon(input.type==="password"?"eye":"eye-off");refreshIcons();});
    $("#logout-btn").addEventListener("click",signOut);
    $("#mobile-menu").addEventListener("click",()=>$("#sidebar").classList.toggle("open"));
    document.addEventListener("click",event=>{
      const page=event.target.closest("[data-page]");if(page){event.preventDefault();navigate(page.dataset.page);}
      const action=event.target.closest("[data-action]");if(action&&action.dataset.action==="add-product")openProductModal();
      const edit=event.target.closest("[data-edit-product]");if(edit)openProductModal(state.products.find(p=>String(p.id)===edit.dataset.editProduct));
      const toggle=event.target.closest("[data-toggle-product]");if(toggle)toggleProduct(toggle.dataset.toggleProduct);
      const order=event.target.closest("[data-order-id]");if(order)openOrderModal(order.dataset.orderId);
      if(event.target.closest("[data-close-modal]"))closeModals();
      if(event.target.classList.contains("modal-backdrop"))closeModals();
    });
    $("#product-form").addEventListener("submit",saveProduct);
    $("#product-image-file").addEventListener("change",event=>{
      const file=event.target.files[0];
      if (!file) return;
      if (!IMAGE_TYPES.has(file.type)) {
        $("#product-error").textContent="Choose a JPG, PNG, WebP, or GIF image.";
        event.target.value="";
        return;
      }
      if (file.size>MAX_IMAGE_SIZE) {
        $("#product-error").textContent="Choose an image smaller than 5 MB.";
        event.target.value="";
        return;
      }
      state.selectedProductImage=file;
      $("#product-error").textContent="";
      $("#product-image-name").textContent=file.name;
      setProductImagePreview(URL.createObjectURL(file));
    });
    $("#clear-product-image").addEventListener("click",()=>{
      state.selectedProductImage=null;
      state.productImageUrl="";
      $("#product-image-file").value="";
      $("#product-image-name").textContent="No image selected";
      $("#product-error").textContent="";
      setProductImagePreview("");
    });
    $("#save-order-status").addEventListener("click",saveOrderStatus);
    $$(".nav-item[data-page]").forEach(btn=>btn.addEventListener("click",()=>navigate(btn.dataset.page)));
    $("#product-search").addEventListener("input",renderProducts);$("#product-status-filter").addEventListener("change",renderProducts);
    $("#order-search").addEventListener("input",renderOrders);$("#order-status-filter").addEventListener("change",renderOrders);
    $("#customer-search").addEventListener("input",renderCustomers);
    $("#refresh-btn").addEventListener("click",refreshAll);$("#products-refresh").addEventListener("click",refreshAll);$("#orders-refresh").addEventListener("click",refreshAll);$("#customers-refresh").addEventListener("click",refreshAll);
    $("#save-config").addEventListener("click",saveConfig);$("#test-connection").addEventListener("click",testConnection);
    document.addEventListener("keydown",event=>{if(event.key==="Escape")closeModals();});
  }
  async function init() {
    loadConfig();bindEvents();
    $("#year").textContent=new Date().getFullYear();
    $("#today-label").textContent=new Date().toLocaleDateString("en-PH",{weekday:"short",month:"short",day:"numeric"});
    refreshIcons();
    if(state.config.url&&state.config.key){
      makeClient();
      try {
        const {data,error}=await state.supabase.auth.getSession();
        if(!error&&data.session){
          if(adminAllowed(data.session.user?.email)){state.session=data.session;state.user=data.session.user;showApp();return;}
          await state.supabase.auth.signOut();
        }
      } catch(error){console.warn("Session restore failed",error);}
    }
    showLogin();
  }
  document.addEventListener("DOMContentLoaded",init);
})();