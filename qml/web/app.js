(function () {
    "use strict";

    var Core = window.DhunCore;
    var DATA = window.DHUN_DATA;
    var CONFIG = window.DHUN_CONFIG || {};
    var params = new URLSearchParams(window.location.search);
    var embedded = params.get("embedded") === "1";
    if (embedded) document.body.classList.add("embedded");
    var STORAGE_KEY = "dhun.studio.v1";
    var KEY_STORAGE = "dhun.maps.key";
    var NOTICE_KEY = "dhun.keyNotice.dismissed";
    var MAX_ACTIVITY_KM = 8;
    var MAX_VIDEO_SECONDS = Number(CONFIG.maxVideoSeconds) || 20;
    var MAX_VIDEO_BYTES = 40 * 1024 * 1024;
    var ROLE_LABELS = { funder: "Funder", dhun: "Dhun", steward: "Steward" };
    var FALLBACK_LAT_SPAN = 0.0125;
    var FALLBACK_LNG_SPAN = 0.0142;

    function $(id) { return document.getElementById(id); }

    var dom = {
        roleSwitch: $("roleSwitch"), searchInput: $("searchInput"), searchResults: $("searchResults"),
        updatesBtn: $("updatesBtn"), updateCount: $("updateCount"), setupBtn: $("setupBtn"),
        recordBtn: $("recordBtn"), mapPanel: $("mapPanel"), map: $("map"), mapFallback: $("mapFallback"),
        fallbackPins: $("fallbackPins"), fallbackFlagText: $("fallbackFlagText"),
        seasonSwitch: $("seasonSwitch"), locateBtn: $("locateBtn"),
        addActivityBtn: $("addActivityBtn"), mapBadgeText: $("mapBadgeText"),
        placementHint: $("placementHint"), cancelPlacement: $("cancelPlacement"), mapCard: $("mapCard"),
        freshnessLabel: $("freshnessLabel"), keyNotice: $("keyNotice"), keyNoticeBtn: $("keyNoticeBtn"),
        calendarTitle: $("calendarTitle"), prevMonth: $("prevMonth"), nextMonth: $("nextMonth"),
        calendarStats: $("calendarStats"), calendarGrid: $("calendarGrid"), calendarAdd: $("calendarAdd"),
        agendaEyebrow: $("agendaEyebrow"), agendaTitle: $("agendaTitle"), agendaRole: $("agendaRole"),
        agendaList: $("agendaList"), inventoryUpdated: $("inventoryUpdated"), dockFilters: $("dockFilters"),
        dockCount: $("dockCount"), produceDock: $("produceDock"), scrim: $("scrim"),
        updatesDrawer: $("updatesDrawer"), closeUpdates: $("closeUpdates"), updatesList: $("updatesList"),
        drawerRecord: $("drawerRecord"), drawerNoteText: $("drawerNoteText"),
        activityModal: $("activityModal"), activityForm: $("activityForm"), activityTitle: $("activityTitle"),
        activityTypes: $("activityTypes"), activityZone: $("activityZone"),
        activityProduce: $("activityProduce"), activityRole: $("activityRole"),
        activityDate: $("activityDate"), activityTime: $("activityTime"),
        activityVisibility: $("activityVisibility"), activityNotes: $("activityNotes"),
        activityLocation: $("activityLocation"), pickOnMap: $("pickOnMap"), activityError: $("activityError"),
        videoModal: $("videoModal"), videoPreview: $("videoPreview"), videoEmpty: $("videoEmpty"),
        maxVideoLabel: $("maxVideoLabel"), recordTimer: $("recordTimer"),
        startCamera: $("startCamera"), toggleRecord: $("toggleRecord"), videoFile: $("videoFile"),
        cameraStatus: $("cameraStatus"), videoForm: $("videoForm"), videoTitle: $("videoTitle"),
        videoProduce: $("videoProduce"), videoZone: $("videoZone"), videoDate: $("videoDate"),
        videoTime: $("videoTime"), videoNotes: $("videoNotes"), videoError: $("videoError"),
        videoShareHint: $("videoShareHint"), setupModal: $("setupModal"), referrerText: $("referrerText"),
        mapsKeyInput: $("mapsKeyInput"), saveKey: $("saveKey"), removeKey: $("removeKey"),
        toast: $("toast")
    };

    function readJSON(key) {
        try { return JSON.parse(window.localStorage.getItem(key) || "null"); }
        catch (error) { return null; }
    }

    function writeStorage(key, value) {
        try { window.localStorage.setItem(key, value); return true; }
        catch (error) { return false; }
    }

    function readKey() {
        try { return window.localStorage.getItem(KEY_STORAGE) || ""; }
        catch (error) { return ""; }
    }

    function esc(value) {
        return String(value === null || value === undefined ? "" : value).replace(/[&<>"']/g, function (ch) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
        });
    }

    function clampNumber(value, min, max) {
        var number = Number(value);
        if (!isFinite(number)) number = min;
        return Math.max(min, Math.min(max, number));
    }

    function startOfDay(timestamp) {
        var date = new Date(Number(timestamp) || Date.now());
        date.setHours(0, 0, 0, 0);
        return date.getTime();
    }

    function dateInputValue(timestamp) {
        var date = new Date(Number(timestamp));
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
    }

    function timeInputValue(timestamp) {
        var date = new Date(Number(timestamp));
        return String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
    }

    function combineDateAndTime(dateValue, timeValue) {
        var dateParts = String(dateValue || "").split("-");
        if (dateParts.length !== 3) return 0;
        var timeParts = String(timeValue || "08:00").split(":");
        var year = Number(dateParts[0]);
        var month = Number(dateParts[1]);
        var day = Number(dateParts[2]);
        var hour = Number(timeParts[0] || 0);
        var minute = Number(timeParts[1] || 0);
        if (!year || month < 1 || month > 12 || day < 1 || day > 31) return 0;
        var date = new Date(year, month - 1, day, hour, minute, 0, 0);
        if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return 0;
        return date.getTime();
    }

    function timeLabel(timestamp) {
        var date = new Date(Number(timestamp));
        return String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
    }

    function dayLabel(timestamp) {
        var value = startOfDay(timestamp);
        var today = startOfDay(Date.now());
        if (value === today) return "Today";
        if (value === today + 86400000) return "Tomorrow";
        if (value === today - 86400000) return "Yesterday";
        var date = new Date(value);
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()] + " " +
            date.getDate() + " " + Core.MONTHS[date.getMonth()];
    }

    function shortDate(timestamp) {
        var date = new Date(Number(timestamp));
        return Core.MONTHS[date.getMonth()] + " " + date.getDate() + " \u00B7 " + timeLabel(timestamp);
    }

    function formatBytes(bytes) {
        var size = Number(bytes) || 0;
        if (size < 1024) return size + " B";
        if (size < 1048576) return (size / 1024).toFixed(0) + " KB";
        return (size / 1048576).toFixed(1) + " MB";
    }

    function distanceKm(a, b) {
        var radius = 6371;
        var toRad = Math.PI / 180;
        var dLat = (Number(b.latitude) - Number(a.latitude)) * toRad;
        var dLng = (Number(b.longitude) - Number(a.longitude)) * toRad;
        var lat1 = Number(a.latitude) * toRad;
        var lat2 = Number(b.latitude) * toRad;
        var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * radius * Math.asin(Math.min(1, Math.sqrt(h)));
    }

    function findProduce(id) {
        for (var i = 0; i < DATA.produce.length; ++i) if (DATA.produce[i].id === id) return DATA.produce[i];
        return null;
    }

    function findZone(id) {
        for (var i = 0; i < DATA.zones.length; ++i) if (DATA.zones[i].id === id) return DATA.zones[i];
        return null;
    }

    function findGrower(id) {
        for (var i = 0; i < DATA.growers.length; ++i) if (DATA.growers[i].id === id) return DATA.growers[i];
        return null;
    }

    function findActivity(id) {
        for (var i = 0; i < app.activities.length; ++i) if (app.activities[i].id === id) return app.activities[i];
        return null;
    }

    function typeById(id) {
        for (var i = 0; i < DATA.activityTypes.length; ++i) if (DATA.activityTypes[i].id === id) return DATA.activityTypes[i];
        return { id: id || "review", label: "Work", color: "#C76B47", hint: "" };
    }

    function inSeasonNow(item) {
        return !!item && (item.yearRound || item.months.indexOf(new Date().getMonth() + 1) !== -1);
    }

    function stockEntry(id) {
        return app.inventory[id] || { stock: 0, updatedAt: 0, lastOrder: null };
    }

    function stockOf(id) { return Number(stockEntry(id).stock) || 0; }

    function stockLabel(item) {
        var stock = stockOf(item.id);
        if (stock <= 0) return inSeasonNow(item) ? "Sold out" : "Out of season";
        if (stock <= 9) return stock + " " + item.unit + " left";
        return stock + " " + item.unit;
    }

    function stockClass(item) {
        var stock = stockOf(item.id);
        if (stock <= 0) return "gone";
        if (stock <= 9) return "low";
        return "";
    }

    function visibleProduce() {
        if (app.season === "current") return DATA.produce.filter(inSeasonNow);
        return DATA.produce.slice();
    }

    function produceForGrower(growerId) {
        return DATA.produce.filter(function (item) { return item.grower.id === growerId; });
    }

    function produceInZone(zoneId) {
        return DATA.produce.filter(function (item) { return item.zone === zoneId; });
    }

    function zoneActivities(zoneId) {
        return app.activities.filter(function (activity) { return activity.zone === zoneId; });
    }

    function roleInitial(role) {
        return (ROLE_LABELS[role] || "D").charAt(0);
    }

    var stored = readJSON(STORAGE_KEY) || {};
    var storedRole = stored.role === "funder" || stored.role === "dhun" || stored.role === "steward" ? stored.role : "dhun";
    var urlRole = params.get("role");
    var initialRole = urlRole === "funder" || urlRole === "dhun" || urlRole === "steward" ? urlRole : storedRole;
    var today = startOfDay(Date.now());

    var app = {
        role: initialRole,
        activities: [],
        updates: [],
        inventory: {},
        category: "All",
        season: "current",
        viewYear: new Date(today).getFullYear(),
        viewMonth: new Date(today).getMonth(),
        selectedDate: today,
        activeProduce: null,
        activeCard: null,
        draft: null,
        placing: false,
        placingReturn: false,
        currentPlace: null,
        order: null,
        searchRows: [],
        searchActive: -1,
        searchMode: "local",
        searchToken: 0,
        geocodeResults: [],
        geocoderReady: false,
        authFailed: false,
        mapProvider: "plan",
        leaflet: null,
        leafletGroup: null,
        leafletMarkers: {},
        memoryMedia: {},
        mediaURLs: {},
        video: { session: 0, stream: null, recorder: null, chunks: [], pending: null, pendingUrl: "", timer: null, startedAt: 0 },
        toastTimer: null
    };

    function hydrateActivities() {
        var previous = {};
        var previousList = Array.isArray(stored.activities) ? stored.activities : [];
        previousList.forEach(function (activity) { if (activity && activity.id) previous[activity.id] = activity; });
        var seedIds = {};
        var merged = DATA.seededActivities.map(function (seed) {
            seedIds[seed.id] = true;
            var copy = JSON.parse(JSON.stringify(seed));
            var old = previous[seed.id];
            if (old) {
                copy.status = old.status === "done" ? "done" : "planned";
                if (old.visibility) copy.visibility = old.visibility;
            }
            return copy;
        });
        previousList.forEach(function (activity) {
            if (activity && activity.id && !seedIds[activity.id]) merged.push(activity);
        });
        return merged;
    }

    function hydrateUpdates() {
        var seedIds = {};
        var merged = DATA.seedUpdates.map(function (seed) {
            seedIds[seed.id] = true;
            return JSON.parse(JSON.stringify(seed));
        });
        var previousList = Array.isArray(stored.updates) ? stored.updates : [];
        previousList.forEach(function (update) {
            if (update && update.id && !seedIds[update.id]) merged.push(update);
        });
        return merged;
    }

    function hydrateInventory() {
        var inventory = {};
        DATA.produce.forEach(function (item) {
            inventory[item.id] = { stock: Number(item.stock) || 0, updatedAt: Number(item.updatedAt) || Date.now(), lastOrder: null };
        });
        var previous = stored.inventory && typeof stored.inventory === "object" ? stored.inventory : {};
        Object.keys(previous).forEach(function (id) {
            if (!inventory[id]) return;
            var entry = previous[id] || {};
            var stock = Number(entry.stock);
            if (isFinite(stock)) inventory[id].stock = Math.max(0, Math.floor(stock));
            var updatedAt = Number(entry.updatedAt);
            if (isFinite(updatedAt) && updatedAt > 0) inventory[id].updatedAt = updatedAt;
            if (entry.lastOrder && entry.lastOrder.reference) inventory[id].lastOrder = entry.lastOrder;
        });
        return inventory;
    }

    function persist() {
        var payload = {
            v: 1,
            role: app.role,
            activities: app.activities,
            updates: app.updates,
            inventory: app.inventory,
            savedAt: Date.now()
        };
        if (!writeStorage(STORAGE_KEY, JSON.stringify(payload))) {
            toast("This browser blocked local storage. Changes will last only for this session.", true);
        }
    }

    function nextId(prefix, list) {
        var max = 0;
        list.forEach(function (entry) {
            var number = parseInt(String(entry.id || "").replace(/\D/g, ""), 10);
            if (isFinite(number) && number > max) max = number;
        });
        return prefix + "-" + String(max + 1).padStart(3, "0");
    }

    function emit(type, payload) {
        var detail = Object.assign({ type: type, at: Date.now() }, payload || {});
        if (embedded) bridgeEvents.push(detail);
        try { window.dispatchEvent(new CustomEvent("dhun:event", { detail: detail })); }
        catch (error) { /* older WebViews */ }
    }

    var bridgeEvents = [];

    function toast(message, isError) {
        if (!dom.toast) return;
        dom.toast.textContent = message;
        dom.toast.classList.toggle("error", !!isError);
        dom.toast.classList.remove("hidden");
        if (app.toastTimer) window.clearTimeout(app.toastTimer);
        app.toastTimer = window.setTimeout(function () { dom.toast.classList.add("hidden"); }, isError ? 5200 : 3600);
    }

    function setBadge(text) {
        if (dom.mapBadgeText) dom.mapBadgeText.textContent = text;
    }

    function syncRoleButtons() {
        if (!dom.roleSwitch) return;
        dom.roleSwitch.querySelectorAll("[data-role]").forEach(function (button) {
            var active = button.getAttribute("data-role") === app.role;
            button.classList.toggle("active", active);
            button.setAttribute("aria-pressed", active ? "true" : "false");
        });
        if (dom.agendaRole) dom.agendaRole.textContent = ROLE_LABELS[app.role];
    }

    function switchRole(role, announce) {
        if (!ROLE_LABELS[role] || role === app.role) {
            syncRoleButtons();
            return;
        }
        app.role = role;
        syncRoleButtons();
        renderCalendar();
        renderAgenda();
        persist();
        if (announce) emit("role", { role: role });
    }

    function showMapCard(html, card) {
        app.activeCard = card;
        dom.mapCard.innerHTML = html;
        dom.mapCard.classList.remove("hidden");
    }

    function hideMapCard() {
        dom.mapCard.classList.add("hidden");
        dom.mapCard.innerHTML = "";
        app.activeCard = null;
    }

    function dismissMapCard() {
        var hadProduce = !!(app.activeCard && app.activeCard.kind === "produce");
        hideMapCard();
        if (hadProduce) {
            app.activeProduce = null;
            renderDock();
            renderMarkers();
        }
    }

    function refreshCard() {
        if (!app.activeCard) return;
        var card = app.activeCard;
        if (card.kind === "produce") showProduceCard(card.id);
        else if (card.kind === "activity") showActivityCard(card.id);
        else if (card.kind === "zone") showZoneCard(card.id);
        else if (card.kind === "site") showSiteCard();
        else if (card.kind === "grower") showGrowerCard(card.id);
        else if (card.kind === "place" && app.currentPlace) showPlaceCard(app.currentPlace);
        else if (card.kind === "point") showPointCard(card.point);
    }

    function renderCalendar() {
        var cells = Core.monthCells(app.viewYear, app.viewMonth);
        var roleActivities = Core.activitiesForRole(app.activities, app.role);
        var byDay = {};
        roleActivities.forEach(function (activity) {
            var key = Core.dateKey(activity.date);
            if (!byDay[key]) byDay[key] = [];
            byDay[key].push(activity);
        });
        var monthItems = roleActivities.filter(function (activity) {
            var date = new Date(activity.date);
            return date.getFullYear() === app.viewYear && date.getMonth() === app.viewMonth;
        });
        var done = monthItems.filter(function (activity) { return activity.status === "done"; }).length;
        dom.calendarTitle.textContent = Core.monthLabel(app.viewYear, app.viewMonth);
        dom.calendarStats.innerHTML =
            "<span><strong>" + monthItems.length + "</strong> this month</span>" +
            "<span><strong>" + (monthItems.length - done) + "</strong> planned</span>" +
            "<span><strong>" + done + "</strong> done</span>";
        var todayKey = Core.dateKey(Date.now());
        var selectedKey = Core.dateKey(app.selectedDate);
        dom.calendarGrid.innerHTML = cells.map(function (cell) {
            var key = Core.dateKey(cell.timestamp);
            var items = byDay[key] || [];
            var classes = ["cal-day"];
            if (!cell.inMonth) classes.push("out");
            if (key === todayKey) classes.push("today");
            if (key === selectedKey) classes.push("selected");
            var dots = items.slice(0, 3).map(function (activity) {
                return '<i style="background:' + esc(typeById(activity.type).color) + '"></i>';
            }).join("");
            var label = new Date(cell.timestamp).toDateString() + " \u00B7 " + items.length + " work item" + (items.length === 1 ? "" : "s");
            return '<button type="button" class="' + classes.join(" ") + '" data-day="' + cell.timestamp + '" aria-label="' + esc(label) + '">' +
                "<span>" + cell.day + "</span>" + (dots ? '<span class="cal-dots">' + dots + "</span>" : "") +
                "</button>";
        }).join("");
    }

    function renderAgenda() {
        var items = Core.activitiesOnDay(app.activities, app.role, app.selectedDate);
        var todayValue = startOfDay(Date.now());
        dom.agendaTitle.textContent = dayLabel(app.selectedDate);
        dom.agendaEyebrow.textContent = startOfDay(app.selectedDate) === todayValue ? "Today \u00B7 selected day" : "Selected day";
        dom.agendaRole.textContent = ROLE_LABELS[app.role];
        if (!items.length) {
            dom.agendaList.innerHTML = '<div class="agenda-empty">No ' + esc(ROLE_LABELS[app.role].toLowerCase()) +
                " work on this day.<br><button type=\"button\" class=\"link-btn\" data-act=\"add\">Add work for this day</button></div>";
            return;
        }
        dom.agendaList.innerHTML = items.map(function (activity) {
            var type = typeById(activity.type);
            var produce = activity.produceId ? findProduce(activity.produceId) : null;
            var zone = findZone(activity.zone);
            var meta = [type.label, zone ? zone.short : "", produce ? produce.name : ""].filter(Boolean).join(" \u00B7 ");
            return '<div class="agenda-item">' +
                '<div class="agenda-time">' + timeLabel(activity.date) + "</div>" +
                '<div class="agenda-mark" style="background:' + esc(type.color) + '"></div>' +
                '<div class="agenda-copy">' +
                '<strong class="' + (activity.status === "done" ? "agenda-done" : "") + '">' + esc(activity.title) + "</strong>" +
                "<span>" + esc(meta) + (activity.source === "challenge" ? " \u00B7 covenant task" : "") + "</span>" +
                '<div class="agenda-actions">' +
                '<button type="button" data-act="toggle" data-id="' + esc(activity.id) + '">' +
                (activity.status === "done" ? "Reopen" : "Mark done") + "</button>" +
                '<button type="button" data-act="map" data-id="' + esc(activity.id) + '">Map</button>' +
                (activity.media && activity.media.length ? '<button type="button" data-act="clip" data-id="' + esc(activity.id) + '">Clip</button>' : "") +
                "</div></div></div>";
        }).join("");
    }

    function renderDockFilters() {
        var preferred = ["All", "Vegetable", "Fruit", "Grain", "Pulse", "Herb", "Dairy", "Poultry", "Seed"];
        var present = {};
        DATA.produce.forEach(function (item) { present[item.category] = true; });
        var categories = preferred.filter(function (name) { return name === "All" || present[name]; });
        if (categories.indexOf(app.category) === -1) app.category = "All";
        dom.dockFilters.innerHTML = categories.map(function (name) {
            return '<button type="button" class="filter-chip' + (app.category === name ? " active" : "") +
                '" data-cat="' + esc(name) + '">' + esc(name) + "</button>";
        }).join("");
    }

    function renderDock() {
        renderDockFilters();
        var scroll = dom.produceDock.scrollLeft;
        var items = DATA.produce.filter(function (item) {
            return app.category === "All" || item.category === app.category;
        });
        items.sort(function (a, b) {
            var aScore = (stockOf(a.id) > 0 ? 2 : 0) + (inSeasonNow(a) ? 1 : 0);
            var bScore = (stockOf(b.id) > 0 ? 2 : 0) + (inSeasonNow(b) ? 1 : 0);
            return bScore - aScore || a.name.localeCompare(b.name);
        });
        dom.dockCount.textContent = String(items.filter(function (item) { return stockOf(item.id) > 0; }).length);
        if (!items.length) {
            dom.produceDock.innerHTML = '<div class="dock-empty">No produce in this category.</div>';
        } else {
            dom.produceDock.innerHTML = items.map(function (item) {
                var stock = stockOf(item.id);
                return '<article class="produce-card' + (app.activeProduce === item.id ? " active" : "") +
                    (inSeasonNow(item) ? "" : " out") + '" data-id="' + esc(item.id) + '">' +
                    '<img class="produce-image" src="' + esc(item.photo) + '" alt="' + esc(item.name) + ' illustration" loading="lazy">' +
                    '<span class="produce-zone">' + esc(findZone(item.zone).short) + "</span>" +
                    '<span class="produce-stock ' + stockClass(item) + '"><i class="stock-dot"></i>' + esc(stockLabel(item)) + "</span>" +
                    '<div class="produce-body">' +
                    '<div class="produce-name-row"><span class="produce-name">' + esc(item.name) + "</span>" +
                    '<span class="produce-local">' + esc(item.local) + "</span></div>" +
                    '<span class="produce-grower">' + esc(item.growerName) + " \u00B7 " + esc(item.harvestLabel) + "</span>" +
                    '<div class="produce-foot">' +
                    '<span class="produce-price">' + Core.formatINR(item.price) + "<small>/" + esc(item.unit) + "</small></span>" +
                    '<span class="produce-actions">' +
                    '<button type="button" class="mini-btn" data-act="map">Map</button>' +
                    '<button type="button" class="mini-btn primary" data-act="procure"' + (stock <= 0 ? " disabled" : "") + ">Procure</button>" +
                    "</span></div></div></article>";
            }).join("");
        }
        dom.produceDock.scrollLeft = scroll;
        renderFreshness();
    }

    function renderFreshness() {
        var latest = 0;
        DATA.produce.forEach(function (item) {
            var entry = stockEntry(item.id);
            if (Number(entry.updatedAt) > latest) latest = Number(entry.updatedAt);
        });
        var label = latest ? Core.timeAgo(latest, Date.now()) : "just now";
        if (dom.freshnessLabel) dom.freshnessLabel.textContent = "stock " + label;
        if (dom.inventoryUpdated) {
            dom.inventoryUpdated.textContent = (embedded ? "Rehearsal inventory \u00B7 wallet orders update stock" : "Local rehearsal inventory \u00B7 updated when you procure") + " \u00B7 " + label;
        }
    }

    function renderUpdateCount() {
        if (dom.updateCount) dom.updateCount.textContent = String(app.updates.length);
    }

    function renderMarkers() {
        renderFallbackMarkers();
        renderLeafletMarkers();
    }

    function fallbackPercent(latitude, longitude) {
        var x = 50 + ((Number(longitude) - DATA.site.longitude) / FALLBACK_LNG_SPAN) * 100;
        var y = 50 - ((Number(latitude) - DATA.site.latitude) / FALLBACK_LAT_SPAN) * 100;
        return { x: clampNumber(x, 3, 97), y: clampNumber(y, 3, 97) };
    }

    function renderFallbackMarkers() {
        if (!dom.fallbackPins) return;
        var fragment = document.createDocumentFragment();
        var visible = visibleProduce();

        function pin(kind, id, latitude, longitude, className, html, label, background) {
            var button = document.createElement("button");
            button.type = "button";
            button.className = "fallback-pin " + className;
            button.setAttribute("data-kind", kind);
            if (id) button.setAttribute("data-id", id);
            var position = fallbackPercent(latitude, longitude);
            button.style.left = position.x + "%";
            button.style.top = position.y + "%";
            if (background) button.style.background = background;
            button.innerHTML = html;
            button.title = label;
            button.setAttribute("aria-label", label);
            fragment.appendChild(button);
        }

        DATA.zones.forEach(function (zone) {
            var count = visible.filter(function (item) { return item.zone === zone.id; }).length;
            pin("zone", zone.id, zone.latitude, zone.longitude, "zone-pin",
                '<i class="zone-dot" style="background:' + esc(zone.color) + '"></i><span>' + esc(zone.short) + " \u00B7 " + count + "</span>",
                zone.name + " \u00B7 " + count + " produce plots", "");
        });

        pin("site", "dhun", DATA.site.latitude, DATA.site.longitude, "site-pin",
            '<svg><use href="#i-leaf"/></svg>', "Dhun at " + DATA.site.place, "");

        visible.forEach(function (item) {
            var stock = stockOf(item.id);
            var label = item.name + " \u00B7 " + item.growerName + " \u00B7 " + stockLabel(item);
            var button = document.createElement("button");
            button.type = "button";
            button.className = "fallback-pin produce-pin" + (inSeasonNow(item) ? "" : " out") + (app.activeProduce === item.id ? " selected" : "");
            button.setAttribute("data-kind", "produce");
            button.setAttribute("data-id", item.id);
            var position = fallbackPercent(item.plot.latitude, item.plot.longitude);
            button.style.left = position.x + "%";
            button.style.top = position.y + "%";
            button.innerHTML = '<img src="' + esc(item.photo) + '" alt="' + esc(item.name) + '"><span>' + esc(item.name) + "</span>";
            button.title = label + " \u00B7 " + (stock > 0 ? "procure in the dock" : "no stock");
            button.setAttribute("aria-label", label);
            fragment.appendChild(button);
        });

        app.activities.forEach(function (activity) {
            var type = typeById(activity.type);
            var done = activity.status === "done";
            var button = document.createElement("button");
            button.type = "button";
            button.className = "fallback-pin activity-pin" + (done ? " done" : "");
            button.setAttribute("data-kind", "activity");
            button.setAttribute("data-id", activity.id);
            var position = fallbackPercent(activity.plot.latitude, activity.plot.longitude);
            button.style.left = position.x + "%";
            button.style.top = position.y + "%";
            button.style.background = type.color;
            var label = activity.title + " \u00B7 " + ROLE_LABELS[activity.role] + " \u00B7 " + type.label;
            button.title = label;
            button.setAttribute("aria-label", label);
            fragment.appendChild(button);
        });

        dom.fallbackPins.innerHTML = "";
        dom.fallbackPins.appendChild(fragment);
        dom.fallbackPins.style.pointerEvents = app.placing ? "none" : "";
    }

    function leafletMarker(key, latitude, longitude, className, html, onClick, label, background) {
        if (!app.leaflet || !app.leafletGroup) return null;
        var icon = L.divIcon({
            className: "leaflet-dhun-icon",
            html: '<div class="' + className + '">' + html + "</div>",
            iconSize: [0, 0],
            iconAnchor: [0, 0]
        });
        var marker = L.marker([Number(latitude), Number(longitude)], {
            icon: icon, keyboard: true, riseOnHover: true, title: label || ""
        });
        if (onClick) {
            marker.on("click", function (event) {
                if (event && event.originalEvent) L.DomEvent.stopPropagation(event.originalEvent);
                onClick();
            });
        }
        if (label) marker.bindTooltip(label, { direction: "top", offset: [0, -14], opacity: 0.95, className: "dhun-tip" });
        marker.addTo(app.leafletGroup);
        if (key) app.leafletMarkers[key] = marker;
        if (background) {
            var inner = marker.getElement() && marker.getElement().querySelector(".gm-activity");
            if (inner) inner.style.background = background;
        }
        return marker;
    }

    function renderLeafletMarkers() {
        if (!app.leaflet || !app.leafletGroup) return;
        app.leafletGroup.clearLayers();
        app.leafletMarkers = {};
        var visible = visibleProduce();

        L.circle([DATA.site.latitude, DATA.site.longitude], {
            radius: 640, stroke: true, color: "#D9EF92", weight: 1.2, opacity: 0.5,
            fill: true, fillColor: "#D9EF92", fillOpacity: 0.035, interactive: false
        }).addTo(app.leafletGroup);

        DATA.zones.forEach(function (zone) {
            var count = visible.filter(function (item) { return item.zone === zone.id; }).length;
            L.circle([zone.latitude, zone.longitude], {
                radius: 145, stroke: true, color: zone.color, weight: 1.2, opacity: 0.75,
                fill: true, fillColor: zone.color, fillOpacity: 0.11, bubblingMouseEvents: false
            }).addTo(app.leafletGroup).on("click", function () { showZoneCard(zone.id); });
            leafletMarker("zone:" + zone.id, zone.latitude, zone.longitude, "gm-zone",
                '<i style="background:' + esc(zone.color) + '"></i>' + esc(zone.short) + " <b>" + count + "</b>",
                function () { showZoneCard(zone.id); }, zone.name);
        });

        leafletMarker("site:dhun", DATA.site.latitude, DATA.site.longitude, "gm-site",
            '<svg><use href="#i-leaf"/></svg>', function () { showSiteCard(); }, "Dhun at " + DATA.site.place);

        visible.forEach(function (item) {
            var marker = leafletMarker("produce:" + item.id, item.plot.latitude, item.plot.longitude,
                "gm-produce" + (inSeasonNow(item) ? "" : " out") + (app.activeProduce === item.id ? " selected" : ""),
                '<img src="' + esc(item.photo) + '" alt="' + esc(item.name) + '">',
                function () { openProduce(item.id); },
                item.name + " \u00B7 " + item.growerName + " \u00B7 " + stockLabel(item));
            if (marker) {
                marker.unbindTooltip();
                marker.bindTooltip(item.name, {
                    permanent: true,
                    direction: "bottom",
                    offset: [0, 6],
                    opacity: 1,
                    className: "dhun-produce-tip",
                    interactive: false
                });
            }
        });

        app.activities.forEach(function (activity) {
            var type = typeById(activity.type);
            leafletMarker("activity:" + activity.id, activity.plot.latitude, activity.plot.longitude,
                "gm-activity" + (activity.status === "done" ? " done" : ""), "",
                function () { showActivityCard(activity.id); },
                activity.title + " \u00B7 " + ROLE_LABELS[activity.role] + " \u00B7 " + type.label,
                type.color);
        });

        if (app.currentPlace) {
            leafletMarker("place", app.currentPlace.latitude, app.currentPlace.longitude, "gm-place",
                '<svg><use href="#i-pin"/></svg>', function () { showPlaceCard(app.currentPlace); },
                app.currentPlace.name);
        }
    }

    function focusCoords(latitude, longitude, zoom) {
        if (app.leaflet) app.leaflet.setView([Number(latitude), Number(longitude)], Number(zoom) || 15);
    }

    function flashPin(kind, id) {
        if (!id) return;
        var pin = dom.fallbackPins.querySelector('[data-kind="' + kind + '"][data-id="' + id + '"]');
        if (pin) {
            pin.classList.add("flash");
            window.setTimeout(function () { pin.classList.remove("flash"); }, 1500);
        }
        var marker = app.leafletMarkers[kind + ":" + id];
        var element = marker && marker.getElement();
        if (!element) return;
        var inner = element.firstChild;
        if (!inner) return;
        inner.classList.add("flash");
        window.setTimeout(function () { inner.classList.remove("flash"); }, 1500);
    }

    function openProduce(id) {
        var item = findProduce(id);
        if (!item) return;
        if (app.season === "current" && !inSeasonNow(item)) {
            app.season = "all";
            syncSeasonSwitch();
        }
        app.activeProduce = id;
        app.currentPlace = null;
        renderDock();
        renderMarkers();
        focusCoords(item.plot.latitude, item.plot.longitude, 16);
        flashPin("produce", id);
        showProduceCard(id);
    }

    function showProduceCard(id) {
        var item = findProduce(id);
        if (!item) return;
        var entry = stockEntry(id);
        var stock = stockOf(id);
        var last = entry.lastOrder;
        var note = last
            ? "Last procurement " + esc(last.reference || "") + " \u00B7 " + esc(Core.timeAgo(last.at, Date.now())) + " \u00B7 " + esc(stock + " " + item.unit + " still in stock")
            : "Stock updated " + esc(Core.timeAgo(entry.updatedAt, Date.now())) + " \u00B7 " + (item.walletOfferId ? "wallet offer " + esc(item.walletOfferId) : "studio inventory");
        showMapCard(
            '<div class="map-card-head">' +
            '<img src="' + esc(item.photo) + '" alt="' + esc(item.name) + ' illustration">' +
            "<div><h4>" + esc(item.name) + " <small>" + esc(item.local) + "</small></h4>" +
            "<p>" + esc(item.growerName) + " \u00B7 " + esc(findZone(item.zone).name) + "</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + esc(stockLabel(item)) + "</span>" +
            '<span class="chip">' + esc(Core.nextHarvestLabel(item, Date.now())) + "</span>" +
            '<span class="chip ghost">' + esc(item.category) + "</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body"><p class="map-card-note">' + esc(item.blurb) + "</p>" +
            '<div class="map-card-row"><div class="map-card-price">' + Core.formatINR(item.price) +
            "<small>/" + esc(item.unit) + "</small></div>" +
            '<button type="button" class="btn btn-ghost" data-act="log">Log work</button>' +
            '<button type="button" class="btn btn-dark" data-act="procure"' + (stock <= 0 ? " disabled" : "") + ">Procure</button></div>" +
            '<p class="map-card-note">' + note + "</p></div>",
            { kind: "produce", id: id }
        );
    }

    function showActivityCard(id) {
        var activity = findActivity(id);
        if (!activity) return;
        var type = typeById(activity.type);
        var zone = findZone(activity.zone);
        var produce = activity.produceId ? findProduce(activity.produceId) : null;
        var meta = [zone ? zone.name : "", produce ? produce.name : ""].filter(Boolean).join(" \u00B7 ");
        var media = activity.media && activity.media.length;
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:' + esc(type.color) + '">' + esc(type.label.charAt(0)) + "</div>" +
            "<div><h4>" + esc(activity.title) + "</h4>" +
            "<p>" + esc(dayLabel(activity.date)) + " \u00B7 " + timeLabel(activity.date) + " \u00B7 " + esc(ROLE_LABELS[activity.role]) + "</p>" +
            '<div class="map-card-meta"><span class="chip' + (activity.status === "done" ? " gold" : " clay") + '">' +
            (activity.status === "done" ? "Done" : "Planned") + "</span>" +
            '<span class="chip ghost">' + esc(type.label) + "</span>" +
            (meta ? '<span class="chip ghost">' + esc(meta) + "</span>" : "") + "</div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body">' +
            (activity.notes ? '<p class="map-card-note">' + esc(activity.notes) + "</p>" : "") +
            '<div class="map-card-row">' +
            '<button type="button" class="btn btn-dark" data-act="toggle">' + (activity.status === "done" ? "Reopen" : "Mark done") + "</button>" +
            '<button type="button" class="btn btn-ghost" data-act="follow-up">Follow-up</button>' +
            (media ? '<button type="button" class="btn btn-ghost" data-act="clip">Clip</button>' : "") +
            "</div></div>",
            { kind: "activity", id: id }
        );
    }

    function showZoneCard(id) {
        var zone = findZone(id);
        if (!zone) return;
        var produce = produceInZone(id);
        var inSeason = produce.filter(inSeasonNow);
        var tasks = zoneActivities(id);
        var list = inSeason.slice(0, 4).map(function (item) { return item.name; }).join(", ");
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:' + esc(zone.color) + '">' + esc(zone.short.charAt(0)) + "</div>" +
            "<div><h4>" + esc(zone.name) + "</h4><p>" + inSeason.length + " in season \u00B7 " + tasks.length + " work items</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + produce.length + " plots</span>" +
            '<span class="chip ghost">' + esc(DATA.site.place) + "</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body"><p class="map-card-note">' + esc(zone.description) + "</p>" +
            (list ? '<p class="map-card-note">In season here: ' + esc(list) + (inSeason.length > 4 ? " and more." : ".") + "</p>" : "") +
            '<div class="map-card-row"><button type="button" class="btn btn-dark" data-act="log-zone">Mark work here</button></div></div>',
            { kind: "zone", id: id }
        );
    }

    function showSiteCard() {
        var inSeason = DATA.produce.filter(inSeasonNow);
        var recent = app.activities.slice().sort(function (a, b) { return Number(b.date) - Number(a.date); }).slice(0, 3);
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:var(--forest);color:var(--lime)"><svg><use href="#i-leaf"/></svg></div>' +
            "<div><h4>Dhun</h4><p>" + esc(DATA.site.place) + " \u00B7 " + DATA.site.acres + " acres</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + DATA.zones.length + " zones</span>" +
            '<span class="chip">' + inSeason.length + " in season</span>" +
            '<span class="chip ghost">' + DATA.site.latitude.toFixed(4) + ", " + DATA.site.longitude.toFixed(4) + "</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body"><p class="map-card-note">The wallet\u2019s field edge. Funder, Dhun and stewards share one treasury; every release needs a second signature.</p>' +
            '<p class="map-card-note">' + recent.map(function (activity) {
                return esc(dayLabel(activity.date)) + " \u00B7 " + esc(ROLE_LABELS[activity.role]) + " \u00B7 " + esc(activity.title);
            }).join("<br>") + "</p>" +
            '<div class="map-card-row"><button type="button" class="btn btn-dark" data-act="log-site">Mark activity</button></div></div>',
            { kind: "site" }
        );
    }

    function showGrowerCard(id) {
        var grower = findGrower(id);
        if (!grower) return;
        var produce = produceForGrower(id);
        var stock = produce.reduce(function (total, item) { return total + stockOf(item.id); }, 0);
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:var(--forest-mid);color:var(--lime)">' + esc(grower.short.charAt(0)) + "</div>" +
            "<div><h4>" + esc(grower.name) + "</h4><p>" + esc(grower.village) + " \u00B7 " + esc(ROLE_LABELS[grower.role]) + " partner</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + produce.length + " plots</span>" +
            '<span class="chip">' + stock + " units in stock</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body"><p class="map-card-note">' + esc(grower.note) + "</p>" +
            '<p class="map-card-note">' + produce.slice(0, 6).map(function (item) { return esc(item.name); }).join(", ") +
            (produce.length > 6 ? " and more." : ".") + "</p></div>",
            { kind: "grower", id: id }
        );
    }

    function showPlaceCard(place) {
        var km = distanceKm(place, DATA.site);
        var close = km <= MAX_ACTIVITY_KM;
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:#3D7EDB;color:#fff"><svg><use href="#i-pin"/></svg></div>' +
            "<div><h4>" + esc(place.name) + "</h4><p>" + esc(place.address || "Map place") + "</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + km.toFixed(1) + " km from Dhun</span>" +
            '<span class="chip ghost">' + Number(place.latitude).toFixed(5) + ", " + Number(place.longitude).toFixed(5) + "</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body">' +
            '<p class="map-card-note">' + (close ? "This place is within the field radius, so you can log work here." :
                "This place is outside the 8 km field radius. Browse it, but field work is logged closer to Dhun.") + "</p>" +
            '<div class="map-card-row"><button type="button" class="btn btn-ghost" data-act="clear-place">Clear pin</button>' +
            '<button type="button" class="btn btn-dark" data-act="log-place"' + (close ? "" : " disabled") + ">Log work here</button></div></div>",
            { kind: "place", id: "" }
        );
    }

    function showPointCard(point) {
        var km = distanceKm(point, DATA.site);
        var close = km <= MAX_ACTIVITY_KM;
        showMapCard(
            '<div class="map-card-head">' +
            '<div class="activity-glyph" style="background:var(--forest-mid);color:var(--lime)"><svg><use href="#i-crosshair"/></svg></div>' +
            "<div><h4>Dropped pin</h4><p>" + Number(point.latitude).toFixed(5) + ", " + Number(point.longitude).toFixed(5) + "</p>" +
            '<div class="map-card-meta"><span class="chip gold">' + km.toFixed(1) + " km from Dhun</span></div></div>" +
            '<button type="button" class="map-card-close" data-act="close" aria-label="Close"><svg><use href="#i-close"/></svg></button>' +
            "</div>" +
            '<div class="map-card-body"><p class="map-card-note">' +
            (close ? "Mark field work at this point, or click another spot." : "Field work must be within 8 km of Dhun.") + "</p>" +
            '<div class="map-card-row"><button type="button" class="btn btn-dark" data-act="log-point"' + (close ? "" : " disabled") + ">Log work here</button></div></div>",
            { kind: "point", point: point }
        );
    }

    function openGrower(id) {
        var grower = findGrower(id);
        if (!grower) return;
        app.activeProduce = null;
        app.currentPlace = null;
        hideMapCard();
        renderDock();
        renderMarkers();
        focusCoords(grower.latitude, grower.longitude, 15);
        showGrowerCard(id);
    }

    function openZone(id) {
        var zone = findZone(id);
        if (!zone) return;
        app.activeProduce = null;
        hideMapCard();
        renderDock();
        renderMarkers();
        focusCoords(zone.latitude, zone.longitude, 15);
        showZoneCard(id);
    }

    function openSite() {
        app.activeProduce = null;
        app.currentPlace = null;
        hideMapCard();
        renderDock();
        renderMarkers();
        focusCoords(DATA.site.latitude, DATA.site.longitude, 15);
        showSiteCard();
    }

    function focusActivity(id) {
        var activity = findActivity(id);
        if (!activity) return;
        app.selectedDate = startOfDay(activity.date);
        app.viewYear = new Date(activity.date).getFullYear();
        app.viewMonth = new Date(activity.date).getMonth();
        renderCalendar();
        renderAgenda();
        app.activeProduce = null;
        renderDock();
        focusCoords(activity.plot.latitude, activity.plot.longitude, 16);
        flashPin("activity", id);
        showActivityCard(id);
    }

    function closePlace() {
        app.currentPlace = null;
        hideMapCard();
        renderMarkers();
        toast("Place pin cleared.");
    }

    function syncSeasonSwitch() {
        dom.seasonSwitch.querySelectorAll("[data-season]").forEach(function (button) {
            button.classList.toggle("active", button.getAttribute("data-season") === app.season);
        });
    }

    function toggleActivity(id) {
        var activity = findActivity(id);
        if (!activity) return;
        activity.status = activity.status === "done" ? "planned" : "done";
        persist();
        renderCalendar();
        renderAgenda();
        renderMarkers();
        renderDock();
        showActivityCard(id);
        emit("activity-status", { id: id, status: activity.status });
        toast(activity.status === "done" ? "Marked done." : "Reopened.");
    }

    function openOrder(id) {
        var item = findProduce(id);
        if (!item) return;
        var stock = stockOf(id);
        if (stock <= 0) {
            toast(inSeasonNow(item) ? "This plot is sold out." : "This produce is out of season.", true);
            return;
        }
        app.order = { id: id, qty: 1 };
        $("orderPhoto").src = item.photo;
        $("orderPhoto").alt = item.name + " illustration";
        $("orderName").textContent = item.name + " \u00B7 " + item.local;
        $("orderMeta").textContent = item.growerName + " \u00B7 " + findZone(item.zone).name + " \u00B7 " + item.harvestLabel;
        $("orderGrower").textContent = (item.walletOfferId ? "Wallet offer " + item.walletOfferId : "Not yet listed as a wallet offer") +
            " \u00B7 updated " + Core.timeAgo(stockEntry(id).updatedAt, Date.now());
        $("orderQty").value = "1";
        $("orderQty").max = String(stock);
        $("orderUnitLabel").textContent = item.unit;
        $("orderError").classList.add("hidden");
        $("orderOfferBtn").classList.toggle("hidden", !embedded || !item.walletOfferId);
        $("orderOfferBtn").disabled = !item.walletOfferId;
        $("orderSubmit").classList.toggle("hidden", embedded);
        $("orderNote").textContent = embedded
            ? (item.walletOfferId
                ? "This opens the wallet purchase sheet. Stock here falls once the purchase is confirmed."
                : "This plot has no linked wallet offer yet. Add it in Market before procuring.")
            : "Records a local rehearsal procurement. No payment is taken here; open the studio inside the wallet to pay from the treasury." +
              (item.walletOfferId ? " Wallet offer " + item.walletOfferId + " is already listed." : "");
        updateOrderTotals();
        openModal("orderModal");
        var qtyInput = $("orderQty");
        window.setTimeout(function () { qtyInput.focus(); qtyInput.select(); }, 40);
    }

    function updateOrderTotals() {
        if (!app.order) return;
        var item = findProduce(app.order.id);
        if (!item) return;
        var stock = stockOf(item.id);
        var qty = clampNumber(app.order.qty, 1, Math.max(1, stock));
        app.order.qty = qty;
        $("orderQty").value = String(qty);
        $("orderStock").textContent = stock + " " + item.unit;
        $("orderPrice").textContent = Core.formatINR(item.price) + "/" + item.unit;
        $("orderTotal").textContent = Core.formatINR(item.price * qty);
    }

    function adjustOrderQty(delta) {
        if (!app.order) return;
        app.order.qty = clampNumber((Number(app.order.qty) || 1) + delta, 1, Math.max(1, stockOf(app.order.id)));
        updateOrderTotals();
    }

    function submitStandaloneOrder() {
        if (!app.order) return;
        var item = findProduce(app.order.id);
        if (!item) return;
        var entry = stockEntry(item.id);
        var result = Core.applyOrder({ stock: entry.stock, updatedAt: entry.updatedAt }, item.id, app.order.qty, Date.now());
        if (!result.ok) {
            $("orderError").textContent = result.error;
            $("orderError").classList.remove("hidden");
            return;
        }
        app.inventory[item.id] = {
            stock: result.inventory.stock,
            updatedAt: result.inventory.updatedAt,
            lastOrder: result.inventory.lastOrder
        };
        persist();
        var qty = app.order.qty;
        var reference = result.reference;
        closeModal("orderModal");
        app.order = null;
        renderDock();
        renderMarkers();
        if (app.activeCard && app.activeCard.kind === "produce" && app.activeCard.id === item.id) showProduceCard(item.id);
        toast("Procured " + qty + " " + item.unit + " " + item.name + " \u00B7 " + reference);
    }

    function requestWalletOffer() {
        if (!app.order) return;
        var item = findProduce(app.order.id);
        if (!item || !item.walletOfferId) return;
        var qty = app.order.qty;
        emit("open-offer", {
            produceId: item.id,
            offerId: item.walletOfferId,
            qty: qty,
            unit: item.unit,
            price: item.price,
            total: item.price * qty
        });
        closeModal("orderModal");
        app.order = null;
        toast("Opening " + item.walletOfferId + " in the wallet purchase sheet.");
    }

    function recordOrder(produceId, quantity, reference, offerId) {
        var item = findProduce(produceId);
        if (!item) return false;
        var qty = clampNumber(Math.floor(Number(quantity) || 0), 1, 100000);
        var entry = stockEntry(produceId);
        var remaining = Math.max(0, Number(entry.stock) - qty);
        app.inventory[produceId] = {
            stock: remaining,
            updatedAt: Date.now(),
            lastOrder: {
                produceId: produceId,
                qty: qty,
                at: Date.now(),
                reference: String(reference || ""),
                offerId: String(offerId || item.walletOfferId || "")
            }
        };
        persist();
        renderDock();
        renderMarkers();
        if (app.activeCard && app.activeCard.kind === "produce" && app.activeCard.id === produceId) showProduceCard(produceId);
        toast("Wallet order recorded: " + qty + " " + item.unit + " " + item.name +
            (reference ? " \u00B7 " + reference : "") + " \u00B7 " + remaining + " left");
        return true;
    }

    function syncInventory(entries) {
        if (!Array.isArray(entries)) return 0;
        var changed = 0;
        entries.forEach(function (entry) {
            if (!entry || !entry.produceId || !findProduce(entry.produceId)) return;
            var stock = Number(entry.stock);
            if (!isFinite(stock)) return;
            var current = app.inventory[entry.produceId] || stockEntry(entry.produceId);
            app.inventory[entry.produceId] = {
                stock: Math.max(0, Math.floor(stock)),
                updatedAt: Number(entry.updatedAt) || Date.now(),
                lastOrder: current.lastOrder || null
            };
            changed += 1;
        });
        if (changed) {
            persist();
            renderDock();
            renderMarkers();
            if (app.activeCard && app.activeCard.kind === "produce") showProduceCard(app.activeCard.id);
        }
        return changed;
    }

    function normalizeBridgeActivity(raw) {
        if (!raw || !raw.id) return null;
        var produce = raw.produceId ? findProduce(raw.produceId) : null;
        var zone = findZone(raw.zone) || findZone("farms");
        var plot = raw.plot && isFinite(Number(raw.plot.latitude)) && isFinite(Number(raw.plot.longitude))
            ? { latitude: Number(raw.plot.latitude), longitude: Number(raw.plot.longitude) }
            : (produce
                ? { latitude: Number(produce.plot.latitude), longitude: Number(produce.plot.longitude) }
                : { latitude: zone.latitude + 0.00035, longitude: zone.longitude + 0.00035 });
        return {
            id: String(raw.id),
            role: ROLE_LABELS[raw.role] ? raw.role : "dhun",
            type: typeById(raw.type).id,
            title: String(raw.title || "Field work"),
            produceId: produce ? produce.id : "",
            zone: zone.id,
            date: Number(raw.date) || Date.now(),
            status: raw.status === "done" ? "done" : "planned",
            notes: String(raw.notes || ""),
            visibility: raw.visibility || "room",
            source: raw.source || "wallet",
            media: Array.isArray(raw.media) ? raw.media.slice(0, 8) : [],
            plot: plot
        };
    }

    function syncActivities(list) {
        if (!Array.isArray(list)) return 0;
        var incoming = list.map(normalizeBridgeActivity).filter(Boolean);
        if (!incoming.length) return 0;
        var index = {};
        app.activities.forEach(function (activity, position) { index[activity.id] = position; });
        var changed = 0;
        incoming.forEach(function (activity) {
            var position = index[activity.id];
            if (position === undefined) {
                app.activities.push(activity);
                index[activity.id] = app.activities.length - 1;
                changed += 1;
                return;
            }
            var current = app.activities[position];
            ["role", "type", "title", "produceId", "zone", "date", "status", "notes", "visibility", "source", "plot"].forEach(function (key) {
                current[key] = activity[key];
            });
            if (activity.media.length) current.media = activity.media;
            changed += 1;
        });
        if (changed) {
            var selected = app.activities.filter(function (activity) {
                return Core.dateKey(activity.date) === Core.dateKey(app.selectedDate);
            });
            if (selected.length) {
                app.viewYear = new Date(selected[0].date).getFullYear();
                app.viewMonth = new Date(selected[0].date).getMonth();
            }
            persist();
            renderCalendar();
            renderAgenda();
            renderUpdateCount();
            renderMarkers();
        }
        return changed;
    }

    function setActivityStatus(id, status) {
        var found = null;
        app.activities.forEach(function (activity) { if (activity.id === id) found = activity; });
        if (!found) return false;
        found.status = status === "done" ? "done" : "planned";
        persist();
        renderCalendar();
        renderAgenda();
        renderMarkers();
        return true;
    }

    function resetStudioSchedule() {
        try { window.localStorage.removeItem(STORAGE_KEY); } catch (error) { /* ignore */ }
        toast("Studio schedule cleared. Reloading from the wallet\u2026");
        window.setTimeout(function () { window.location.reload(); }, 250);
    }

    function populateSelects() {
        var zoneOptions = DATA.zones.map(function (zone) {
            return '<option value="' + esc(zone.id) + '">' + esc(zone.name) + "</option>";
        }).join("");
        dom.activityZone.innerHTML = zoneOptions;
        dom.videoZone.innerHTML = zoneOptions;
        dom.activityRole.innerHTML = Object.keys(ROLE_LABELS).map(function (role) {
            return '<option value="' + esc(role) + '">' + esc(ROLE_LABELS[role]) + "</option>";
        }).join("");
        var categories = [];
        DATA.produce.forEach(function (item) {
            if (categories.indexOf(item.category) === -1) categories.push(item.category);
        });
        var produceOptions = "";
        categories.forEach(function (category) {
            produceOptions += '<optgroup label="' + esc(category) + '">';
            DATA.produce.filter(function (item) { return item.category === category; }).forEach(function (item) {
                produceOptions += '<option value="' + esc(item.id) + '">' + esc(item.name) + " \u00B7 " + esc(item.local) + "</option>";
            });
            produceOptions += "</optgroup>";
        });
        dom.activityProduce.innerHTML = '<option value="">No specific produce</option>' + produceOptions;
        dom.videoProduce.innerHTML = '<option value="">No specific produce</option>' + produceOptions;
    }

    function populateTypePicker(activeType) {
        dom.activityTypes.innerHTML = DATA.activityTypes.map(function (type) {
            return '<button type="button" class="type-chip' + (type.id === activeType ? " active" : "") +
                '" data-type="' + esc(type.id) + '" title="' + esc(type.hint) + '">' +
                '<i style="background:' + esc(type.color) + '"></i>' + esc(type.label) + "</button>";
        }).join("");
    }

    function openActivityModal(options) {
        var opts = options || {};
        var produce = opts.produceId ? findProduce(opts.produceId) : null;
        var zoneId = opts.zone || (produce ? produce.zone : "farms");
        var baseDate = new Date(Number(opts.date) || app.selectedDate);
        if (baseDate.getHours() === 0 && baseDate.getMinutes() === 0) baseDate.setHours(8, 0, 0, 0);
        app.draft = {
            title: opts.title || "",
            type: opts.type || "sowing",
            zone: zoneId,
            produceId: opts.produceId || "",
            role: opts.role || app.role,
            visibility: "room",
            notes: "",
            point: opts.point || null,
            date: baseDate.getTime()
        };
        app.placing = false;
        app.placingReturn = false;
        dom.placementHint.classList.add("hidden");
        dom.mapPanel.classList.remove("placing");
        syncActivityForm();
        dom.activityError.classList.add("hidden");
        var minDate = new Date();
        minDate.setFullYear(minDate.getFullYear() - 1);
        var maxDate = new Date();
        maxDate.setFullYear(maxDate.getFullYear() + 1);
        dom.activityDate.min = dateInputValue(minDate.getTime());
        dom.activityDate.max = dateInputValue(maxDate.getTime());
        openModal("activityModal");
        window.setTimeout(function () { dom.activityTitle.focus(); }, 60);
    }

    function syncActivityForm() {
        if (!app.draft) return;
        dom.activityTitle.value = app.draft.title || "";
        dom.activityZone.value = app.draft.zone || "farms";
        dom.activityProduce.value = app.draft.produceId || "";
        dom.activityRole.value = app.draft.role || app.role;
        dom.activityDate.value = dateInputValue(app.draft.date || app.selectedDate);
        dom.activityTime.value = timeInputValue(app.draft.date || Date.now());
        dom.activityVisibility.value = app.draft.visibility || "room";
        dom.activityNotes.value = app.draft.notes || "";
        populateTypePicker(app.draft.type || "sowing");
        updateActivityLocationLabel();
    }

    function updateActivityLocationLabel() {
        if (!app.draft) return;
        if (app.draft.point) {
            dom.activityLocation.textContent = "Pinned on map \u00B7 " +
                Number(app.draft.point.latitude).toFixed(5) + ", " + Number(app.draft.point.longitude).toFixed(5);
        } else {
            var zone = findZone(app.draft.zone);
            dom.activityLocation.textContent = "Location: " + (zone ? zone.name : "field centre") + " \u00B7 pick on map to be exact";
        }
    }

    function readActivityForm() {
        if (!app.draft) app.draft = {};
        var activeChip = dom.activityTypes.querySelector(".type-chip.active");
        app.draft.title = dom.activityTitle.value.trim();
        app.draft.type = activeChip ? activeChip.getAttribute("data-type") : (app.draft.type || "sowing");
        app.draft.zone = dom.activityZone.value;
        app.draft.produceId = dom.activityProduce.value;
        app.draft.role = dom.activityRole.value;
        app.draft.visibility = dom.activityVisibility.value;
        app.draft.notes = dom.activityNotes.value.trim();
        app.draft.date = combineDateAndTime(dom.activityDate.value, dom.activityTime.value);
        return app.draft;
    }

    function beginPlacement() {
        if (!app.draft) return;
        app.placing = true;
        app.placingReturn = true;
        dom.placementHint.classList.remove("hidden");
        dom.mapPanel.classList.add("placing");
        if (dom.fallbackPins) dom.fallbackPins.style.pointerEvents = "none";
        toast("Tap the map to place this activity.");
    }

    function finishPlacement(latitude, longitude) {
        if (!app.draft) {
            app.placing = false;
            return;
        }
        app.draft.point = { latitude: Number(latitude), longitude: Number(longitude) };
        app.placing = false;
        app.placingReturn = false;
        dom.placementHint.classList.add("hidden");
        dom.mapPanel.classList.remove("placing");
        if (dom.fallbackPins) dom.fallbackPins.style.pointerEvents = "";
        openModal("activityModal");
        syncActivityForm();
        dom.activityError.classList.add("hidden");
    }

    function cancelPlacement(reopen) {
        app.placing = false;
        var shouldReopen = reopen !== false && app.placingReturn;
        app.placingReturn = false;
        dom.placementHint.classList.add("hidden");
        dom.mapPanel.classList.remove("placing");
        if (dom.fallbackPins) dom.fallbackPins.style.pointerEvents = "";
        if (shouldReopen) {
            openModal("activityModal");
            syncActivityForm();
        }
    }

    function submitActivity(event) {
        if (event) event.preventDefault();
        var draft = readActivityForm();
        var produce = draft.produceId ? findProduce(draft.produceId) : null;
        var zone = findZone(draft.zone);
        var check = Core.validateActivity({
            title: draft.title,
            type: draft.type,
            zone: draft.zone,
            date: draft.date,
            notes: draft.notes,
            role: draft.role
        }, Date.now());
        if (!check.ok) {
            dom.activityError.textContent = check.errors[0];
            dom.activityError.classList.remove("hidden");
            return;
        }
        var plot = draft.point || (produce ? produce.plot : {
            latitude: zone.latitude + 0.00035,
            longitude: zone.longitude + 0.00035
        });
        if (distanceKm(plot, DATA.site) > MAX_ACTIVITY_KM) {
            dom.activityError.textContent = "Field work must be within 8 km of Dhun. Pick a closer point.";
            dom.activityError.classList.remove("hidden");
            return;
        }
        var activity = {
            id: nextId("FLD", app.activities),
            role: draft.role,
            type: draft.type,
            title: check.title,
            produceId: draft.produceId || "",
            zone: draft.zone,
            date: draft.date,
            status: "planned",
            notes: draft.notes,
            visibility: draft.visibility,
            source: "studio",
            media: [],
            plot: { latitude: Number(plot.latitude), longitude: Number(plot.longitude) }
        };
        app.activities.push(activity);
        app.selectedDate = startOfDay(activity.date);
        app.viewYear = new Date(activity.date).getFullYear();
        app.viewMonth = new Date(activity.date).getMonth();
        persist();
        closeModal("activityModal");
        renderCalendar();
        renderAgenda();
        renderMarkers();
        emit("activity", { activity: activity });
        toast("Added to the " + ROLE_LABELS[activity.role] + " calendar" +
            (draft.role !== app.role ? " \u00B7 switch role to view" : ""));
    }

    function openVideoModal() {
        resetVideoSession();
        dom.videoTitle.value = "";
        dom.videoNotes.value = "";
        dom.videoDate.value = dateInputValue(app.selectedDate);
        dom.videoTime.value = "08:00";
        dom.videoProduce.value = "";
        dom.videoZone.value = "farms";
        dom.videoError.classList.add("hidden");
        dom.videoShareHint.textContent = embedded
            ? "Posts the note to the wallet room; the clip stays in this studio."
            : "Posts to the local studio feed.";
        configureVideoCapabilities();
        openModal("videoModal");
    }

    function configureVideoCapabilities() {
        var hasCamera = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
        var hasRecorder = typeof window.MediaRecorder !== "undefined";
        dom.startCamera.classList.toggle("hidden", !hasCamera);
        dom.toggleRecord.classList.add("hidden");
        if (!hasCamera) {
            dom.cameraStatus.textContent = "Camera capture is not available in this view. Attach a clip instead.";
        } else if (!hasRecorder) {
            dom.cameraStatus.textContent = "Live recording is not supported here. Start the camera to preview, or attach a clip.";
        } else {
            dom.cameraStatus.textContent = "Camera access is requested only when you start it.";
        }
        dom.cameraStatus.classList.remove("error");
        dom.maxVideoLabel.textContent = String(MAX_VIDEO_SECONDS);
    }

    function setButtonLabel(button, icon, text) {
        button.innerHTML = '<svg><use href="#i-' + icon + '"/></svg>' + esc(text);
    }

    function setPendingMedia(blob, source) {
        if (!blob) return;
        if (blob.size > MAX_VIDEO_BYTES) {
            videoError("That clip is larger than 40 MB. Trim it or record a shorter one.");
            return;
        }
        stopStreamTracks();
        if (app.video.pendingUrl) URL.revokeObjectURL(app.video.pendingUrl);
        app.video.pending = { blob: blob, mime: blob.type || "video/mp4", size: blob.size, source: source || "Clip" };
        app.video.pendingUrl = URL.createObjectURL(blob);
        dom.videoPreview.srcObject = null;
        dom.videoPreview.src = app.video.pendingUrl;
        dom.videoPreview.muted = false;
        dom.videoPreview.controls = true;
        dom.videoPreview.play().catch(function () {});
        dom.videoEmpty.classList.add("hidden");
        dom.recordTimer.classList.add("hidden");
        dom.toggleRecord.classList.add("hidden");
        setButtonLabel(dom.startCamera, "camera", "Retake");
        dom.startCamera.classList.toggle("hidden", !(navigator.mediaDevices && navigator.mediaDevices.getUserMedia));
        dom.cameraStatus.textContent = (source || "Clip") + " \u00B7 " + formatBytes(blob.size) + " \u00B7 ready to post.";
        dom.cameraStatus.classList.remove("error");
    }

    function stopStreamTracks() {
        if (app.video.stream) {
            app.video.stream.getTracks().forEach(function (track) { track.stop(); });
            app.video.stream = null;
        }
        dom.videoPreview.srcObject = null;
    }

    function resetVideoSession() {
        app.video.session += 1;
        if (app.video.timer) {
            window.clearInterval(app.video.timer);
            app.video.timer = null;
        }
        if (app.video.recorder && app.video.recorder.state !== "inactive") {
            try { app.video.recorder.stop(); } catch (error) { /* already stopped */ }
        }
        app.video.recorder = null;
        stopStreamTracks();
        if (app.video.pendingUrl) URL.revokeObjectURL(app.video.pendingUrl);
        app.video.pendingUrl = "";
        app.video.pending = null;
        app.video.chunks = [];
        dom.videoPreview.pause();
        dom.videoPreview.removeAttribute("src");
        dom.videoPreview.srcObject = null;
        dom.videoPreview.controls = false;
        dom.videoPreview.muted = true;
        dom.videoPreview.load();
        dom.videoEmpty.classList.remove("hidden");
        dom.recordTimer.classList.add("hidden");
        dom.toggleRecord.classList.add("hidden");
        setButtonLabel(dom.startCamera, "camera", "Start camera");
        dom.videoFile.value = "";
        dom.videoError.classList.add("hidden");
        dom.cameraStatus.classList.remove("error");
        dom.cameraStatus.textContent = "Camera access is requested only when you start it.";
    }

    function cameraErrorMessage(error) {
        var name = error && error.name ? error.name : "";
        if (name === "NotAllowedError" || name === "SecurityError") return "Camera permission was denied. Allow camera access or attach a clip instead.";
        if (name === "NotFoundError" || name === "OverconstrainedError") return "No camera was found. Attach a clip instead.";
        if (name === "NotReadableError") return "The camera is busy in another app. Attach a clip instead.";
        return "The camera could not start in this view. Attach a clip instead.";
    }

    function startCamera() {
        if (app.video.pending) {
            resetVideoSession();
            configureVideoCapabilities();
            startCamera();
            return;
        }
        if (app.video.stream) {
            if (app.video.recorder && app.video.recorder.state === "recording") {
                try { app.video.recorder.stop(); } catch (error) { /* already stopped */ }
            }
            stopStreamTracks();
            setButtonLabel(dom.startCamera, "camera", "Start camera");
            dom.toggleRecord.classList.add("hidden");
            dom.cameraStatus.textContent = "Camera stopped.";
            return;
        }
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            dom.cameraStatus.textContent = "Camera capture is not available here. Attach a clip instead.";
            dom.cameraStatus.classList.add("error");
            return;
        }
        var session = app.video.session;
        var settled = false;
        dom.cameraStatus.textContent = "Requesting camera permission\u2026";
        dom.cameraStatus.classList.remove("error");
        var requestTimer = window.setTimeout(function () {
            if (settled || session !== app.video.session || app.video.stream) return;
            dom.cameraStatus.textContent = "The camera did not respond. Allow access in this view, or attach a clip instead.";
            dom.cameraStatus.classList.add("error");
        }, 15000);
        navigator.mediaDevices.getUserMedia({
            video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } },
            audio: true
        }).then(function (stream) {
            settled = true;
            window.clearTimeout(requestTimer);
            if (session !== app.video.session) {
                stream.getTracks().forEach(function (track) { track.stop(); });
                return;
            }
            app.video.stream = stream;
            dom.videoPreview.srcObject = stream;
            dom.videoPreview.muted = true;
            dom.videoPreview.controls = false;
            dom.videoPreview.play().catch(function () {});
            dom.videoEmpty.classList.add("hidden");
            setButtonLabel(dom.startCamera, "camera", "Stop camera");
            if (typeof window.MediaRecorder !== "undefined") {
                dom.toggleRecord.classList.remove("hidden");
                setRecordButton(false);
            }
            dom.cameraStatus.textContent = "Camera on. Clips stay on this device.";
        }).catch(function (error) {
            settled = true;
            window.clearTimeout(requestTimer);
            if (session !== app.video.session) return;
            dom.cameraStatus.textContent = cameraErrorMessage(error);
            dom.cameraStatus.classList.add("error");
        });
    }

    function setRecordButton(recording) {
        dom.toggleRecord.innerHTML = '<span class="rec-dot"></span>' + (recording ? "Stop recording" : "Start recording");
    }

    function pickRecorderMime() {
        var candidates = ["video/mp4;codecs=h264,aac", "video/mp4", "video/webm;codecs=vp9,opus", "video/webm;codecs=vp8,opus", "video/webm"];
        for (var i = 0; i < candidates.length; ++i) {
            if (window.MediaRecorder && window.MediaRecorder.isTypeSupported && window.MediaRecorder.isTypeSupported(candidates[i])) return candidates[i];
        }
        return "";
    }

    function toggleRecording() {
        if (!app.video.stream) return;
        if (app.video.recorder && app.video.recorder.state === "recording") {
            stopRecording();
            return;
        }
        var session = app.video.session;
        var mime = pickRecorderMime();
        var recorder;
        try {
            recorder = mime ? new MediaRecorder(app.video.stream, { mimeType: mime }) : new MediaRecorder(app.video.stream);
        } catch (error) {
            videoError("Recording is not available here. Attach a clip instead.");
            return;
        }
        app.video.chunks = [];
        app.video.recorder = recorder;
        recorder.ondataavailable = function (event) {
            if (event.data && event.data.size > 0) app.video.chunks.push(event.data);
        };
        recorder.onstop = function () {
            if (session !== app.video.session) return;
            var type = recorder.mimeType || mime || "video/mp4";
            var blob = new Blob(app.video.chunks, { type: type });
            app.video.recorder = null;
            if (app.video.timer) {
                window.clearInterval(app.video.timer);
                app.video.timer = null;
            }
            dom.recordTimer.classList.add("hidden");
            if (!blob.size) {
                videoError("The recording came back empty. Try again or attach a clip.");
                return;
            }
            setPendingMedia(blob, "Recorded clip");
        };
        try { recorder.start(250); }
        catch (error) {
            videoError("The recording could not start. Attach a clip instead.");
            return;
        }
        app.video.startedAt = Date.now();
        dom.recordTimer.textContent = "00:00";
        dom.recordTimer.classList.remove("hidden");
        dom.toggleRecord.classList.remove("hidden");
        setRecordButton(true);
        dom.cameraStatus.textContent = "Recording\u2026 up to " + MAX_VIDEO_SECONDS + " seconds.";
        if (app.video.timer) window.clearInterval(app.video.timer);
        app.video.timer = window.setInterval(function () {
            var elapsed = (Date.now() - app.video.startedAt) / 1000;
            dom.recordTimer.textContent = String(Math.floor(elapsed / 60)).padStart(2, "0") + ":" + String(Math.floor(elapsed % 60)).padStart(2, "0");
            if (elapsed >= MAX_VIDEO_SECONDS) stopRecording();
        }, 200);
    }

    function stopRecording() {
        if (!app.video.recorder || app.video.recorder.state === "inactive") return;
        app.video.recorder.stop();
        dom.toggleRecord.classList.add("hidden");
        stopStreamTracks();
        if (app.video.timer) {
            window.clearInterval(app.video.timer);
            app.video.timer = null;
        }
        dom.cameraStatus.textContent = "Finishing the clip\u2026";
    }

    function attachFile(file) {
        if (!file) return;
        if (!String(file.type || "").startsWith("video/")) {
            videoError("Choose a video file.");
            return;
        }
        if (file.size > MAX_VIDEO_BYTES) {
            videoError("That clip is larger than 40 MB. Trim it or choose a shorter clip.");
            return;
        }
        resetVideoSession();
        configureVideoCapabilities();
        setPendingMedia(file, "Attached clip \u00B7 " + file.name);
    }

    function videoError(message) {
        dom.videoError.textContent = message;
        dom.videoError.classList.remove("hidden");
    }

    function openMediaDB() {
        if (!("indexedDB" in window)) return Promise.reject(new Error("IndexedDB unavailable"));
        if (app.mediaDBPromise) return app.mediaDBPromise;
        app.mediaDBPromise = new Promise(function (resolve, reject) {
            var request = window.indexedDB.open("dhun-studio-media", 1);
            request.onupgradeneeded = function () {
                var database = request.result;
                if (!database.objectStoreNames.contains("media")) database.createObjectStore("media");
            };
            request.onsuccess = function () { resolve(request.result); };
            request.onerror = function () { reject(request.error || new Error("IndexedDB failed")); };
        });
        return app.mediaDBPromise;
    }

    function storeMedia(id, blob) {
        if (!("indexedDB" in window)) {
            app.memoryMedia[id] = blob;
            return Promise.resolve();
        }
        return openMediaDB().then(function (database) {
            return new Promise(function (resolve, reject) {
                var transaction = database.transaction("media", "readwrite");
                transaction.objectStore("media").put({ blob: blob, at: Date.now() }, id);
                transaction.oncomplete = function () { resolve(); };
                transaction.onerror = function () { reject(transaction.error || new Error("Could not store clip")); };
                transaction.onabort = function () { reject(transaction.error || new Error("Could not store clip")); };
            });
        }).catch(function () {
            app.memoryMedia[id] = blob;
        });
    }

    function readMedia(id) {
        if (app.memoryMedia[id]) return Promise.resolve(app.memoryMedia[id]);
        if (!("indexedDB" in window)) return Promise.resolve(null);
        return openMediaDB().then(function (database) {
            return new Promise(function (resolve, reject) {
                var transaction = database.transaction("media", "readonly");
                var request = transaction.objectStore("media").get(id);
                request.onsuccess = function () {
                    resolve(request.result && request.result.blob ? request.result.blob : null);
                };
                request.onerror = function () { reject(request.error || new Error("Could not read clip")); };
            });
        }).catch(function () { return null; });
    }

    function mediaUrl(id) {
        if (!id) return Promise.resolve("");
        if (app.mediaURLs[id]) return Promise.resolve(app.mediaURLs[id]);
        return readMedia(id).then(function (blob) {
            if (!blob) return "";
            var url = URL.createObjectURL(blob);
            app.mediaURLs[id] = url;
            return url;
        });
    }

    function postVideoUpdate(event) {
        if (event) event.preventDefault();
        dom.videoError.classList.add("hidden");
        var title = dom.videoTitle.value.trim();
        if (title.length < 3) {
            videoError("Give the update a short title.");
            return;
        }
        if (!app.video.pending) {
            videoError("Record or attach a clip before posting.");
            return;
        }
        var notes = dom.videoNotes.value.trim();
        var produceId = dom.videoProduce.value;
        var zoneId = dom.videoZone.value || "farms";
        var dateValue = dom.videoDate.value;
        var timestamp = 0;
        if (dateValue) {
            timestamp = combineDateAndTime(dateValue, dom.videoTime.value);
            if (!timestamp) {
                videoError("That calendar date is not valid.");
                return;
            }
            if (Math.abs(timestamp - Date.now()) > 366 * 86400000) {
                videoError("The calendar date must be within a year.");
                return;
            }
        }
        var mediaId = "MED-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1296).toString(36);
        var blob = app.video.pending.blob;
        var updateId = nextId("UPD", app.updates);
        var activity = null;
        var produce = produceId ? findProduce(produceId) : null;
        var zone = findZone(zoneId);
        if (timestamp) {
            var plot = produce ? produce.plot : { latitude: zone.latitude + 0.00035, longitude: zone.longitude + 0.00035 };
            activity = {
                id: nextId("FLD", app.activities),
                role: app.role,
                type: "review",
                title: title,
                produceId: produceId || "",
                zone: zoneId,
                date: timestamp,
                status: "done",
                notes: notes,
                visibility: "room",
                source: "video",
                media: [mediaId],
                plot: { latitude: Number(plot.latitude), longitude: Number(plot.longitude) }
            };
        }
        var update = {
            id: updateId,
            role: app.role,
            kind: "video",
            title: title,
            text: notes,
            produceId: produceId || "",
            zone: zoneId,
            at: Date.now(),
            shared: true,
            mediaId: mediaId,
            mediaMime: app.video.pending.mime,
            mediaSize: app.video.pending.size,
            activityId: activity ? activity.id : ""
        };
        var submit = dom.videoForm.querySelector('button[type="submit"]');
        if (submit) submit.disabled = true;
        storeMedia(mediaId, blob).then(function () {
            app.updates.push(update);
            if (activity) app.activities.push(activity);
            if (activity) {
                app.selectedDate = startOfDay(activity.date);
                app.viewYear = new Date(activity.date).getFullYear();
                app.viewMonth = new Date(activity.date).getMonth();
            }
            persist();
            renderUpdateCount();
            renderCalendar();
            renderAgenda();
            renderMarkers();
            emit("update", {
                update: {
                    id: update.id, role: update.role, title: update.title, text: update.text,
                    produceId: update.produceId, zone: update.zone, at: update.at,
                    hasVideo: true, activityId: update.activityId
                }
            });
            if (activity) emit("activity", { activity: activity });
            closeModal("videoModal");
            openUpdates();
            toast("Update posted" + (activity ? " and added to the calendar." : "."));
        }).finally(function () {
            if (submit) submit.disabled = false;
        });
    }

    function renderUpdates() {
        renderUpdateCount();
        if (dom.updatesDrawer.classList.contains("hidden")) return;
        var sorted = app.updates.slice().sort(function (a, b) { return Number(b.at) - Number(a.at); });
        dom.updatesList.innerHTML = sorted.map(function (update) {
            var produce = update.produceId ? findProduce(update.produceId) : null;
            var zone = findZone(update.zone);
            var media = update.mediaId
                ? '<div class="update-media" data-media-id="' + esc(update.mediaId) + '"><div class="update-missing">Loading clip\u2026</div></div>'
                : "";
            return '<article class="update-card" data-activity-id="' + esc(update.activityId || "") + '" data-zone="' + esc(update.zone || "") + '">' +
                '<div class="update-head"><div class="update-avatar">' + esc(roleInitial(update.role)) + "</div>" +
                "<div><strong>" + esc(ROLE_LABELS[update.role] || "Dhun") + "</strong>" +
                "<small>" + esc(shortDate(update.at)) + " \u00B7 " + esc(Core.timeAgo(update.at, Date.now())) + "</small></div></div>" +
                "<h4>" + esc(update.title) + "</h4>" +
                (update.text ? "<p>" + esc(update.text) + "</p>" : "") +
                media +
                '<div class="update-foot">' +
                '<span class="chip">' + (update.kind === "video" ? "video" : "note") + "</span>" +
                (zone ? '<span class="chip ghost">' + esc(zone.short) + "</span>" : "") +
                (produce ? '<span class="chip ghost">' + esc(produce.name) + "</span>" : "") +
                '<span class="chip ghost">' + (embedded ? "room copy" : "local copy") + "</span>" +
                '<button type="button" class="btn btn-ghost" data-act="show-update"' + (zone ? "" : " disabled") + ">Map</button>" +
                "</div></article>";
        }).join("");
        dom.updatesList.querySelectorAll("[data-media-id]").forEach(function (holder) {
            var id = holder.getAttribute("data-media-id");
            mediaUrl(id).then(function (url) {
                if (!url) {
                    holder.innerHTML = '<div class="update-missing">This clip is not available in this browser anymore.</div>';
                    return;
                }
                holder.innerHTML = "";
                var video = document.createElement("video");
                video.controls = true;
                video.playsInline = true;
                video.preload = "metadata";
                video.src = url;
                holder.appendChild(video);
            });
        });
        if (app.updatesFocusActivity) {
            var target = dom.updatesList.querySelector('[data-activity-id="' + app.updatesFocusActivity + '"]');
            if (target) target.scrollIntoView({ block: "center" });
            app.updatesFocusActivity = "";
        }
    }

    function openUpdates() {
        dom.scrim.classList.remove("hidden");
        dom.updatesDrawer.classList.remove("hidden");
        renderUpdates();
    }

    function closeUpdates() {
        dom.updatesDrawer.classList.add("hidden");
        dom.scrim.classList.add("hidden");
    }

    function openUpdatesForActivity(id) {
        app.updatesFocusActivity = id;
        openUpdates();
    }

    function openModal(id) {
        var modal = $(id);
        if (!modal) return;
        modal.classList.remove("hidden");
    }

    function closeModal(id) {
        var modal = $(id);
        if (!modal) return;
        modal.classList.add("hidden");
        if (id === "videoModal") resetVideoSession();
        if (id === "activityModal") {
            cancelPlacement(false);
        }
        if (id === "orderModal") app.order = null;
    }

    function anyModalOpen() {
        return Array.prototype.some.call(document.querySelectorAll(".modal-layer"), function (modal) {
            return !modal.classList.contains("hidden");
        });
    }

    function closeTopModal() {
        var layers = Array.prototype.filter.call(document.querySelectorAll(".modal-layer"), function (modal) {
            return !modal.classList.contains("hidden");
        });
        if (layers.length) {
            closeModal(layers[layers.length - 1].id);
            return true;
        }
        return false;
    }

    function referrerLabel() {
        if (window.location.protocol === "file:") return "the embedded studio (file origin)";
        if (window.location.origin === "null") return "http://127.0.0.1:8788/*";
        return window.location.origin + "/*";
    }

    function showKeyNotice(kind) {
        var strong = dom.keyNotice.querySelector("strong");
        var paragraph = dom.keyNotice.querySelector("p");
        if (kind === "auth") {
            strong.textContent = "Google place search rejected this key.";
            paragraph.textContent = window.location.protocol === "file:"
                ? "The embedded studio runs from a file origin, so website referrer restrictions will not match. The satellite map and OpenStreetMap search still work."
                : "Check that the Geocoding API is enabled and the key allows " +
                    referrerLabel() + ". The satellite map and OpenStreetMap search still work.";
            dom.keyNoticeBtn.textContent = "Fix key";
        } else if (kind === "network") {
            strong.textContent = "Google place search could not load.";
            paragraph.textContent = "Check the connection or key restrictions. The satellite map and OpenStreetMap search still work.";
            dom.keyNoticeBtn.textContent = "Open setup";
        } else {
            strong.textContent = "Google place search is optional.";
            paragraph.textContent = "The satellite map works without a key. Your key stays in this browser and is never committed.";
            dom.keyNoticeBtn.textContent = "Add key";
        }
        dom.keyNotice.classList.remove("hidden");
    }

    function hideKeyNotice() {
        dom.keyNotice.classList.add("hidden");
    }

    function noticeDismissed() {
        try { return window.sessionStorage.getItem(NOTICE_KEY) === "1"; }
        catch (error) { return false; }
    }

    function dismissNotice() {
        hideKeyNotice();
        try { window.sessionStorage.setItem(NOTICE_KEY, "1"); } catch (error) { /* ignore */ }
    }

    function openSetup() {
        dom.referrerText.textContent = window.location.protocol === "file:"
            ? "file:// \u00B7 use API restrictions only, or serve at http://127.0.0.1:8788/qml/web/"
            : (window.location.origin === "null" ? "http://127.0.0.1:8788" : window.location.origin) + "/*";
        dom.mapsKeyInput.value = "";
        dom.mapsKeyInput.placeholder = readKey() ? "A key is saved \u00B7 paste a new one to replace it" : "AIza\u2026";
        dom.removeKey.classList.toggle("hidden", !readKey());
        var consoleLink = dom.setupModal.querySelector('a[href*="console.cloud.google.com"]');
        if (consoleLink) consoleLink.classList.toggle("hidden", embedded);
        openModal("setupModal");
        window.setTimeout(function () { dom.mapsKeyInput.focus(); }, 50);
    }

    function saveMapsKey() {
        var key = dom.mapsKeyInput.value.trim();
        if (key.length < 20) {
            toast("Paste a Google Maps API key first.", true);
            return;
        }
        if (!writeStorage(KEY_STORAGE, key)) {
            toast("This browser blocked local storage. Serve the studio at http://127.0.0.1:8788/qml/web/.", true);
            return;
        }
        try { window.sessionStorage.removeItem(NOTICE_KEY); } catch (error) { /* ignore */ }
        toast("Key saved in this browser. Reloading Google place search\u2026");
        window.setTimeout(function () { window.location.reload(); }, 250);
    }

    function removeMapsKey() {
        try { window.localStorage.removeItem(KEY_STORAGE); } catch (error) { /* ignore */ }
        toast("Key removed. OpenStreetMap place search is active\u2026");
        window.setTimeout(function () { window.location.reload(); }, 200);
    }

    function loadGoogleMaps(key) {
        return new Promise(function (resolve, reject) {
            var settled = false;
            var callbackName = "__dhunMapsReady";
            var timer = window.setTimeout(function () {
                if (settled) return;
                settled = true;
                reject(new Error("timeout"));
            }, 16000);
            function finish(error) {
                if (settled) return;
                settled = true;
                window.clearTimeout(timer);
                if (error) reject(error); else resolve();
            }
            window[callbackName] = function () { finish(); };
            window.gm_authFailure = function () {
                app.authFailed = true;
                finish(new Error("auth"));
            };
            var script = document.createElement("script");
            script.src = "https://maps.googleapis.com/maps/api/js?key=" + encodeURIComponent(key) +
                "&v=weekly&region=IN&language=en&callback=" + callbackName;
            script.async = true;
            script.defer = true;
            script.onerror = function () { finish(new Error("network")); };
            document.head.appendChild(script);
        });
    }

    function addZoomButtons() {
        if (document.querySelector(".map-zoom")) return;
        var tools = document.querySelector(".map-tools");
        if (!tools) return;
        var zoomIn = document.createElement("button");
        zoomIn.type = "button";
        zoomIn.className = "map-btn icon-only map-zoom";
        zoomIn.title = "Zoom in";
        zoomIn.setAttribute("aria-label", "Zoom in");
        zoomIn.innerHTML = '<svg><use href="#i-plus"/></svg>';
        zoomIn.addEventListener("click", function () {
            if (app.leaflet) app.leaflet.setZoom(app.leaflet.getZoom() + 1);
        });
        var zoomOut = document.createElement("button");
        zoomOut.type = "button";
        zoomOut.className = "map-btn icon-only map-zoom";
        zoomOut.title = "Zoom out";
        zoomOut.setAttribute("aria-label", "Zoom out");
        zoomOut.innerHTML = '<svg><use href="#i-minus"/></svg>';
        zoomOut.addEventListener("click", function () {
            if (app.leaflet) app.leaflet.setZoom(app.leaflet.getZoom() - 1);
        });
        tools.insertBefore(zoomIn, dom.locateBtn);
        tools.insertBefore(zoomOut, dom.locateBtn);
    }

    function initLeafletMap() {
        if (app.leaflet) return true;
        if (!window.L) return false;
        dom.map.classList.remove("hidden");
        dom.mapFallback.classList.add("hidden");
        try {
            app.leaflet = L.map(dom.map, {
                center: [DATA.site.latitude, DATA.site.longitude],
                zoom: Number(CONFIG.defaultZoom) || 15,
                minZoom: 3,
                maxZoom: 19,
                zoomControl: false,
                worldCopyJump: true,
                attributionControl: true
            });
        } catch (error) {
            app.leaflet = null;
            dom.map.classList.add("hidden");
            dom.mapFallback.classList.remove("hidden");
            return false;
        }
        var imagery = L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
            maxZoom: 19,
            maxNativeZoom: 19,
            attribution: "Imagery &copy; Esri, Maxar, Earthstar Geographics"
        }).addTo(app.leaflet);
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}", {
            maxZoom: 19,
            maxNativeZoom: 19,
            attribution: "Labels &copy; Esri, OpenStreetMap contributors"
        }).addTo(app.leaflet);
        app.leafletGroup = L.layerGroup().addTo(app.leaflet);

        var tileErrors = 0;
        imagery.on("tileerror", function () {
            tileErrors += 1;
            if (tileErrors !== 4) return;
            setBadge("SATELLITE OFFLINE");
            toast("Satellite tiles did not load. Check the connection; markers still work.", true);
        });
        imagery.on("load", function () {
            tileErrors = 0;
            setBadge("SATELLITE \u00B7 ESRI");
        });
        app.leaflet.on("click", function (event) {
            var latitude = event.latlng.lat;
            var longitude = event.latlng.lng;
            if (app.placing) finishPlacement(latitude, longitude);
            else showPointCard({ latitude: latitude, longitude: longitude });
        });

        app.mapProvider = "leaflet";
        setBadge("SATELLITE \u00B7 ESRI");
        addZoomButtons();
        renderMarkers();
        window.setTimeout(function () { if (app.leaflet) app.leaflet.invalidateSize(); }, 0);
        // The WKWebView host can lay the grid out after the first tick, so keep
        // Leaflet matched to the container instead of trusting one timeout.
        if (window.ResizeObserver && !app.mapResizeObserver) {
            app.mapResizeObserver = new ResizeObserver(function () {
                if (app.leaflet) app.leaflet.invalidateSize();
            });
            app.mapResizeObserver.observe(dom.map);
        }
        return true;
    }

    function initMaps() {
        var leafletOk = initLeafletMap();
        if (!leafletOk) {
            setBadge("LOCAL PLAN VIEW");
            if (dom.fallbackFlagText) dom.fallbackFlagText.textContent = "Plan view \u00B7 satellite library did not load";
            toast("The satellite map could not start. The local plan view is active.", true);
        }
        var key = readKey();
        if (!key) return;
        app.authFailed = false;
        loadGoogleMaps(key).then(function () {
            if (app.authFailed) return;
            app.geocoderReady = true;
            hideKeyNotice();
            toast("Google place search connected.", false);
        }).catch(function (error) {
            app.geocoderReady = false;
            showKeyNotice(error.message === "auth" ? "auth" : "network");
            toast("Google place search is unavailable. OpenStreetMap search is active.", true);
        });
    }

    function localSearch(query) {
        var value = String(query || "").trim().toLowerCase();
        if (!value) return { produce: [], growers: [], zones: [], site: false };
        var growers = DATA.growers.filter(function (grower) {
            return (grower.name + " " + grower.short + " " + grower.village + " " + grower.note).toLowerCase().indexOf(value) !== -1;
        }).slice(0, 3);
        var zones = DATA.zones.filter(function (zone) {
            return (zone.name + " " + zone.short + " " + zone.description).toLowerCase().indexOf(value) !== -1;
        }).slice(0, 2);
        var site = ("dhun " + DATA.site.name + " " + DATA.site.place).toLowerCase().indexOf(value) !== -1;
        return {
            produce: Core.searchProduces(DATA.produce, value).slice(0, 5),
            growers: growers,
            zones: zones,
            site: site
        };
    }

    function closeSearch() {
        dom.searchResults.classList.add("hidden");
        app.searchActive = -1;
        app.searchMode = "local";
    }

    function renderLocalSearch() {
        var query = dom.searchInput.value.trim();
        if (!query) { closeSearch(); return; }
        var results = localSearch(query);
        var html = "";
        var rows = [];
        if (results.produce.length) {
            html += '<div class="search-group">Produce</div>';
            results.produce.forEach(function (item) {
                html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                    '<img src="' + esc(item.photo) + '" alt="">' +
                    "<div><strong>" + esc(item.name) + " \u00B7 " + esc(item.local) + "</strong>" +
                    "<small>" + esc(item.growerName) + " \u00B7 " + esc(stockLabel(item)) + " \u00B7 " + Core.formatINR(item.price) + "/" + esc(item.unit) + "</small></div></button>";
                rows.push({ kind: "produce", id: item.id });
            });
        }
        if (results.growers.length) {
            html += '<div class="search-group">Growers</div>';
            results.growers.forEach(function (grower) {
                html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                    '<span class="search-glyph">' + esc(grower.short.charAt(0)) + "</span>" +
                    "<div><strong>" + esc(grower.name) + "</strong><small>" + esc(grower.village) + " \u00B7 " +
                    produceForGrower(grower.id).length + " plots</small></div></button>";
                rows.push({ kind: "grower", id: grower.id });
            });
        }
        if (results.zones.length) {
            html += '<div class="search-group">Field zones</div>';
            results.zones.forEach(function (zone) {
                html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                    '<span class="search-glyph"><svg><use href="#i-pin"/></svg></span>' +
                    "<div><strong>" + esc(zone.name) + "</strong><small>" + produceInZone(zone.id).length + " plots \u00B7 " +
                    zoneActivities(zone.id).length + " work items</small></div></button>";
                rows.push({ kind: "zone", id: zone.id });
            });
        }
        if (results.site) {
            html += '<div class="search-group">Site</div>';
            html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                '<span class="search-glyph"><svg><use href="#i-leaf"/></svg></span>' +
                "<div><strong>Dhun</strong><small>" + esc(DATA.site.place) + " \u00B7 " + DATA.site.acres + " acres</small></div></button>";
            rows.push({ kind: "site" });
        }
        if (query.length >= 3) {
            html += '<div class="search-group">' + (app.geocoderReady ? "Google Maps" : "OpenStreetMap") + '</div>';
            html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                '<span class="search-glyph"><svg><use href="#i-search"/></svg></span>' +
                '<div><strong>Search the map for &ldquo;' + esc(query) + '&rdquo;</strong>' +
                "<small>" + (app.geocoderReady ? "Geocoding API" : "Photon \u00B7 keyless place search") +
                " \u00B7 results appear as map pins</small></div></button>";
            rows.push({ kind: "geocode", query: query });
        }
        if (!html) {
            html = '<div class="search-empty">No local match. ' +
                (query.length >= 3 ? "Press Enter to search places." : "Type three characters to search places.") + "</div>";
        }
        app.searchRows = rows;
        app.searchMode = "local";
        app.searchActive = -1;
        dom.searchResults.innerHTML = html;
        dom.searchResults.classList.remove("hidden");
    }

    function renderPlaceSearchResults() {
        var query = dom.searchInput.value.trim();
        var provider = app.geocodeResults.length ? app.geocodeResults[0].provider : "OpenStreetMap";
        var html = '<div class="search-group">' + esc(provider) + ' \u00B7 pick a pin</div>';
        var rows = [];
        app.geocodeResults.forEach(function (result, index) {
            html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
                '<span class="search-glyph"><svg><use href="#i-pin"/></svg></span>' +
                "<div><strong>" + esc(result.name) + "</strong><small>" + esc(result.address) + "</small></div></button>";
            rows.push({ kind: "place", index: index });
        });
        html += '<div class="search-group">Local matches</div>';
        html += '<button type="button" class="search-row" data-row-index="' + rows.length + '">' +
            '<span class="search-glyph"><svg><use href="#i-search"/></svg></span>' +
            "<div><strong>Back to produce and growers</strong><small>" + esc(query || "Search the field index") + "</small></div></button>";
        rows.push({ kind: "local", query: query });
        app.searchRows = rows;
        app.searchMode = "places";
        app.searchActive = -1;
        dom.searchResults.innerHTML = html;
        dom.searchResults.classList.remove("hidden");
    }

    function highlightSearchRows() {
        dom.searchResults.querySelectorAll(".search-row").forEach(function (row, index) {
            row.classList.toggle("active", index === app.searchActive);
        });
    }

    function activateSearchRow(index) {
        var row = app.searchRows[index];
        if (!row) return;
        if (row.kind === "geocode") {
            runPlaceSearch(row.query);
            return;
        }
        if (row.kind === "local") {
            renderLocalSearch();
            return;
        }
        closeSearch();
        dom.searchInput.value = "";
        if (row.kind === "produce") openProduce(row.id);
        else if (row.kind === "grower") openGrower(row.id);
        else if (row.kind === "zone") openZone(row.id);
        else if (row.kind === "site") openSite();
        else if (row.kind === "place") {
            var result = app.geocodeResults[row.index];
            if (result) selectPlaceResult(result);
        }
    }

    function placeErrorMessage(status) {
        if (status === "OVER_QUERY_LIMIT") return "Google Maps place-search quota reached. Try again later.";
        if (status === "REQUEST_DENIED") return "Place search is not enabled for this key. OpenStreetMap search still works.";
        return "Google Maps place search failed. OpenStreetMap search still works.";
    }

    function normalizeGooglePlace(result) {
        var location = result && result.geometry && result.geometry.location;
        if (!location) return null;
        var address = result.formatted_address || "";
        return {
            name: address.split(",")[0] || "Place",
            address: address,
            latitude: location.lat(),
            longitude: location.lng(),
            provider: "Google Maps"
        };
    }

    function normalizePhotonPlace(feature) {
        var properties = (feature && feature.properties) || {};
        var coordinates = (feature && feature.geometry && feature.geometry.coordinates) || [];
        if (coordinates.length < 2) return null;
        var name = properties.name || properties.street || properties.city || properties.county || "Place";
        var parts = [];
        [properties.street, properties.city || properties.district, properties.state, properties.postcode, properties.country]
            .forEach(function (part) {
                if (part && parts.indexOf(part) === -1) parts.push(part);
            });
        return {
            name: name,
            address: parts.join(", ") || name,
            latitude: Number(coordinates[1]),
            longitude: Number(coordinates[0]),
            provider: "OpenStreetMap"
        };
    }

    function handlePlaceResults(results, token, query) {
        if (token !== app.searchToken) return;
        if (!results.length) {
            toast("No places found for \u201C" + query + "\u201D.");
            renderLocalSearch();
            return;
        }
        if (results.length === 1) {
            selectPlaceResult(results[0]);
            return;
        }
        app.geocodeResults = results;
        renderPlaceSearchResults();
    }

    function photonPlaceSearch(query, token) {
        var bbox = [
            DATA.site.longitude - 0.8, DATA.site.latitude - 0.8,
            DATA.site.longitude + 0.8, DATA.site.latitude + 0.8
        ].join(",");
        var url = "https://photon.komoot.io/api/?q=" + encodeURIComponent(query) +
            "&limit=6&lang=en&lat=" + DATA.site.latitude + "&lon=" + DATA.site.longitude + "&bbox=" + bbox;
        fetch(url, { headers: { Accept: "application/json" } }).then(function (response) {
            if (!response.ok) throw new Error("HTTP " + response.status);
            return response.json();
        }).then(function (data) {
            if (token !== app.searchToken) return;
            var results = (data.features || []).map(normalizePhotonPlace).filter(Boolean);
            handlePlaceResults(results, token, query);
        }).catch(function () {
            if (token !== app.searchToken) return;
            toast("OpenStreetMap place search is unavailable. Local produce and grower search still works.", true);
            renderLocalSearch();
        });
    }

    function runPlaceSearch(query) {
        query = String(query || "").trim();
        if (!query) return;
        if (query.length < 3) {
            toast("Type at least three characters to search places.", true);
            return;
        }
        var token = ++app.searchToken;
        var googleReady = app.geocoderReady && window.google && google.maps;
        dom.searchResults.innerHTML = '<div class="search-empty">Searching ' +
            (googleReady ? "Google Maps" : "OpenStreetMap") + ' for &ldquo;' + esc(query) + '&rdquo;\u2026</div>';
        dom.searchResults.classList.remove("hidden");
        app.searchRows = [];
        if (!googleReady) {
            photonPlaceSearch(query, token);
            return;
        }
        var bounds = new google.maps.LatLngBounds(
            new google.maps.LatLng(DATA.site.latitude - 0.8, DATA.site.longitude - 0.8),
            new google.maps.LatLng(DATA.site.latitude + 0.8, DATA.site.longitude + 0.8)
        );
        new google.maps.Geocoder().geocode({ address: query, region: "IN", bounds: bounds }, function (results, status) {
            if (token !== app.searchToken) return;
            if (status === "OK" && results && results.length) {
                handlePlaceResults(results.map(normalizeGooglePlace).filter(Boolean), token, query);
                return;
            }
            if (status === "ZERO_RESULTS") {
                toast("No places found for \u201C" + query + "\u201D.");
                renderLocalSearch();
                return;
            }
            toast(placeErrorMessage(status), true);
            renderLocalSearch();
        });
    }

    function selectPlaceResult(result) {
        if (!result || !isFinite(Number(result.latitude)) || !isFinite(Number(result.longitude))) return;
        app.currentPlace = {
            name: result.name || "Dropped place",
            address: result.address || "",
            latitude: Number(result.latitude),
            longitude: Number(result.longitude)
        };
        app.geocodeResults = [];
        app.searchMode = "local";
        dom.searchInput.value = "";
        closeSearch();
        focusCoords(app.currentPlace.latitude, app.currentPlace.longitude, 14);
        showPlaceCard(app.currentPlace);
        renderMarkers();
    }

    function locateDhun() {
        showSiteCard();
        if (app.leaflet) {
            app.leaflet.setView([DATA.site.latitude, DATA.site.longitude], Number(CONFIG.defaultZoom) || 15);
            flashPin("site", "dhun");
            return;
        }
        flashPin("site", "dhun");
        toast("Plan view \u00B7 satellite tiles are unavailable.", true);
    }

    function openActivityForPoint(point) {
        openActivityModal({ point: point, zone: "farms", date: app.selectedDate });
    }

    function bindEvents() {
        dom.roleSwitch.addEventListener("click", function (event) {
            var button = event.target.closest("[data-role]");
            if (button) switchRole(button.getAttribute("data-role"), true);
        });

        dom.seasonSwitch.addEventListener("click", function (event) {
            var button = event.target.closest("[data-season]");
            if (!button) return;
            app.season = button.getAttribute("data-season");
            syncSeasonSwitch();
            renderMarkers();
        });

        dom.calendarGrid.addEventListener("click", function (event) {
            var button = event.target.closest("[data-day]");
            if (!button) return;
            app.selectedDate = Number(button.getAttribute("data-day"));
            renderCalendar();
            renderAgenda();
        });

        dom.prevMonth.addEventListener("click", function () {
            app.viewMonth -= 1;
            if (app.viewMonth < 0) { app.viewMonth = 11; app.viewYear -= 1; }
            var now = new Date();
            app.selectedDate = now.getFullYear() === app.viewYear && now.getMonth() === app.viewMonth
                ? startOfDay(now.getTime())
                : new Date(app.viewYear, app.viewMonth, 1).getTime();
            renderCalendar();
            renderAgenda();
        });

        dom.nextMonth.addEventListener("click", function () {
            app.viewMonth += 1;
            if (app.viewMonth > 11) { app.viewMonth = 0; app.viewYear += 1; }
            var now = new Date();
            app.selectedDate = now.getFullYear() === app.viewYear && now.getMonth() === app.viewMonth
                ? startOfDay(now.getTime())
                : new Date(app.viewYear, app.viewMonth, 1).getTime();
            renderCalendar();
            renderAgenda();
        });

        dom.calendarAdd.addEventListener("click", function () {
            openActivityModal({ date: app.selectedDate });
        });

        dom.agendaList.addEventListener("click", function (event) {
            var button = event.target.closest("[data-act]");
            if (!button) return;
            var action = button.getAttribute("data-act");
            if (action === "add") openActivityModal({ date: app.selectedDate });
            if (action === "toggle") toggleActivity(button.getAttribute("data-id"));
            if (action === "map") focusActivity(button.getAttribute("data-id"));
            if (action === "clip") {
                var activity = findActivity(button.getAttribute("data-id"));
                if (activity && activity.media && activity.media.length) openUpdatesForActivity(activity.id);
            }
        });

        dom.dockFilters.addEventListener("click", function (event) {
            var button = event.target.closest("[data-cat]");
            if (!button) return;
            app.category = button.getAttribute("data-cat");
            renderDock();
        });

        dom.produceDock.addEventListener("click", function (event) {
            var action = event.target.closest("[data-act]");
            var card = event.target.closest(".produce-card");
            if (!card) return;
            var id = card.getAttribute("data-id");
            if (action) {
                if (action.getAttribute("data-act") === "map") openProduce(id);
                if (action.getAttribute("data-act") === "procure") openOrder(id);
                return;
            }
            openProduce(id);
        });

        dom.produceDock.addEventListener("keydown", function (event) {
            if (event.key !== "Enter" && event.key !== " ") return;
            var card = event.target.closest(".produce-card");
            if (!card) return;
            event.preventDefault();
            openProduce(card.getAttribute("data-id"));
        });

        dom.fallbackPins.addEventListener("click", function (event) {
            if (app.placing) return;
            var pin = event.target.closest("[data-kind]");
            if (!pin) return;
            event.stopPropagation();
            var kind = pin.getAttribute("data-kind");
            var id = pin.getAttribute("data-id");
            if (kind === "produce") openProduce(id);
            else if (kind === "zone") openZone(id);
            else if (kind === "site") openSite();
            else if (kind === "activity") focusActivity(id);
        });

        dom.mapFallback.addEventListener("click", function (event) {
            if (!app.placing) return;
            var rect = dom.mapFallback.getBoundingClientRect();
            if (!rect.width || !rect.height) return;
            var x = (event.clientX - rect.left) / rect.width;
            var y = (event.clientY - rect.top) / rect.height;
            var latitude = DATA.site.latitude + (0.5 - y) * FALLBACK_LAT_SPAN;
            var longitude = DATA.site.longitude + (x - 0.5) * FALLBACK_LNG_SPAN;
            finishPlacement(latitude, longitude);
        });

        dom.mapCard.addEventListener("click", function (event) {
            var button = event.target.closest("[data-act]");
            if (!button) return;
            var action = button.getAttribute("data-act");
            var card = app.activeCard;
            if (!card) return;
            if (action === "close") {
                if (card.kind === "place") closePlace();
                else dismissMapCard();
                return;
            }
            if (card.kind === "produce") {
                if (action === "procure") openOrder(card.id);
                if (action === "log") {
                    var item = findProduce(card.id);
                    openActivityModal({ produceId: card.id, zone: item ? item.zone : "farms" });
                }
            } else if (card.kind === "activity") {
                if (action === "toggle") toggleActivity(card.id);
                if (action === "follow-up") {
                    var activity = findActivity(card.id);
                    openActivityModal({
                        produceId: activity ? activity.produceId : "",
                        zone: activity ? activity.zone : "farms",
                        point: activity ? { latitude: activity.plot.latitude, longitude: activity.plot.longitude } : null
                    });
                }
                if (action === "clip") {
                    var current = findActivity(card.id);
                    if (current && current.media && current.media.length) openUpdatesForActivity(current.id);
                }
            } else if (card.kind === "zone") {
                if (action === "log-zone") openActivityModal({ zone: card.id });
            } else if (card.kind === "site") {
                if (action === "log-site") openActivityModal();
            } else if (card.kind === "place") {
                if (action === "clear-place") closePlace();
                if (action === "log-place" && app.currentPlace) openActivityForPoint({ latitude: app.currentPlace.latitude, longitude: app.currentPlace.longitude });
            } else if (card.kind === "point") {
                if (action === "log-point") openActivityForPoint(card.point);
            }
        });

        dom.locateBtn.addEventListener("click", locateDhun);
        dom.addActivityBtn.addEventListener("click", function () { openActivityModal(); });

        dom.cancelPlacement.addEventListener("click", function () { cancelPlacement(true); });
        dom.pickOnMap.addEventListener("click", function () {
            readActivityForm();
            closeModal("activityModal");
            beginPlacement();
        });

        dom.activityTypes.addEventListener("click", function (event) {
            var button = event.target.closest("[data-type]");
            if (!button) return;
            dom.activityTypes.querySelectorAll(".type-chip").forEach(function (chip) { chip.classList.remove("active"); });
            button.classList.add("active");
            if (app.draft) app.draft.type = button.getAttribute("data-type");
        });

        dom.activityZone.addEventListener("change", function () {
            if (app.draft) {
                app.draft.zone = dom.activityZone.value;
                if (!app.draft.point) updateActivityLocationLabel();
            }
        });

        dom.activityProduce.addEventListener("change", function () {
            var item = findProduce(dom.activityProduce.value);
            if (item) {
                dom.activityZone.value = item.zone;
                if (app.draft) {
                    app.draft.zone = item.zone;
                    if (!app.draft.point) updateActivityLocationLabel();
                }
            }
        });

        dom.activityForm.addEventListener("submit", submitActivity);

        dom.recordBtn.addEventListener("click", openVideoModal);
        dom.drawerRecord.addEventListener("click", function () {
            closeUpdates();
            openVideoModal();
        });

        dom.startCamera.addEventListener("click", startCamera);
        dom.toggleRecord.addEventListener("click", toggleRecording);
        dom.videoFile.addEventListener("change", function () {
            var file = dom.videoFile.files && dom.videoFile.files[0];
            if (file) attachFile(file);
        });
        dom.videoProduce.addEventListener("change", function () {
            var item = findProduce(dom.videoProduce.value);
            if (item) dom.videoZone.value = item.zone;
        });
        dom.videoForm.addEventListener("submit", postVideoUpdate);

        dom.updatesBtn.addEventListener("click", openUpdates);
        dom.closeUpdates.addEventListener("click", closeUpdates);
        dom.scrim.addEventListener("click", closeUpdates);
        dom.updatesList.addEventListener("click", function (event) {
            var button = event.target.closest("[data-act]");
            if (!button) return;
            var card = button.closest(".update-card");
            if (!card) return;
            var zone = card.getAttribute("data-zone");
            var activityId = card.getAttribute("data-activity-id");
            closeUpdates();
            if (activityId) focusActivity(activityId);
            else if (zone) openZone(zone);
        });

        dom.setupBtn.addEventListener("click", openSetup);
        dom.keyNoticeBtn.addEventListener("click", openSetup);
        dom.saveKey.addEventListener("click", saveMapsKey);
        dom.removeKey.addEventListener("click", removeMapsKey);
        dom.mapsKeyInput.addEventListener("keydown", function (event) {
            if (event.key === "Enter") { event.preventDefault(); saveMapsKey(); }
        });

        dom.searchInput.addEventListener("input", function () {
            app.searchMode = "local";
            app.geocodeResults = [];
            app.searchToken += 1;
            renderLocalSearch();
        });

        dom.searchInput.addEventListener("focus", function () {
            if (dom.searchInput.value.trim()) renderLocalSearch();
        });

        dom.searchInput.addEventListener("keydown", function (event) {
            if (event.key === "ArrowDown" || event.key === "ArrowUp") {
                event.preventDefault();
                if (!app.searchRows.length) return;
                if (event.key === "ArrowDown") app.searchActive = (app.searchActive + 1) % app.searchRows.length;
                else app.searchActive = app.searchActive <= 0 ? app.searchRows.length - 1 : app.searchActive - 1;
                highlightSearchRows();
                return;
            }
            if (event.key === "Enter") {
                event.preventDefault();
                if (app.searchActive >= 0) activateSearchRow(app.searchActive);
                else if (app.searchRows.length) activateSearchRow(0);
                else runPlaceSearch(dom.searchInput.value);
                return;
            }
            if (event.key === "Escape") {
                closeSearch();
                dom.searchInput.blur();
            }
        });

        dom.searchResults.addEventListener("click", function (event) {
            var row = event.target.closest("[data-row-index]");
            if (!row) return;
            activateSearchRow(Number(row.getAttribute("data-row-index")));
        });

        dom.orderMinus.addEventListener("click", function () { adjustOrderQty(-1); });
        dom.orderPlus.addEventListener("click", function () { adjustOrderQty(1); });
        dom.orderQty.addEventListener("change", function () {
            if (!app.order) return;
            app.order.qty = clampNumber(dom.orderQty.value, 1, Math.max(1, stockOf(app.order.id)));
            updateOrderTotals();
        });
        dom.orderSubmit.addEventListener("click", submitStandaloneOrder);
        dom.orderOfferBtn.addEventListener("click", requestWalletOffer);

        document.addEventListener("click", function (event) {
            if (event.target.closest("[data-close]")) {
                var closeId = event.target.closest("[data-close]").getAttribute("data-close");
                closeModal(closeId);
                return;
            }
            if (event.target.classList && event.target.classList.contains("modal-layer")) {
                closeModal(event.target.id);
                return;
            }
            if (!event.target.closest(".search-wrap")) closeSearch();
        });

        document.addEventListener("keydown", function (event) {
            if ((event.metaKey || event.ctrlKey) && String(event.key).toLowerCase() === "k") {
                event.preventDefault();
                dom.searchInput.focus();
                dom.searchInput.select();
                return;
            }
            if (event.key !== "Escape") return;
            if (closeTopModal()) return;
            if (app.placing) { cancelPlacement(true); return; }
            if (!dom.updatesDrawer.classList.contains("hidden")) { closeUpdates(); return; }
            if (!dom.searchResults.classList.contains("hidden")) { closeSearch(); return; }
            dismissMapCard();
        });

        window.addEventListener("beforeunload", function () {
            stopStreamTracks();
            if (app.video.pendingUrl) URL.revokeObjectURL(app.video.pendingUrl);
        });
    }

    function createOrderModal() {
        var wrapper = document.createElement("div");
        wrapper.innerHTML =
            '<div class="modal-layer hidden" id="orderModal" role="dialog" aria-modal="true" aria-labelledby="orderModalTitle">' +
            '<div class="modal modal-order">' +
            '<header class="modal-head"><div><p class="eyebrow">Farmer inventory</p><h2 id="orderModalTitle">Procure from the field</h2></div>' +
            '<button type="button" class="icon-btn" data-close="orderModal" aria-label="Close"><svg><use href="#i-close"/></svg></button></header>' +
            '<div class="setup-body">' +
            '<div class="order-hero"><img id="orderPhoto" alt="" width="76" height="76"><div><h3 id="orderName"></h3><p id="orderMeta"></p><p id="orderGrower"></p></div></div>' +
            '<div class="order-summary"><div><span>In stock</span><strong id="orderStock"></strong></div>' +
            '<div><span>Price</span><strong id="orderPrice"></strong></div>' +
            '<div><span>Total</span><strong id="orderTotal"></strong></div></div>' +
            '<label class="field"><span>Quantity</span><div class="qty-row"><button type="button" id="orderMinus" aria-label="Decrease quantity">\u2212</button>' +
            '<input id="orderQty" type="number" min="1" step="1" value="1" aria-label="Quantity">' +
            '<button type="button" id="orderPlus" aria-label="Increase quantity">+</button><span id="orderUnitLabel"></span></div></label>' +
            '<p class="order-note" id="orderNote"></p>' +
            '<div class="form-error hidden" id="orderError"></div>' +
            '<footer class="modal-foot"><button class="btn btn-ghost" type="button" data-close="orderModal">Cancel</button>' +
            '<button class="btn btn-dark" id="orderOfferBtn" type="button">Open offer in wallet</button>' +
            '<button class="btn btn-dark" id="orderSubmit" type="button">Confirm procurement</button></footer>' +
            "</div></div></div>";
        document.body.appendChild(wrapper.firstChild);
        dom.orderPhoto = $("orderPhoto");
        dom.orderName = $("orderName");
        dom.orderMeta = $("orderMeta");
        dom.orderGrower = $("orderGrower");
        dom.orderStock = $("orderStock");
        dom.orderPrice = $("orderPrice");
        dom.orderTotal = $("orderTotal");
        dom.orderQty = $("orderQty");
        dom.orderMinus = $("orderMinus");
        dom.orderPlus = $("orderPlus");
        dom.orderUnitLabel = $("orderUnitLabel");
        dom.orderNote = $("orderNote");
        dom.orderError = $("orderError");
        dom.orderSubmit = $("orderSubmit");
        dom.orderOfferBtn = $("orderOfferBtn");
    }

    function snapshot() {
        var stats = Core.activityStats(app.activities, app.role, Date.now());
        return {
            role: app.role,
            site: { name: DATA.site.name, place: DATA.site.place, latitude: DATA.site.latitude, longitude: DATA.site.longitude },
            activities: app.activities.length,
            thisWeek: stats.thisWeek,
            planned: stats.planned,
            done: stats.done,
            produceInSeason: DATA.produce.filter(inSeasonNow).length,
            produceWithStock: DATA.produce.filter(function (item) { return stockOf(item.id) > 0; }).length,
            updates: app.updates.length,
            mapProvider: app.mapProvider,
            leafletReady: !!app.leaflet,
            geocoderReady: app.geocoderReady,
            embedded: embedded,
            at: Date.now()
        };
    }

    function pushReady() {
        if (!embedded) return;
        bridgeEvents.push({
            type: "ready",
            role: app.role,
            at: Date.now(),
            site: { name: DATA.site.name, latitude: DATA.site.latitude, longitude: DATA.site.longitude },
            produceInSeason: DATA.produce.filter(inSeasonNow).length,
            mapProvider: app.mapProvider,
            leafletReady: !!app.leaflet,
            geocoderReady: app.geocoderReady
        });
    }

    function initialise() {
        app.activities = hydrateActivities();
        app.updates = hydrateUpdates();
        app.inventory = hydrateInventory();
        document.body.classList.toggle("embedded", embedded);
        if (dom.drawerNoteText) {
            dom.drawerNoteText.textContent = embedded
                ? "Update notes are sent to the wallet coordination room. Clips stay in this studio unless you export them."
                : "Updates and clips stay in this browser. Open the studio inside the Dhun wallet to share with the coordination room.";
        }
        if (dom.videoShareHint) dom.videoShareHint.textContent = embedded
            ? "Posts the note to the wallet room; the clip stays in this studio."
            : "Posts to the local studio feed.";
        syncRoleButtons();
        syncSeasonSwitch();
        renderCalendar();
        renderAgenda();
        renderDock();
        renderUpdateCount();
        renderMarkers();
        createOrderModal();
        bindEvents();
        populateSelects();
        var close = document.createElement("button");
        close.type = "button";
        close.className = "key-notice-close";
        close.setAttribute("aria-label", "Dismiss");
        close.innerHTML = '<svg><use href="#i-close"/></svg>';
        close.addEventListener("click", dismissNotice);
        dom.keyNotice.appendChild(close);
        if (dom.referrerText && window.location.protocol !== "file:") {
            dom.referrerText.textContent = (window.location.origin === "null" ? "http://127.0.0.1:8788" : window.location.origin) + "/*";
        }
        if (app.role !== storedRole || urlRole) persist();
        setBadge("STARTING MAP");
        initMaps();
        window.setInterval(renderFreshness, 30000);
        pushReady();
    }

    window.dhunStudio = {
        openComposer: function (kind) {
            if (kind === "activity") openActivityModal();
            else openVideoModal();
        },
        openSetup: openSetup,
        setRole: function (role) { switchRole(role, false); return app.role; },
        focusProduce: openProduce,
        openProduce: openProduce,
        recordOrder: recordOrder,
        syncInventory: syncInventory,
        syncActivities: syncActivities,
        importActivity: function (activity) { return syncActivities([activity]) > 0; },
        setActivityStatus: setActivityStatus,
        resetSchedule: resetStudioSchedule,
        snapshot: snapshot,
        refresh: function () { window.location.reload(); }
    };

    window.dhunBridge = {
        drain: function () { return bridgeEvents.splice(0, bridgeEvents.length); },
        drainJSON: function () { return JSON.stringify(bridgeEvents.splice(0, bridgeEvents.length)); },
        snapshotJSON: function () { return JSON.stringify(snapshot()); },
        role: function () { return app.role; },
        setRole: function (role) { switchRole(role, false); return app.role; }
    };

    initialise();
}());
