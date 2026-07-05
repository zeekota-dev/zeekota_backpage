const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'zeekota_backpage';

const state = {
    visible: false,
    mode: 'dealer',
    tab: 'live',
    clientSubtab: 'clients',
    adminTab: 'overview',
    dashboard: null,
    selectedConversationId: null,
    search: '',
    interaction: null,
    adminPlayers: [],
    logsPage: 1
};

const root = document.getElementById('phoneRoot');
const shell = document.getElementById('phoneShell');
const tabs = document.getElementById('tabs');
const content = document.getElementById('content');
const title = document.getElementById('appTitle');
const subtitle = document.getElementById('appSubtitle');
const closeBtn = document.getElementById('closeBtn');
const interactionRoot = document.getElementById('interactionRoot');
const promptRoot = document.getElementById('promptRoot');
const toastRoot = document.getElementById('toastRoot');
const modalRoot = document.getElementById('modalRoot');

function t(key) {
    const locale = state.dashboard?.config?.locale || {};
    return locale[key] || key;
}

function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    }[char]));
}

function money(value) {
    return `$${Number(value || 0).toLocaleString()}`;
}

function dateText(timestamp) {
    const value = Number(timestamp || 0);
    if (!value) return '-';
    return new Date(value * 1000).toLocaleString();
}

function duration(seconds) {
    seconds = Math.max(0, Number(seconds || 0));
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function until(timestamp) {
    const value = Number(timestamp || 0);
    if (!value) return '-';
    return duration(value - Math.floor(Date.now() / 1000));
}

async function nui(name, payload = {}) {
    try {
        const response = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        });
        return await response.json();
    } catch (error) {
        return { ok: false, error: 'nui_unavailable' };
    }
}

function setDashboard(payload) {
    if (payload?.dashboard) payload = payload.dashboard;
    if (payload?.ok) {
        state.dashboard = payload;
    }
}

function render() {
    if (!state.visible || !state.dashboard) return;
    root.classList.toggle('admin', state.mode === 'admin');
    root.classList.toggle('messages-wide', state.mode !== 'admin' && state.tab === 'messages');
    title.textContent = t('app_title');
    subtitle.textContent = state.mode === 'admin' ? t('admin_tab') : t('app_subtitle');
    renderTabs();
    if (state.mode === 'admin') {
        renderAdmin();
    } else if (state.tab === 'messages') {
        renderMessages();
    } else if (state.tab === 'clients') {
        renderClientsStats();
    } else {
        renderLive();
    }
}

function renderTabs() {
    const items = state.mode === 'admin'
        ? [
            ['overview', t('admin_overview')],
            ['drugs', t('admin_drugs')],
            ['archetypes', t('admin_archetypes')],
            ['locations', t('admin_locations')],
            ['settings', t('admin_settings')],
            ['players', t('admin_players')],
            ['logs', t('admin_logs')]
        ]
        : [
            ['live', t('live_tab')],
            ['clients', t('clients_tab')],
            ['messages', t('messages_tab')]
        ];

    tabs.innerHTML = items.map(([id, label]) => {
        const active = state.mode === 'admin' ? state.adminTab === id : state.tab === id;
        return `<button class="tab ${active ? 'active' : ''}" data-action="tab" data-tab="${esc(id)}" type="button">${esc(label)}</button>`;
    }).join('');
}

function session() {
    return state.dashboard?.session || {};
}

function stats() {
    return state.dashboard?.stats || {};
}

function conversations() {
    return state.dashboard?.conversations || [];
}

function clients() {
    return state.dashboard?.clients || [];
}

function drugs() {
    return state.dashboard?.config?.drugs || state.dashboard?.drugs || [];
}

