(function (root, factory) {
    if (typeof module === "object" && module.exports) module.exports = factory();
    else root.DhunCore = factory();
}(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";

    var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

    function hash32(text) {
        var h = 0x811c9dc5;
        var value = String(text);
        for (var i = 0; i < value.length; ++i) {
            h ^= value.charCodeAt(i);
            h = Math.imul(h, 0x01000193) >>> 0;
        }
        return h >>> 0;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, Number(value) || 0));
    }

    function dateKey(timestamp) {
        var date = new Date(Number(timestamp) || Date.now());
        return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
    }

    function monthCells(year, month) {
        var first = new Date(year, month, 1);
        var offset = (first.getDay() + 6) % 7;
        var start = new Date(year, month, 1 - offset);
        var cells = [];
        for (var i = 0; i < 42; ++i) {
            var date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            cells.push({
                day: date.getDate(),
                month: date.getMonth(),
                year: date.getFullYear(),
                inMonth: date.getMonth() === month,
                timestamp: date.getTime()
            });
        }
        return cells;
    }

    function formatINR(value) {
        var rounded = Math.round(Number(value) || 0);
        var sign = rounded < 0 ? "-" : "";
        var digits = String(Math.abs(rounded));
        if (digits.length <= 3) return "\u20B9" + sign + digits;
        var last3 = digits.slice(-3);
        var rest = digits.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ",");
        return "\u20B9" + sign + rest + "," + last3;
    }

    function timeAgo(timestamp, now) {
        var seconds = Math.max(0, Math.round(((Number(now) || Date.now()) - Number(timestamp)) / 1000));
        if (seconds < 45) return "just now";
        var minutes = Math.round(seconds / 60);
        if (minutes < 60) return minutes + " min ago";
        var hours = Math.round(minutes / 60);
        if (hours < 24) return hours + " hr ago";
        var days = Math.round(hours / 24);
        if (days < 7) return days + " d ago";
        return MONTHS[new Date(Number(timestamp)).getMonth()] + " " + new Date(Number(timestamp)).getDate();
    }

    function inSeason(produce, month) {
        if (!produce) return false;
        if (produce.yearRound) return true;
        return (produce.months || []).indexOf(Number(month)) !== -1;
    }

    function seasonForMonth(month) {
        var value = Number(month);
        if (value >= 7 && value <= 10) return "Kharif";
        if (value >= 11 || value <= 3) return "Rabi";
        return "Zaid";
    }

    function nextHarvestLabel(produce, now) {
        if (!produce) return "";
        if (produce.yearRound) return "Year-round";
        var date = new Date(Number(now) || Date.now());
        var month = date.getMonth() + 1;
        if ((produce.months || []).indexOf(month) !== -1) return "In season now";
        for (var step = 1; step <= 12; ++step) {
            var next = ((month - 1 + step) % 12) + 1;
            if ((produce.months || []).indexOf(next) !== -1) return "Next harvest \u00B7 " + MONTHS[next - 1];
        }
        return "Out of season";
    }

    function filterProduce(items, options) {
        var opts = options || {};
        var source = items || [];
        var query = String(opts.query || "").trim().toLowerCase();
        return source.filter(function (item) {
            if (opts.zone && item.zone !== opts.zone) return false;
            if (opts.seasonOnly && opts.month && !inSeason(item, opts.month)) return false;
            if (opts.category && opts.category !== "All" && item.category !== opts.category) return false;
            if (!query) return true;
            var haystack = [item.name, item.local, item.botanical, item.category, item.zone, item.growerName].join(" ").toLowerCase();
            return haystack.indexOf(query) !== -1;
        });
    }

    function searchProduces(items, query) {
        var value = String(query || "").trim().toLowerCase();
        if (!value) return [];
        var scored = [];
        (items || []).forEach(function (item) {
            var name = String(item.name || "").toLowerCase();
            var local = String(item.local || "").toLowerCase();
            var other = [item.botanical, item.category, item.growerName].join(" ").toLowerCase();
            var score = -1;
            if (name === value || local === value) score = 100;
            else if (name.indexOf(value) === 0 || local.indexOf(value) === 0) score = 80;
            else if (name.indexOf(value) !== -1 || local.indexOf(value) !== -1) score = 60;
            else if (other.indexOf(value) !== -1) score = 30;
            if (score > 0) scored.push({ item: item, score: score });
        });
        scored.sort(function (a, b) { return b.score - a.score || a.item.name.localeCompare(b.item.name); });
        return scored.slice(0, 8).map(function (entry) { return entry.item; });
    }

    function validateActivity(input, now) {
        var activity = input || {};
        var errors = [];
        var title = String(activity.title || "").trim();
        if (title.length < 3) errors.push("Give the activity a short title.");
        if (title.length > 90) errors.push("Keep the title under 90 characters.");
        if (!activity.type) errors.push("Choose an activity type.");
        if (!activity.zone) errors.push("Choose a field zone.");
        var timestamp = Number(activity.date);
        if (!timestamp || isNaN(timestamp)) errors.push("Choose a valid date.");
        else {
            var drift = Math.abs(timestamp - (Number(now) || Date.now()));
            if (drift > 366 * 86400000) errors.push("The date must be within a year.");
        }
        if (String(activity.notes || "").length > 500) errors.push("Notes must be under 500 characters.");
        if (activity.role !== "funder" && activity.role !== "dhun" && activity.role !== "steward")
            errors.push("Choose a valid role.");
        return { ok: errors.length === 0, errors: errors, title: title };
    }

    function applyOrder(inventory, produceId, quantity, now) {
        var qty = Number(quantity);
        var stock = Number(inventory && inventory.stock);
        if (!produceId) return { ok: false, error: "Choose a produce item." };
        if (!isFinite(qty) || qty <= 0) return { ok: false, error: "Quantity must be at least 1." };
        if (!isFinite(stock)) return { ok: false, error: "This item has no live inventory." };
        if (stock < qty) return { ok: false, error: "Only " + stock + " left in the live inventory." };
        var reference = "FD-" + hash32(produceId + "|" + (Number(now) || Date.now())).toString(36).slice(0, 4).toUpperCase();
        return {
            ok: true,
            reference: reference,
            inventory: {
                stock: stock - qty,
                updatedAt: Number(now) || Date.now(),
                lastOrder: {
                    produceId: produceId,
                    qty: qty,
                    at: Number(now) || Date.now(),
                    reference: reference
                }
            }
        };
    }

    function activitiesForRole(activities, role) {
        return (activities || []).filter(function (activity) { return activity.role === role; })
            .slice().sort(function (a, b) { return Number(a.date) - Number(b.date); });
    }

    function activitiesOnDay(activities, role, timestamp) {
        var key = dateKey(timestamp);
        return activitiesForRole(activities, role).filter(function (activity) {
            return dateKey(activity.date) === key;
        });
    }

    function activityStats(activities, role, now) {
        var target = new Date(Number(now) || Date.now());
        var start = new Date(target.getFullYear(), target.getMonth(), target.getDate());
        var end = new Date(start.getTime() + 7 * 86400000);
        var mine = activitiesForRole(activities, role);
        var stats = { total: mine.length, planned: 0, done: 0, thisWeek: 0 };
        mine.forEach(function (activity) {
            if (activity.status === "done") stats.done += 1;
            else stats.planned += 1;
            var at = Number(activity.date);
            if (at >= start.getTime() && at < end.getTime()) stats.thisWeek += 1;
        });
        return stats;
    }

    function plotFor(produce, zone) {
        var h = hash32(produce && produce.id ? produce.id : "dhun");
        var angle = ((h % 360) / 180) * Math.PI;
        var radius = 0.0011 + ((h >>> 9) % 83) / 100000;
        var lat = zone ? Number(zone.latitude) : 26.711302;
        var lng = zone ? Number(zone.longitude) : 75.5901325;
        return {
            latitude: lat + Math.sin(angle) * radius * 0.82,
            longitude: lng + Math.cos(angle) * radius
        };
    }

    function growerFor(produce, growers, pools) {
        if (!produce || !growers || !growers.length) return null;
        var pool = (pools && pools[produce.zone]) || [];
        if (!pool.length) return growers[0];
        var id = pool[hash32(produce.id) % pool.length];
        for (var i = 0; i < growers.length; ++i) if (growers[i].id === id) return growers[i];
        return growers[0];
    }

    function monthLabel(year, month) {
        return MONTHS_LONG[month] + " " + year;
    }

    function formatDate(timestamp, now) {
        var date = new Date(Number(timestamp) || Date.now());
        if (dateKey(timestamp) === dateKey(now)) return "Today";
        var tomorrow = new Date(Number(now) || Date.now());
        tomorrow.setDate(tomorrow.getDate() + 1);
        if (dateKey(timestamp) === dateKey(tomorrow.getTime())) return "Tomorrow";
        return MONTHS[date.getMonth()] + " " + date.getDate() + " \u00B7 " +
            String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
    }

    return {
        MONTHS: MONTHS,
        MONTHS_LONG: MONTHS_LONG,
        hash32: hash32,
        clamp: clamp,
        dateKey: dateKey,
        monthCells: monthCells,
        formatINR: formatINR,
        timeAgo: timeAgo,
        inSeason: inSeason,
        seasonForMonth: seasonForMonth,
        nextHarvestLabel: nextHarvestLabel,
        filterProduce: filterProduce,
        searchProduces: searchProduces,
        validateActivity: validateActivity,
        applyOrder: applyOrder,
        activitiesForRole: activitiesForRole,
        activitiesOnDay: activitiesOnDay,
        activityStats: activityStats,
        plotFor: plotFor,
        growerFor: growerFor,
        monthLabel: monthLabel,
        formatDate: formatDate
    };
}));