function stat(label, value, cls = '') {
    return `<div class="stat ${cls}"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
}

function renderLive() {
    const s = session();
    const st = stats();
    const live = s.live === true;
    const recent = conversations().find((conversation) => conversation.request && conversation.request.status === 'pending');
    const cooldownLeft = Math.max(0, Number(s.cooldownEndsAt || 0) - Math.floor(Date.now() / 1000));

    content.innerHTML = `
        <div class="grid">
            <section class="card">
                <div class="section-head">
                    <div>
                        <h2>${esc(t('status'))}</h2>
                        <p class="muted">${esc(live ? t('waiting_for_messages') : t('offline'))}</p>
                    </div>
                    <span class="pill ${live ? 'good' : 'bad'}"><i class="status-dot ${live ? 'live' : ''}"></i>${esc(live ? t('live') : t('offline'))}</span>
                </div>
                <div class="grid two">
                    ${stat(t('reputation'), st.reputation || 0)}
                    ${stat(t('active_clients'), clients().filter((client) => !client.blocked).length)}
                    ${stat(t('pending_meetups'), s.pendingMeetups || 0)}
                    ${stat(t('session_time'), live ? duration(Math.floor(Date.now() / 1000) - Number(s.startedAt || 0)) : '-')}
                </div>
                <div class="row" style="margin-top:12px">
                    <button class="btn primary" data-action="goLive" type="button" ${live || cooldownLeft > 0 ? 'disabled' : ''}>${esc(t('go_live'))}</button>
                    <button class="btn danger" data-action="endSession" type="button" ${!live ? 'disabled' : ''}>${esc(t('end_session'))}</button>
                    <span class="pill">${esc(t('current_area'))}: ${esc(s.area || '-')}</span>
                    <span class="pill ${cooldownLeft > 0 ? 'warn' : ''}">${esc(t('cooldown'))}: ${esc(duration(cooldownLeft))}</span>
                </div>
            </section>
            <section class="card">
                <div class="section-head">
                    <h2>${esc(t('recent_request'))}</h2>
                    <span class="pill">${esc(t('risk'))}: ${esc(recent?.request?.risk ?? 0)}</span>
                </div>
                ${recent ? conversationPreview(recent, true) : `<div class="empty">${esc(t('no_recent_request'))}</div>`}
            </section>
        </div>
    `;
}

function conversationPreview(conversation, includeAction) {
    const request = conversation.request || {};
    return `
        <div class="conversation-row" data-action="selectConversation" data-id="${esc(conversation.id)}">
            <div class="avatar">${esc(conversation.avatar || 'ZK')}</div>
            <div>
                <strong>${esc(conversation.alias || '-')}</strong>
                <span>${esc(conversation.lastMessage || request.preview || '-')}</span>
            </div>
            <div class="grid">
                <span class="badge ${conversation.activeMeetup ? 'good' : ''}">${esc(conversation.status || '-')}</span>
                ${includeAction && request.id ? `<button class="btn primary" data-action="acceptRequest" data-request="${esc(request.id)}" type="button">${esc(t('meet_up'))}</button>` : ''}
            </div>
        </div>
    `;
}

function renderMessages() {
    const query = state.search.toLowerCase();
    const list = conversations().filter((conversation) => !query || String(conversation.alias || '').toLowerCase().includes(query) || String(conversation.lastMessage || '').toLowerCase().includes(query));
    const selected = list.find((conversation) => String(conversation.id) === String(state.selectedConversationId)) || list[0];
    if (selected) state.selectedConversationId = selected.id;

    content.innerHTML = `
        <div class="messages-layout">
            <section class="conversation-list">
                <input class="search" data-action="search" type="search" value="${esc(state.search)}" placeholder="${esc(t('search'))}">
                <div class="list">
                    ${list.length ? list.map((conversation) => conversationRow(conversation, selected)).join('') : `<div class="empty">${esc(t('no_conversations'))}</div>`}
                </div>
            </section>
            ${selected ? conversationDetail(selected) : `<section class="conversation-detail"><div class="empty">${esc(t('no_conversations'))}</div></section>`}
        </div>
    `;
    requestAnimationFrame(() => {
        const body = content.querySelector('.conversation-body');
        if (body) body.scrollTop = body.scrollHeight;
    });
}

function conversationRow(conversation, selected) {
    const active = String(selected?.id) === String(conversation.id);
    const unread = Number(conversation.unreadCount || 0);
    return `
        <button class="conversation-row ${active ? 'active' : ''}" data-action="selectConversation" data-id="${esc(conversation.id)}" type="button">
            <div class="avatar">${esc(conversation.avatar || 'ZK')}</div>
            <div>
                <strong>${esc(conversation.alias || '-')}</strong>
                <span>${esc(conversation.lastMessage || '-')}</span>
            </div>
            <div class="grid">
                ${unread > 0 ? `<span class="badge good">${esc(unread)}</span>` : ''}
                ${conversation.activeMeetup ? `<span class="badge warn">${esc(t('active_meetup'))}</span>` : ''}
            </div>
        </button>
    `;
}

function conversationDetail(conversation) {
    const request = conversation.request || {};
    const messages = conversation.messages || [];
    const pending = request.id && request.status === 'pending';
    const accepted = request.id && request.status === 'accepted';
    return `
        <section class="conversation-detail">
            <header class="conversation-head">
                <div class="avatar">${esc(conversation.avatar || 'ZK')}</div>
                <div>
                    <strong>${esc(conversation.alias || '-')}</strong>
                    <div class="row">
                        <span class="badge">${esc(conversation.status || '-')}</span>
                        ${request.expiresAt ? `<span class="badge warn">${esc(t('request_countdown'))}: ${esc(until(request.expiresAt))}</span>` : ''}
                    </div>
                </div>
            </header>
            <div class="conversation-body">
                ${messages.map((message) => `<div class="bubble ${esc(message.sender)}">${esc(message.body)}</div>`).join('')}
            </div>
            <footer class="conversation-actions">
                ${pending ? `<button class="btn primary" data-action="acceptRequest" data-request="${esc(request.id)}" type="button">${esc(t('meet_up'))}</button>` : ''}
                ${pending ? `<button class="btn ghost" data-action="declineRequest" data-request="${esc(request.id)}" type="button">${esc(t('decline'))}</button>` : ''}
                ${accepted ? `<button class="btn danger" data-action="cancelMeetup" data-request="${esc(request.id)}" type="button">${esc(t('cancel_meetup'))}</button>` : ''}
                <button class="btn ghost" data-action="markRead" data-id="${esc(conversation.id)}" type="button">${esc(t('mark_read'))}</button>
                <button class="btn ghost" data-action="${conversation.isClient ? 'blockClient' : 'deleteConversation'}" data-id="${esc(conversation.id)}" data-customer="${esc(conversation.customerKey)}" type="button">${esc(conversation.isClient ? t('block_client') : t('delete_conversation'))}</button>
            </footer>
        </section>
    `;
}

function renderClientsStats() {
    const st = stats();
    content.innerHTML = `
        <div class="segmented" style="margin-bottom:12px">
            <button class="${state.clientSubtab === 'clients' ? 'active' : ''}" data-action="clientSubtab" data-tab="clients" type="button">${esc(t('clients'))}</button>
            <button class="${state.clientSubtab === 'statistics' ? 'active' : ''}" data-action="clientSubtab" data-tab="statistics" type="button">${esc(t('statistics'))}</button>
        </div>
        ${state.clientSubtab === 'clients' ? renderClients() : renderStats(st)}
    `;
}

function renderClients() {
    const list = clients();
    if (!list.length) return `<div class="empty">${esc(t('no_clients'))}</div>`;
    return `
        <div class="grid">
            ${list.map((client) => `
                <section class="card">
                    <div class="section-head">
                        <div class="row">
                            <div class="avatar">${esc(client.avatar || 'ZK')}</div>
                            <div>
                                <h2>${esc(client.alias)}</h2>
                                <p class="muted">${esc(client.archetypeLabel || client.archetypeId || '-')}</p>
                            </div>
                        </div>
                        <span class="badge ${client.blocked ? 'bad' : 'good'}">${esc(client.blocked ? t('blocked') : t('active'))}</span>
                    </div>
                    <div class="grid two">
                        ${stat(t('loyalty'), client.loyalty)}
                        ${stat(t('tier'), client.tier)}
                        ${stat(t('preferred_drug'), client.preferredDrug || '-')}
                        ${stat(t('total_spent'), money(client.totalSpent))}
                        ${stat(t('total_purchases'), client.totalPurchases)}
                        ${stat(t('average_order'), client.averageOrderSize)}
                    </div>
                    <div class="row" style="margin-top:12px">
                        <button class="btn ${client.blocked ? 'primary' : 'danger'}" data-action="${client.blocked ? 'unblockClient' : 'blockClient'}" data-customer="${esc(client.customerKey)}" type="button">${esc(client.blocked ? t('unblock_client') : t('block_client'))}</button>
                    </div>
                </section>
            `).join('')}
        </div>
    `;
}

function renderStats(st) {
    const drugStats = st.drugStats || [];
    return `
        <div class="grid two">
            ${stat(t('total_drugs_sold'), st.totalDrugsSold || 0)}
            ${stat(t('total_transactions'), st.totalTransactions || 0)}
            ${stat(t('total_money'), money(st.totalMoneyMade))}
            ${stat(t('samples_given'), st.totalSamplesGiven || 0)}
            ${stat(t('clients_gained'), st.totalClientsGained || 0)}
            ${stat(t('average_sale'), money(st.averageSaleValue))}
            ${stat(t('largest_sale'), money(st.largestSale))}
            ${stat(t('live_time'), duration(st.totalLiveTime || 0))}
        </div>
        <section class="card">
            <div class="section-head"><h2>${esc(t('drug_statistics'))}</h2></div>
            <div class="grid">
                ${drugStats.length ? drugStats.map((drug) => `
                    <div class="card">
                        <div class="split">
                            <strong>${esc(drug.label)}</strong>
                            <span class="badge">${esc(drug.transactions || 0)} ${esc(t('transactions'))}</span>
                        </div>
                        <div class="grid two" style="margin-top:10px">
                            ${stat(t('units_sold'), drug.unitsSold || 0)}
                            ${stat(t('revenue'), money(drug.revenue))}
                            ${stat(t('samples_given'), drug.samplesGiven || 0)}
                            ${stat(t('last_sale'), dateText(drug.lastSale))}
                        </div>
                    </div>
                `).join('') : `<div class="empty">${esc(t('no_stats'))}</div>`}
            </div>
        </section>
    `;
}

function renderAdmin() {
    if (state.adminTab === 'drugs') return renderAdminDrugs();
    if (state.adminTab === 'archetypes') return renderAdminArchetypes();
    if (state.adminTab === 'locations') return renderAdminLocations();
    if (state.adminTab === 'settings') return renderAdminSettings();
    if (state.adminTab === 'players') return renderAdminPlayers();
    if (state.adminTab === 'logs') return renderAdminLogs();
    return renderAdminOverview();
}

function adminData() {
    return state.dashboard || {};
}

function renderAdminOverview() {
    const o = adminData().overview || {};
    content.innerHTML = `
        <div class="grid four">
            ${stat(t('live_dealers'), o.liveDealers || 0)}
            ${stat(t('active_meetups'), o.activeMeetups || 0)}
            ${stat(t('pending_requests'), o.pendingRequests || 0)}
            ${stat(t('configured_drugs'), o.configuredDrugs || 0)}
            ${stat(t('total_customers'), o.totalCustomers || 0)}
            ${stat(t('permanent_clients'), o.permanentClients || 0)}
            ${stat(t('server_money'), money(o.serverMoney))}
            ${stat(t('script_status'), o.scriptStatus || '-')}
        </div>
        <section class="card">
            <div class="section-head">
                <h2>${esc(t('recent_transactions'))}</h2>
                <button class="btn ghost" data-action="adminRefreshCache" type="button">${esc(t('refresh_cache'))}</button>
            </div>
            ${adminTransactions(o.recentTransactions || [])}
        </section>
    `;
}

function adminTransactions(rows) {
    if (!rows.length) return `<div class="empty">${esc(t('no_data'))}</div>`;
    return `<div class="admin-table">${rows.map((row) => `
        <div class="admin-row">
            <div>
                <strong>${esc(row.transaction_id || row.id)}</strong>
                <span class="muted">${esc(row.identifier || '-')} | ${esc(row.drug || '-')} | ${money(row.payment || 0)}</span>
            </div>
            <span class="badge">${esc(row.outcome || '-')}</span>
        </div>
    `).join('')}</div>`;
}

function renderAdminDrugs() {
    const rows = adminData().drugs || [];
    content.innerHTML = `
        <div class="section-head">
            <h2>${esc(t('admin_drugs'))}</h2>
            <button class="btn primary" data-action="editDrug" type="button">${esc(t('add'))}</button>
        </div>
        <div class="admin-table">
            ${rows.map((drug) => adminRow(drug.label, `${drug.item} | ${money(drug.minPrice)}-${money(drug.maxPrice)}`, [
                ['editDrug', t('edit'), drug.id],
                ['duplicateDrug', t('duplicate'), drug.id],
                ['testDrugItem', t('test_item'), drug.id],
                ['deleteDrug', t('delete'), drug.id, 'danger']
            ])).join('')}
        </div>
    `;
}

function renderAdminArchetypes() {
    const rows = adminData().archetypes || [];
    content.innerHTML = `
        <div class="section-head">
            <h2>${esc(t('admin_archetypes'))}</h2>
            <button class="btn primary" data-action="editArchetype" type="button">${esc(t('add'))}</button>
        </div>
        <div class="admin-table">
            ${rows.map((entry) => adminRow(entry.label, `${entry.id} | ${t('risk')}: ${entry.risk || 0}`, [
                ['editArchetype', t('edit'), entry.id],
                ['duplicateArchetype', t('duplicate'), entry.id],
                ['deleteArchetype', t('delete'), entry.id, 'danger']
            ])).join('')}
        </div>
    `;
}

function renderAdminLocations() {
    const rows = adminData().locations || [];
    content.innerHTML = `
        <div class="section-head">
            <h2>${esc(t('admin_locations'))}</h2>
            <div class="row">
                <button class="btn primary" data-action="addCurrentLocation" type="button">${esc(t('get_current_location'))}</button>
                <button class="btn ghost" data-action="editLocation" type="button">${esc(t('add'))}</button>
            </div>
        </div>
        <div class="admin-table">
            ${rows.map((entry) => adminRow(entry.label, `${entry.area} | ${Number(entry.x).toFixed(1)}, ${Number(entry.y).toFixed(1)}, ${Number(entry.z).toFixed(1)}`, [
                ['editLocation', t('edit'), entry.id],
                ['teleportLocation', t('teleport'), entry.id],
                ['testLocation', t('test_spawn'), entry.id],
                ['deleteLocation', t('delete'), entry.id, 'danger']
            ])).join('')}
        </div>
    `;
}

function adminRow(label, meta, actions) {
    return `
        <div class="admin-row">
            <div>
                <strong>${esc(label)}</strong>
                <span class="muted">${esc(meta)}</span>
            </div>
            <div class="row">
                ${actions.map(([action, text, id, cls]) => `<button class="btn ${cls || 'ghost'}" data-action="${esc(action)}" data-id="${esc(id || '')}" type="button">${esc(text)}</button>`).join('')}
            </div>
        </div>
    `;
}

function renderAdminSettings() {
    const settings = adminData().settings || {};
    content.innerHTML = `
        <div class="section-head">
            <h2>${esc(t('admin_settings'))}</h2>
            <button class="btn ghost" data-action="adminRefreshCache" type="button">${esc(t('reload_settings'))}</button>
        </div>
        <div class="grid two">
            ${Object.entries(settings).map(([key, value]) => `
                <section class="card">
                    <div class="section-head">
                        <h2>${esc(key)}</h2>
                        <button class="btn primary" data-action="saveSetting" data-key="${esc(key)}" type="button">${esc(t('save'))}</button>
                    </div>
                    <textarea class="setting-json" data-key="${esc(key)}">${esc(JSON.stringify(value, null, 2))}</textarea>
                </section>
            `).join('')}
        </div>
    `;
}

function renderAdminPlayers() {
    content.innerHTML = `
        <section class="card">
            <div class="section-head">
                <h2>${esc(t('admin_players'))}</h2>
            </div>
            <div class="row">
                <input class="search" id="playerSearch" type="search" placeholder="${esc(t('search_player'))}">
                <button class="btn primary" data-action="searchPlayer" type="button">${esc(t('search'))}</button>
            </div>
        </section>
        <div class="grid">
            ${state.adminPlayers.length ? state.adminPlayers.map((player) => `
                <section class="card">
                    <div class="section-head">
                        <div>
                            <h2>${esc(player.displayName || player.identifier)}</h2>
                            <p class="muted">${esc(player.identifier)}</p>
                        </div>
                        <span class="badge">${esc(t('reputation'))}: ${esc(player.reputation || 0)}</span>
                    </div>
                    <div class="row">
                        ${['reset_reputation', 'reset_clients', 'clear_messages', 'reset_statistics', 'cancel_session', 'cancel_meetup'].map((action) => `
                            <button class="btn danger" data-action="playerAction" data-player="${esc(player.identifier)}" data-player-action="${esc(action)}" type="button">${esc(t(action))}</button>
                        `).join('')}
                    </div>
                </section>
            `).join('') : `<div class="empty">${esc(t('no_data'))}</div>`}
        </div>
    `;
}

function renderAdminLogs() {
    const rows = adminData().logs || [];
    content.innerHTML = `
        <div class="section-head">
            <h2>${esc(t('admin_logs'))}</h2>
            <button class="btn ghost" data-action="loadLogs" type="button">${esc(t('refresh_cache'))}</button>
        </div>
        <div class="admin-table">
            ${rows.length ? rows.map((log) => `
                <div class="admin-row">
                    <div>
                        <strong>${esc(log.category)} | ${esc(log.action)}</strong>
                        <span class="muted">${esc(log.player_name || '-')} | ${dateText(log.created_at)}</span>
                    </div>
                    <span class="badge">${esc(log.server_id || 0)}</span>
                </div>
            `).join('') : `<div class="empty">${esc(t('no_data'))}</div>`}
        </div>
    `;
}

function renderInteraction() {
    const payload = state.interaction;
    if (!payload) {
        interactionRoot.classList.remove('visible');
        interactionRoot.innerHTML = '';
        return;
    }

    const request = payload.request;
    const drug = payload.drug || {};
    const availableDrugs = payload.drugs || [];
    interactionRoot.classList.add('visible');
    interactionRoot.innerHTML = `
        <section class="interaction-card">
            <div class="section-head">
                <div>
                    <h2>${esc(request.alias)}</h2>
                    <p class="muted">${esc(request.archetype || '-')}</p>
                </div>
                <span class="badge warn">${esc(t('customer_patience'))}: ${esc(until(request.arrivalDeadline))}</span>
            </div>
            <div class="grid two">
                ${stat(t('requested_drug'), request.drugLabel || drug.label || request.drugId)}
                ${stat(t('requested_amount'), request.quantity)}
                ${stat(t('offered_payment'), money(request.price))}
                ${stat(t('customer_status'), request.status)}
            </div>
            <div class="row" style="margin-top:14px">
                <button class="btn primary" data-action="completeSale" data-request="${esc(request.id)}" type="button">${esc(t('sell_requested'))}</button>
                <button class="btn ghost" data-action="openOfferDrug" data-request="${esc(request.id)}" type="button">${esc(t('offer_different'))}</button>
                <button class="btn ghost" data-action="giveSample" data-request="${esc(request.id)}" type="button" ${request.sampleGiven ? 'disabled' : ''}>${esc(t('give_sample'))}</button>
                <button class="btn ghost" data-action="openExtraProduct" data-request="${esc(request.id)}" type="button">${esc(t('give_extra'))}</button>
                <button class="btn danger" data-action="declineSale" data-request="${esc(request.id)}" type="button">${esc(t('decline_sale'))}</button>
                <button class="btn ghost" data-action="leaveInteraction" type="button">${esc(t('leave'))}</button>
            </div>
            <select id="drugOfferSelect" hidden>
                ${availableDrugs.map((entry) => `<option value="${esc(entry.id)}">${esc(entry.label)}</option>`).join('')}
            </select>
        </section>
    `;
}

function toast(data) {
    const item = document.createElement('div');
    item.className = `toast ${esc(data.type || '')}`;
    item.innerHTML = `<strong>${esc(data.title || t('app_title'))}</strong><span>${esc(data.description || data.message || '')}</span>`;
    toastRoot.appendChild(item);
    setTimeout(() => item.remove(), data.duration || 4200);
}

function showPrompt(payload) {
    promptRoot.classList.add('visible');
    promptRoot.innerHTML = `<div class="zeekota-prompt"><div class="prompt-key">${esc(payload.key || 'E')}</div><div class="prompt-text">${esc(payload.text || t('speak_customer'))}</div></div>`;
}

function hidePrompt() {
    promptRoot.classList.remove('visible');
    promptRoot.innerHTML = '';
}

function openConfirm(message, onConfirm) {
    modalRoot.classList.add('visible');
    modalRoot.innerHTML = `
        <section class="modal">
            <h2>${esc(t('destructive_confirm'))}</h2>
            <p class="muted">${esc(message)}</p>
            <div class="row">
                <button class="btn danger" data-action="modalConfirm" type="button">${esc(t('confirm'))}</button>
                <button class="btn ghost" data-action="modalClose" type="button">${esc(t('cancel'))}</button>
            </div>
        </section>
    `;
    modalRoot._confirm = onConfirm;
}

function closeModal() {
    modalRoot.classList.remove('visible');
    modalRoot.innerHTML = '';
    modalRoot._confirm = null;
}

function openForm(titleText, fields, value, onSave) {
    modalRoot.classList.add('visible');
    modalRoot.innerHTML = `
        <section class="modal">
            <h2>${esc(titleText)}</h2>
            <form id="modalForm">
                ${fields.map((field) => formField(field, value)).join('')}
                <div class="row">
                    <button class="btn primary" type="submit">${esc(t('save'))}</button>
                    <button class="btn ghost" data-action="modalClose" type="button">${esc(t('cancel'))}</button>
                </div>
            </form>
        </section>
    `;
    document.getElementById('modalForm').addEventListener('submit', (event) => {
        event.preventDefault();
        const output = { ...(value || {}) };
        fields.forEach((field) => {
            if (!field.name) return;
            const element = document.querySelector(`[name="${field.name}"]`);
            if (!element) return;
            if (field.type === 'checkbox') output[field.name] = element.checked;
            else if (field.type === 'number') output[field.name] = Number(element.value || 0);
            else if (field.type === 'array') output[field.name] = element.value.split(',').map((item) => item.trim()).filter(Boolean);
            else output[field.name] = element.value;
        });
        closeModal();
        onSave(output);
    });
}

function formField(field, value) {
    if (field.type === 'locationTools') {
        return `<div class="form-tools"><button class="btn ghost" data-action="fillCurrentLocation" type="button">${esc(t('get_current_location'))}</button></div>`;
    }

    const current = value?.[field.name] ?? field.default ?? '';
    if (field.type === 'select') {
        return `<label class="field"><span>${esc(field.label)}</span><select name="${esc(field.name)}">${(field.options || []).map((option) => `<option value="${esc(option.id)}" ${String(current) === String(option.id) ? 'selected' : ''}>${esc(option.label)}</option>`).join('')}</select></label>`;
    }
    if (field.type === 'checkbox') {
        return `<label class="field"><span>${esc(field.label)}</span><input name="${esc(field.name)}" type="checkbox" ${current ? 'checked' : ''}></label>`;
    }
    if (field.type === 'textarea') {
        return `<label class="field"><span>${esc(field.label)}</span><textarea name="${esc(field.name)}">${esc(typeof current === 'string' ? current : JSON.stringify(current, null, 2))}</textarea></label>`;
    }
    return `<label class="field"><span>${esc(field.label)}</span><input name="${esc(field.name)}" type="${field.type || 'text'}" value="${esc(Array.isArray(current) ? current.join(', ') : current)}"></label>`;
}

function drugFields() {
    return [
        { name: 'id', label: t('id') },
        { name: 'item', label: t('item_name') },
        { name: 'label', label: t('label') },
        { name: 'icon', label: t('icon') },
        { name: 'enabled', label: t('enabled'), type: 'checkbox', default: true },
        { name: 'minQuantity', label: t('min_quantity'), type: 'number', default: 1 },
        { name: 'maxQuantity', label: t('max_quantity'), type: 'number', default: 5 },
        { name: 'minPrice', label: t('min_price'), type: 'number', default: 1 },
        { name: 'maxPrice', label: t('max_price'), type: 'number', default: 1 },
        { name: 'sampleQuantity', label: t('sample_quantity'), type: 'number', default: 1 },
        { name: 'sampleClientChanceBonus', label: t('sample_bonus'), type: 'number', default: 0 },
        { name: 'extraUnitBonus', label: t('extra_bonus'), type: 'number', default: 0 },
        { name: 'maxExtraUnits', label: t('max_extra'), type: 'number', default: 0 },
        { name: 'reputationRequirement', label: t('reputation_requirement'), type: 'number', default: 0 },
        { name: 'risk', label: t('risk'), type: 'number', default: 0 },
        { name: 'supportedArchetypes', label: t('supported_archetypes'), type: 'array' }
    ];
}

function archetypeFields() {
    return [
        { name: 'id', label: t('id') },
        { name: 'label', label: t('label') },
        { name: 'enabled', label: t('enabled'), type: 'checkbox', default: true },
        { name: 'pedModels', label: t('ped_models'), type: 'array' },
        { name: 'preferredDrugs', label: t('preferred_drug'), type: 'array' },
        { name: 'minQuantity', label: t('min_quantity'), type: 'number', default: 1 },
        { name: 'maxQuantity', label: t('max_quantity'), type: 'number', default: 5 },
        { name: 'budgetMultiplier', label: t('budget_multiplier'), type: 'number', default: 1 },
        { name: 'loyaltyGain', label: t('loyalty'), type: 'number', default: 0 },
        { name: 'patience', label: t('customer_patience'), type: 'number', default: 600 },
        { name: 'rejectionChance', label: t('rejected_offers'), type: 'number', default: 0 },
        { name: 'policeAlertChance', label: t('police_alert_chance'), type: 'number', default: 0 },
        { name: 'scamChance', label: t('scam_chance'), type: 'number', default: 0 },
        { name: 'negotiationTolerance', label: t('negotiation_tolerance'), type: 'number', default: 50 },
        { name: 'acquisitionModifier', label: t('acquisition_modifier'), type: 'number', default: 0 },
        { name: 'risk', label: t('risk'), type: 'number', default: 0 }
    ];
}

function locationFields() {
    return [
        { type: 'locationTools' },
        { name: 'id', label: t('id') },
        { name: 'label', label: t('label') },
        { name: 'area', label: t('current_area') },
        { name: 'x', label: t('coordinate_x'), type: 'number' },
        { name: 'y', label: t('coordinate_y'), type: 'number' },
        { name: 'z', label: t('coordinate_z'), type: 'number' },
        { name: 'heading', label: t('heading'), type: 'number' },
        { name: 'enabled', label: t('enabled'), type: 'checkbox', default: true },
        { name: 'risk', label: t('risk'), type: 'number', default: 0 },
        { name: 'supportedArchetypes', label: t('supported_archetypes'), type: 'array' }
    ];
}

async function doAction(action, payload = {}) {
    const result = await nui(action, payload);
    if (!result.ok) toast({ title: t('error'), description: result.error || t('error'), type: 'error' });
    return result;
}

function fillLocationForm(location) {
    const form = document.getElementById('modalForm');
    if (!form || !location) return;

    const setValue = (name, value, overwrite = true) => {
        const element = form.querySelector(`[name="${name}"]`);
        if (!element || value === undefined || value === null) return;
        if (!overwrite && element.value) return;
        element.value = value;
    };

    setValue('id', location.id, false);
    setValue('label', location.label, false);
    setValue('area', location.area);
    setValue('x', Number(location.x || 0).toFixed(3));
    setValue('y', Number(location.y || 0).toFixed(3));
    setValue('z', Number(location.z || 0).toFixed(3));
    setValue('heading', Number(location.heading || 0).toFixed(2));
}

async function currentLocationPayload() {
    const result = await doAction('adminGetCurrentLocation', {});
    return result?.ok ? result.location : null;
}

function openLocationForm(value) {
    return openForm(t('admin_locations'), locationFields(), value, async (payload) => {
        await doAction('adminSaveLocation', payload);
        await refresh();
    });
}

async function refresh() {
    const result = await nui(state.mode === 'admin' ? 'adminRefresh' : 'refresh', {});
    if (result?.ok) {
        setDashboard(result);
        render();
    }
    return result;
}

document.body.addEventListener('input', (event) => {
    if (event.target.matches('[data-action="search"]')) {
        state.search = event.target.value;
        renderMessages();
    }
});

document.body.addEventListener('click', async (event) => {
    const button = event.target.closest('[data-action]');
    if (!button) return;
    const action = button.dataset.action;

    if (action === 'tab') {
        if (state.mode === 'admin') state.adminTab = button.dataset.tab;
        else state.tab = button.dataset.tab;
        render();
        return;
    }

    if (action === 'modalClose') return closeModal();
    if (action === 'modalConfirm') {
        const fn = modalRoot._confirm;
        closeModal();
        if (fn) await fn();
        return;
    }
    if (action === 'fillCurrentLocation') {
        const location = await currentLocationPayload();
        if (location) fillLocationForm(location);
        return;
    }

    if (action === 'goLive' || action === 'endSession') return refreshAfter(action);
    if (action === 'selectConversation') {
        state.selectedConversationId = button.dataset.id;
        state.tab = 'messages';
        render();
        return;
    }
    if (action === 'acceptRequest') return refreshAfter('acceptRequest', { requestId: button.dataset.request });
    if (action === 'declineRequest') return refreshAfter('declineRequest', { requestId: button.dataset.request });
    if (action === 'cancelMeetup') return refreshAfter('cancelMeetup', { requestId: button.dataset.request });
    if (action === 'markRead') return refreshAfter('markRead', { conversationId: button.dataset.id });
    if (action === 'deleteConversation') return openConfirm(t('delete_conversation'), () => refreshAfter('deleteConversation', { conversationId: button.dataset.id }));
    if (action === 'blockClient' || action === 'unblockClient') return refreshAfter(action, { customerKey: button.dataset.customer });
    if (action === 'clientSubtab') {
        state.clientSubtab = button.dataset.tab;
        render();
        return;
    }

    if (action === 'leaveInteraction') return doAction('leaveInteraction');
    if (action === 'completeSale') return refreshAfter('completeSale', { requestId: button.dataset.request, extraQuantity: 0 });
    if (action === 'giveSample') return refreshAfter('giveSample', { requestId: button.dataset.request });
    if (action === 'declineSale') return refreshAfter('declineSale', { requestId: button.dataset.request });
    if (action === 'openOfferDrug') {
        const options = drugs().map((drug) => ({ id: drug.id, label: drug.label }));
        const selected = options[0]?.id || '';
        openForm(t('offer_different'), [{ name: 'drugId', label: t('choose_drug'), type: 'select', options, default: selected }], { drugId: selected }, (value) => refreshAfter('offerDifferentDrug', { requestId: button.dataset.request, drugId: value.drugId }));
        return;
    }
    if (action === 'openExtraProduct') {
        openForm(t('give_extra'), [{ name: 'extraQuantity', label: t('extra_units'), type: 'number', default: 1 }], { extraQuantity: 1 }, (value) => refreshAfter('completeSale', { requestId: button.dataset.request, extraQuantity: value.extraQuantity }));
        return;
    }

    await adminClick(action, button);
});

async function refreshAfter(action, payload = {}) {
    const result = await doAction(action, payload);
    if (result.ok) await refresh();
    return result;
}

async function adminClick(action, button) {
    const id = button.dataset.id;
    const data = adminData();
    if (action === 'adminRefreshCache') return refreshAfter('adminRefreshCache');
    if (action === 'editDrug' || action === 'duplicateDrug') {
        const original = (data.drugs || []).find((entry) => entry.id === id);
        const value = original ? { ...original } : {};
        if (action === 'duplicateDrug') value.id = `${value.id}_copy`;
        return openForm(t('admin_drugs'), drugFields(), value, async (payload) => {
            await doAction('adminSaveDrug', payload);
            await refresh();
        });
    }
    if (action === 'deleteDrug') return openConfirm(t('delete'), () => refreshAfter('adminDeleteDrug', { id }));
    if (action === 'testDrugItem') {
        const drug = (data.drugs || []).find((entry) => entry.id === id);
        const result = await doAction('adminTestItem', { item: drug?.item });
        toast({ title: t('test_item'), description: result.exists ? t('enabled') : t('error'), type: result.exists ? 'success' : 'error' });
        return;
    }
    if (action === 'editArchetype' || action === 'duplicateArchetype') {
        const original = (data.archetypes || []).find((entry) => entry.id === id);
        const value = original ? { ...original } : {};
        if (action === 'duplicateArchetype') value.id = `${value.id}_copy`;
        return openForm(t('admin_archetypes'), archetypeFields(), value, async (payload) => {
            await doAction('adminSaveArchetype', payload);
            await refresh();
        });
    }
    if (action === 'deleteArchetype') return openConfirm(t('delete'), () => refreshAfter('adminDeleteArchetype', { id }));
    if (action === 'editLocation') {
        const value = (data.locations || []).find((entry) => entry.id === id) || {};
        return openLocationForm(value);
    }
    if (action === 'addCurrentLocation') {
        const location = await currentLocationPayload();
        if (location) return openLocationForm(location);
        return;
    }
    if (action === 'deleteLocation') return openConfirm(t('delete'), () => refreshAfter('adminDeleteLocation', { id }));
    if (action === 'teleportLocation') {
        const location = (data.locations || []).find((entry) => entry.id === id);
        return doAction('adminTeleportLocation', { location });
    }
    if (action === 'testLocation') {
        const location = (data.locations || []).find((entry) => entry.id === id);
        const archetype = (data.archetypes || [])[0];
        return doAction('adminTestSpawn', { location, archetype });
    }
    if (action === 'saveSetting') {
        const key = button.dataset.key;
        const field = document.querySelector(`.setting-json[data-key="${CSS.escape(key)}"]`);
        let value;
        try {
            value = JSON.parse(field.value);
        } catch {
            return toast({ title: t('error'), description: t('error'), type: 'error' });
        }
        await doAction('adminSaveSetting', { key, value, type: 'json' });
        return refresh();
    }
    if (action === 'searchPlayer') {
        const query = document.getElementById('playerSearch')?.value || '';
        const result = await doAction('adminSearchPlayer', { query });
        state.adminPlayers = result.players || [];
        render();
        return;
    }
    if (action === 'playerAction') {
        const identifier = button.dataset.player;
        const playerAction = button.dataset.playerAction;
        return openConfirm(t(playerAction), async () => {
            await doAction('adminPlayerAction', { identifier, action: playerAction });
            const result = await doAction('adminSearchPlayer', { query: identifier });
            state.adminPlayers = result.players || [];
            render();
        });
    }
    if (action === 'loadLogs') {
        const result = await doAction('adminGetLogs', { page: state.logsPage });
        if (result.ok) {
            state.dashboard.logs = result.logs || [];
            render();
        }
    }
}

closeBtn.addEventListener('click', () => {
    nui('close');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' || event.key === 'Backspace') {
        if (modalRoot.classList.contains('visible')) closeModal();
        else nui('close');
    }
});

window.addEventListener('message', async (event) => {
    const { action, payload } = event.data || {};
    if (action === 'open') {
        state.visible = true;
        state.mode = payload.mode || 'dealer';
        setDashboard(payload.dashboard);
        root.classList.add('visible');
        render();
        return;
    }
    if (action === 'close') {
        state.visible = false;
        state.interaction = null;
        root.classList.remove('visible');
        interactionRoot.classList.remove('visible');
        closeModal();
        return;
    }
    if (action === 'sync') {
        setDashboard(payload);
        render();
        return;
    }
    if (action === 'newRequest' || action === 'requestUpdated') {
        if (state.visible) await refresh();
        return;
    }
    if (action === 'meetupStarted') {
        return;
    }
    if (action === 'meetupEnded') {
        state.interaction = null;
        renderInteraction();
        return;
    }
    if (action === 'openInteraction') {
        state.interaction = payload;
        renderInteraction();
        return;
    }
    if (action === 'closeInteraction') {
        state.interaction = null;
        renderInteraction();
        return;
    }
    if (action === 'showPrompt') return showPrompt(payload || {});
    if (action === 'hidePrompt') return hidePrompt();
    if (action === 'toast') return toast(payload || {});
});

setInterval(() => {
    if (state.visible && (state.mode === 'admin' || state.tab !== 'messages')) render();
    if (state.interaction) renderInteraction();
}, 1000);
