.pragma library

/* Dhun Commons · agronomy and conservation advisory.
 *
 * Forecast values arrive from the Open-Meteo-backed agroForecast() slot.
 * Every rule here is advisory: it reads a threshold and suggests action, it
 * never moves funds, changes field state or speaks for the land.
 * Ventusky has no public data API, so the atlas is linked, not embedded. */

var LOCATIONS = [
    { id: "farms", name: "Farms & market garden", short: "Farms", latitude: 26.7088, longitude: 75.5868, zoom: 11 },
    { id: "orchard", name: "Orchards & groves", short: "Orchards", latitude: 26.7122, longitude: 75.5906, zoom: 11 },
    { id: "kitchen", name: "Kitchen garden", short: "Kitchen", latitude: 26.7143, longitude: 75.5936, zoom: 11 },
    { id: "dairy", name: "Dairy & poultry", short: "Dairy", latitude: 26.7077, longitude: 75.5958, zoom: 11 },
    { id: "estate", name: "Dhun estate centre", short: "Estate", latitude: 26.7113, longitude: 75.5901, zoom: 10 }
];

var LAYERS = [
    { id: "rain-3h", label: "Rain · 3 h", short: "Rain" },
    { id: "precipitation-probability", label: "Rain chance", short: "Chance" },
    { id: "temperature-2m", label: "Air temp · 2 m", short: "Temp" },
    { id: "wind-10m", label: "Wind · 10 m", short: "Wind" },
    { id: "wind-gusts", label: "Gusts", short: "Gusts" },
    { id: "humidity-2m", label: "Humidity · 2 m", short: "Humidity" },
    { id: "dew-point", label: "Dew point", short: "Dew" },
    { id: "clouds", label: "Cloud cover", short: "Cloud" },
    { id: "temperature-5cm", label: "Soil temp · 5 cm", short: "Soil" }
];

var ATTRIBUTION = "Forecast data by Open-Meteo (CC BY 4.0). Ventusky opens as a live atlas.";
var LIMIT_NOTE = "Advisory only. Rules read a gridded forecast for one point near the estate; " +
    "they cannot see a specific bed, soil test, spray record or the next week of decisions. " +
    "Check the ground and your own records before acting.";

function locationById(id) {
    for (var i = 0; i < LOCATIONS.length; ++i)
        if (LOCATIONS[i].id === id) return LOCATIONS[i];
    return LOCATIONS[0];
}

function layerById(id) {
    for (var i = 0; i < LAYERS.length; ++i)
        if (LAYERS[i].id === id) return LAYERS[i];
    return LAYERS[0];
}

function embedUrl(locationId, layerId) {
    var location = locationById(locationId);
    var layer = layerById(layerId);
    return "https://embed.ventusky.com/?p=" + location.latitude + ";" + location.longitude + ";" +
        location.zoom + "&l=" + layer.id;
}

function webUrl(locationId, layerId) {
    var location = locationById(locationId);
    var layer = layerById(layerId);
    return "https://www.ventusky.com/?p=" + location.latitude + ";" + location.longitude + ";" +
        location.zoom + "&l=" + layer.id;
}

function googleMapsUrl(locationId) {
    var location = locationById(locationId);
    return "https://www.google.com/maps/@" + location.latitude + "," + location.longitude +
        ",14z/data=!3m1!1e3";
}

function number(value) {
    if (value === null || value === undefined || value === "" || isNaN(Number(value))) return null;
    return Number(value);
}

function num(value, digits) {
    var parsed = number(value);
    if (parsed === null) return "—";
    return parsed.toFixed(digits === undefined ? 0 : digits);
}

function percent(fraction, digits) {
    var parsed = number(fraction);
    if (parsed === null) return "—";
    return (parsed * 100).toFixed(digits === undefined ? 1 : digits) + "%";
}

function conditionLabel(code) {
    var value = Number(code);
    if (value === 0) return "Clear sky";
    if (value === 1) return "Mainly clear";
    if (value === 2) return "Partly cloudy";
    if (value === 3) return "Overcast";
    if (value === 45 || value === 48) return "Fog";
    if (value === 51 || value === 53 || value === 55) return "Drizzle";
    if (value === 56 || value === 57) return "Freezing drizzle";
    if (value === 61) return "Light rain";
    if (value === 63) return "Rain";
    if (value === 65) return "Heavy rain";
    if (value === 66 || value === 67) return "Freezing rain";
    if (value === 71 || value === 73 || value === 75) return "Snow";
    if (value === 77) return "Snow grains";
    if (value === 80 || value === 81) return "Rain showers";
    if (value === 82) return "Violent showers";
    if (value === 85 || value === 86) return "Snow showers";
    if (value === 95) return "Thunderstorm";
    if (value === 96 || value === 99) return "Storm with hail";
    return "Mixed conditions";
}

function directionLabel(degrees) {
    var value = number(degrees);
    if (value === null) return "—";
    var names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    return names[Math.round(((value % 360) / 22.5)) % 16];
}

function parseDate(key) {
    var parts = String(key || "").split("-");
    if (parts.length !== 3) return new Date();
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
}

function dayLabel(key, index) {
    if (Number(index) === 0) return "Today";
    var date = parseDate(key);
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[date.getDay()] + " " + date.getDate();
}

function shortDate(key) {
    var date = parseDate(key);
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return days[date.getDay()] + " " + date.getDate() + " " + months[date.getMonth()];
}

function monthOf(key) {
    var parts = String(key || "").split("-");
    return parts.length === 3 ? Number(parts[1]) : new Date().getMonth() + 1;
}

function mapForecast(payload) {
    var empty = { success: false, error: "No forecast returned.", days: [], current: {}, location: "", label: "" };
    if (!payload || payload.success !== true) {
        if (payload && payload.error) empty.error = String(payload.error);
        return empty;
    }
    var days = [];
    var rawDays = payload.days || [];
    for (var i = 0; i < rawDays.length; ++i) {
        var raw = rawDays[i] || {};
        days.push({
            date: String(raw.date || ""),
            code: number(raw.code),
            tMax: number(raw.tMax),
            tMin: number(raw.tMin),
            apparentMax: number(raw.apparentMax),
            apparentMin: number(raw.apparentMin),
            rain: number(raw.rain),
            chance: number(raw.chance),
            wind: number(raw.wind),
            gust: number(raw.gust),
            direction: number(raw.direction),
            rh: number(raw.rh),
            et0: number(raw.et0),
            radiation: number(raw.radiation),
            uv: number(raw.uv),
            soil: number(raw.soil),
            dew: number(raw.dew),
            cloud: number(raw.cloud)
        });
    }
    var rawCurrent = payload.current || {};
    return {
        success: days.length > 0,
        error: days.length ? "" : "The forecast carried no days.",
        source: payload.source || "open-meteo",
        attribution: payload.attribution || ATTRIBUTION,
        location: payload.location || "",
        label: payload.label || "",
        latitude: number(payload.latitude),
        longitude: number(payload.longitude),
        timezone: payload.timezone || "",
        fetchedAt: number(payload.fetchedAt),
        cached: payload.cached === true,
        current: {
            temp: number(rawCurrent.temp),
            rh: number(rawCurrent.rh),
            rain: number(rawCurrent.rain),
            code: number(rawCurrent.code),
            wind: number(rawCurrent.wind),
            gust: number(rawCurrent.gust),
            direction: number(rawCurrent.direction),
            soil: number(rawCurrent.soil),
            soilTemp: number(rawCurrent.soilTemp),
            observedAt: rawCurrent.observedAt || ""
        },
        days: days
    };
}

/* Agronomy: what the next day asks of field work. */
function dayAdvisories(day) {
    var items = [];
    if (!day) return items;

    if (day.rain >= 25) {
        items.push({
            tone: "red",
            category: "Agronomy",
            title: "Heavy rain · " + num(day.rain, 1) + " mm",
            detail: "Runoff and erosion risk is high. Secure beds, nursery trays and stored inputs before the window.",
            measures: ["Open grass-lined drains and bund outlets",
                       "Cover nursery trays and freshly sown beds",
                       "Delay compost turning, foliar feeds and spraying"]
        });
    } else if (day.rain >= 8) {
        items.push({
            tone: "green",
            category: "Agronomy",
            title: "Soaking rain · " + num(day.rain, 1) + " mm",
            detail: "Enough rain to refill the topsoil. Let the profile absorb it before irrigating again.",
            measures: ["Switch off drip for 24–48 hours and recheck moisture at 10 cm",
                       "Direct-sow millet, pulse or leafy seed into the moist bed",
                       "Mulch paths and beds to hold the rain"]
        });
    } else if (day.rain >= 2) {
        items.push({
            tone: "blue",
            category: "Agronomy",
            title: "Light rain · " + num(day.rain, 1) + " mm",
            detail: "A shallow wetting event. Useful for seedlings, not enough to refill the profile.",
            measures: ["Hold irrigation until the surface dries",
                       "Scout for leaf spots 12–24 hours after the rain",
                       "Keep mulch off direct-seeded rows until emergence"]
        });
    } else if (day.chance >= 60) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Rain may pass · " + num(day.chance) + "% chance",
            detail: "Probability is high but the forecast volume is small. Do not count this as irrigation.",
            measures: ["Keep mulch in place and check the rain gauge",
                       "Delay foliar sprays until the window clears",
                       "Avoid deep tillage that exposes moist soil"]
        });
    }

    if (day.tMax >= 42) {
        items.push({
            tone: "red",
            category: "Agronomy",
            title: "Severe heat · " + num(day.tMax, 1) + " °C",
            detail: "Midday soil and leaf temperatures will stress seedlings, nursery stock and livestock.",
            measures: ["Water before 08:00 and again at dusk if the bed dries",
                       "Shade nursery and young transplants with 50% net",
                       "Move field work out of 11:00–16:00 and keep water for stock"]
        });
    } else if (day.tMax >= 38) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Heat stress · " + num(day.tMax, 1) + " °C",
            detail: "High evaporative demand. Prioritise water for seedlings, fruit trees and dairy shade.",
            measures: ["Irrigate at dawn, not at midday",
                       "Keep 5–7 cm straw mulch on beds and tree basins",
                       "Avoid transplanting and heavy pruning in the afternoon"]
        });
    } else if (day.tMax >= 35) {
        items.push({
            tone: "blue",
            category: "Agronomy",
            title: "Warm day · " + num(day.tMax, 1) + " °C",
            detail: "Manageable heat, but exposed beds will dry faster than the daily average suggests.",
            measures: ["Check the 10 cm moisture before the evening irrigation",
                       "Keep shade on the nursery through midday",
                       "Harvest leafy greens early"]
        });
    }

    if (day.tMin <= 5) {
        items.push({
            tone: "red",
            category: "Agronomy",
            title: "Frost risk · low " + num(day.tMin, 1) + " °C",
            detail: "Clear, cold nights can burn tender growth at dawn, especially low-lying beds.",
            measures: ["Cover sensitive seedlings with straw or shade net at dusk",
                       "Avoid evening irrigation before a cold night",
                       "No burning: use mulch, windbreaks and row cover instead"]
        });
    } else if (day.tMin <= 8) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Cold night · low " + num(day.tMin, 1) + " °C",
            detail: "Growth will slow and cold-sensitive crops may check. Protect the nursery and new transplants.",
            measures: ["Close the nursery sides before sunset",
                       "Hold back on transplanting until the morning warms",
                       "Keep a straw mulch layer over root zones"]
        });
    }

    if (day.gust >= 50) {
        items.push({
            tone: "red",
            category: "Agronomy",
            title: "Damaging gusts · " + num(day.gust) + " km/h",
            detail: "Shade net, trellis and young trees are exposed. Secure structures before the wind arrives.",
            measures: ["Stake tall crops and tension shade net",
                       "Skip spraying and foliar feeds",
                       "Give beehives and poultry a solid windbreak"]
        });
    } else if (day.gust >= 35) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Windy · gusts " + num(day.gust) + " km/h",
            detail: "Spray drift and moisture loss will be higher than the average wind speed implies.",
            measures: ["Spray only in the early morning lull",
                       "Check trellis ties and row-cover edges",
                       "Irrigate early to reduce wind evaporation"]
        });
    }

    var spread = day.tMax !== null && day.dew !== null ? day.tMax - day.dew : null;
    if ((day.rh >= 85 && day.tMax >= 18 && day.tMax <= 32) || (spread !== null && spread <= 2 && day.tMax > 16)) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Fungal pressure · RH " + num(day.rh) + "%",
            detail: "Long damp leaf hours favour blight, mildew and fruit rot. Airflow matters more than another spray.",
            measures: ["Prune lower leaves and open the canopy",
                       "Irrigate at the root, not over the leaf",
                       "Scout early and use neem or bio-fungicide only where scouting shows need"]
        });
    }

    if (day.soil !== null && day.soil < 0.08 && (day.rain || 0) < 5) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "Dry topsoil · " + percent(day.soil),
            detail: "The top 10 cm is near wilting point. Seedbeds and shallow-rooted crops need water first.",
            measures: ["Irrigate seedbeds and nursery at dawn",
                       "Top up mulch to 5–7 cm",
                       "Prioritise seedlings, fruit trees and fodder over established grain"]
        });
    } else if (day.soil !== null && day.soil > 0.34) {
        items.push({
            tone: "blue",
            category: "Agronomy",
            title: "Wet topsoil · " + percent(day.soil),
            detail: "The surface is saturated. Working or grazing it now will compact the soil.",
            measures: ["Keep people, tractors and stock off the beds",
                       "Open drainage furrows before the next rain",
                       "Delay tillage and compost incorporation"]
        });
    }

    if (day.et0 >= 6.5 && (day.rain || 0) < 8) {
        items.push({
            tone: "amber",
            category: "Agronomy",
            title: "High water demand · ET0 " + num(day.et0, 1) + " mm",
            detail: "Reference evapotranspiration is high. The irrigation schedule needs a real top-up, not a token run.",
            measures: ["Add 20–30% to the drip run and check emitter output",
                       "Mulch every exposed bed and tree basin",
                       "Water deeply at dawn instead of lightly at midday"]
        });
    }

    if (day.uv >= 9) {
        items.push({
            tone: "blue",
            category: "Agronomy",
            title: "Very high UV · index " + num(day.uv, 1),
            detail: "Sun exposure is severe for field crews and nursery stock through the middle of the day.",
            measures: ["Shift field work to early morning and late afternoon",
                       "Keep hats, sleeves and water with every crew",
                       "Shade nursery trays and young grafts"]
        });
    }

    if (!items.length) {
        items.push({
            tone: "green",
            category: "Agronomy",
            title: "Workable field day",
            detail: "No threshold is crossed in this forecast. Ordinary seasonal work can proceed.",
            measures: ["Keep the irrigation and mulch routine steady",
                       "Use the morning for transplanting and pruning",
                       "Scout for pests while the canopy is dry"]
        });
    }

    return items.slice(0, 6);
}

/* Conservation: what the week means for soil, water, habitat and fire. */
function conservationAdvisories(days, current) {
    var items = [];
    if (!days || !days.length) return items;

    var rain3 = 0, rainWeek = 0, et0Week = 0, wettest = 0, maxT = -Infinity, minT = Infinity;
    var fireDays = 0, gypsy = 0;
    for (var i = 0; i < days.length; ++i) {
        var day = days[i] || {};
        var rain = day.rain || 0;
        rainWeek += rain;
        if (i < 3) rain3 += rain;
        et0Week += day.et0 || 0;
        if (rain > wettest) wettest = rain;
        if (day.tMax !== null) maxT = Math.max(maxT, day.tMax);
        if (day.tMin !== null) minT = Math.min(minT, day.tMin);
        if (day.tMax >= 38 && day.rh !== null && day.rh <= 25) fireDays += 1;
        if (day.rh !== null && day.rh < 30 && day.gust !== null && day.gust >= 35) gypsy += 1;
    }
    if (maxT === -Infinity) maxT = null;
    if (minT === Infinity) minT = null;

    if (rain3 >= 40) {
        items.push({
            tone: "red",
            category: "Conservation",
            title: "Runoff watch · " + num(rain3) + " mm in 72 h",
            detail: "A concentrated wet window on bare or compacted ground will sheet-flow into the low fields.",
            measures: ["Clear grass-lined drains and check bund outlets before the rain",
                       "Keep residue or mulch on every exposed bed and path",
                       "Read erosion pins and repair any rill before the next event"]
        });
    } else if (wettest >= 25) {
        items.push({
            tone: "red",
            category: "Conservation",
            title: "Erosion risk · " + num(wettest) + " mm day",
            detail: "One heavy day can move more topsoil than a month of ordinary rain.",
            measures: ["Do not till or harrow while the surface is saturated",
                       "Divert roof and path runoff into a settling pit, not the field",
                       "Hold stock off steep and wet paddocks"]
        });
    } else if (rainWeek >= 25) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Sheet-flow watch · " + num(rainWeek) + " mm this week",
            detail: "Repeated wetting keeps the surface sealed. Check where water actually leaves the estate.",
            measures: ["Walk the bund line after the last shower",
                       "Keep grass strips uncut where water crosses paths",
                       "Note any new channel or gully in the field log"]
        });
    }

    var balance = rainWeek - et0Week;
    if (balance <= -20) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Irrigation deficit · " + num(-balance) + " mm",
            detail: "The week's demand outruns its rain. The aquifer and the drip line will carry the difference.",
            measures: ["Stagger irrigation across zones instead of one shallow pass",
                       "Read the borewell meter before and after the week",
                       "Water perennials and shade trees deeply, less often"]
        });
    } else if (balance >= 30) {
        items.push({
            tone: "blue",
            category: "Conservation",
            title: "Surplus water · " + num(balance) + " mm",
            detail: "Rain exceeds reference demand. Use the surplus to recharge rather than to run off.",
            measures: ["Desilt recharge pits and check the roof-runoff inlet",
                       "Open gentle bund cuts so water spreads and soaks",
                       "Keep stock and vehicles off saturated soil to avoid compaction"]
        });
    } else {
        items.push({
            tone: "green",
            category: "Conservation",
            title: "Water budget roughly balanced",
            detail: "Rain and reference evapotranspiration are close this week. The soil should hold its condition.",
            measures: ["Keep the existing mulch and residue cover",
                       "Recheck the rain gauge against the forecast mid-week",
                       "No extra draw on the aquifer is indicated"]
        });
    }

    var today = days[0] || {};
    if (rainWeek < 5 && et0Week >= 20) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Bare-soil exposure · dry week",
            detail: "Little rain with high demand is when exposed topsoil loses carbon and structure fastest.",
            measures: ["Mulch or leave residue on every bare bed and basin",
                       "Avoid turning soil that will not be sown within days",
                       "Shade young trees and nursery stock through midday"]
        });
    }

    var todaySoil = today.soil !== null && today.soil !== undefined ? today.soil
                    : (current && current.soil !== null ? current.soil : null);
    if (todaySoil !== null && todaySoil > 0.34) {
        items.push({
            tone: "blue",
            category: "Conservation",
            title: "Saturated topsoil · " + percent(todaySoil),
            detail: "Traffic and grazing now compact the layer that stores the next rain.",
            measures: ["Keep tractors, carts and stock off the beds",
                       "Work from the path; postpone compost incorporation",
                       "Check drainage outlets stay open through the week"]
        });
    }

    var month = monthOf(today.date);
    if (month >= 6 && month <= 9) {
        items.push({
            tone: "green",
            category: "Conservation",
            title: "Native planting window · monsoon",
            detail: "Monsoon moisture gives khejri, neem, ber and local grasses their best establishment chance.",
            measures: ["Pit-plant saplings where runoff concentrates, not on the crest",
                       "Protect new pits from grazing with brush or thorn enclosures",
                       "Record species and pit count so survival can be audited later"]
        });
    } else if (month >= 10 && month <= 11) {
        items.push({
            tone: "blue",
            category: "Conservation",
            title: "Seed collection window",
            detail: "Dry-season seed from local trees and grasses keeps the seed bank native and adapted.",
            measures: ["Collect from several parents, not one tree",
                       "Label species, date and place in the seed bank",
                       "Sow a nursery batch before the cold nights"]
        });
    } else if (month === 12 || month <= 2) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Winter sapling care",
            detail: "Cold nights and dry air check young transplants even when the soil is not dry.",
            measures: ["Mulch basins and close nursery sides before sunset",
                       "Avoid evening irrigation ahead of a cold night",
                       "Repair tree guards and windbreaks"]
        });
    } else {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Summer survival watering",
            detail: "Pre-monsoon heat is the hardest stretch for young native stock and fodder trees.",
            measures: ["Give new saplings deep water at dawn twice a week",
                       "Keep shade and mulch on nursery beds",
                       "Protect water points and troughs from evaporation"]
        });
    }

    if (fireDays > 0) {
        items.push({
            tone: "red",
            category: "Conservation",
            title: "Fire weather · " + fireDays + (fireDays === 1 ? " day" : " days"),
            detail: "Hot, dry air with any wind carries fire quickly through cured grass and crop residue.",
            measures: ["No burning of residue, trash or bund vegetation",
                       "Clear dry biomass around sheds, hay and the nursery",
                       "Keep a filled water tank and beaters ready; tell neighbours"]
        });
    } else if (gypsy > 0) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Wind-driven fire spread · " + gypsy + (gypsy === 1 ? " day" : " days"),
            detail: "Dry air and gusts will push any ignition across paths and bunds.",
            measures: ["Keep vehicles and machinery off cured grass",
                       "Check the firebreak around stored fodder",
                       "Delay any planned burn until the wind drops"]
        });
    }

    if (maxT !== null && maxT >= 40) {
        items.push({
            tone: "amber",
            category: "Conservation",
            title: "Wildlife water stress · " + num(maxT, 1) + " °C",
            detail: "Birds, small mammals and pollinators need shade and shallow water through the hottest hours.",
            measures: ["Refill wildlife troughs and bird baths at dawn",
                       "Keep shallow water shaded, with stones for perches",
                       "Leave uncut shade patches along field edges"]
        });
    } else if (minT !== null && minT <= 5) {
        items.push({
            tone: "blue",
            category: "Conservation",
            title: "Cold-night shelter · low " + num(minT, 1) + " °C",
            detail: "Cold snaps concentrate wildlife around whatever cover and water remain.",
            measures: ["Keep water points ice-free and clear of netting",
                       "Leave brush piles and grass margins uncut",
                       "Delay hedge trimming until the cold passes"]
        });
    }

    if (rain3 >= 20) {
        items.push({
            tone: "blue",
            category: "Conservation",
            title: "Recharge opportunity · " + num(rain3) + " mm inbound",
            detail: "Water that soaks in near the estate is water available later in the season.",
            measures: ["Desilt recharge pits before the first heavy shower",
                       "Direct clean roof runoff into the pit, not the drain",
                       "Keep the well head covered and the apron clean"]
        });
    }

    return items.slice(0, 6);
}

function windowsFor(days) {
    var windows = { sow: [], spray: [], harvest: [], hold: [] };
    for (var i = 0; i < (days || []).length; ++i) {
        var day = days[i] || {};
        if (day.rain >= 5 && day.rain <= 25 && day.tMax !== null && day.tMax < 38 && day.gust !== null && day.gust < 40)
            windows.sow.push(day.date);
        if ((day.rain || 0) < 1 && day.wind !== null && day.wind < 16 && day.tMax !== null && day.tMax >= 12 && day.tMax <= 34)
            windows.spray.push(day.date);
        if ((day.rain || 0) < 2 && day.rh !== null && day.rh < 75 && day.gust !== null && day.gust < 25)
            windows.harvest.push(day.date);
        if ((day.rain || 0) >= 8) windows.hold.push(day.date);
    }
    return windows;
}

function summarise(days) {
    var summary = {
        rainWeek: 0, rain72: 0, et0Week: 0, maxGust: 0, maxTemp: null, minTemp: null,
        peakChance: 0, dryDays: 0, redDays: 0, watchDays: 0
    };
    if (!days || !days.length) return summary;
    for (var i = 0; i < days.length; ++i) {
        var day = days[i] || {};
        var rain = day.rain || 0;
        summary.rainWeek += rain;
        if (i < 3) summary.rain72 += rain;
        summary.et0Week += day.et0 || 0;
        summary.maxGust = Math.max(summary.maxGust, day.gust || 0);
        if (day.tMax !== null) summary.maxTemp = summary.maxTemp === null ? day.tMax : Math.max(summary.maxTemp, day.tMax);
        if (day.tMin !== null) summary.minTemp = summary.minTemp === null ? day.tMin : Math.min(summary.minTemp, day.tMin);
        summary.peakChance = Math.max(summary.peakChance, day.chance || 0);
        if (rain < 2) summary.dryDays += 1;
        var items = dayAdvisories(day);
        for (var j = 0; j < items.length; ++j) {
            if (i >= 2) break;
            if (items[j].tone === "red") summary.redDays += 1;
            if (items[j].tone === "amber") summary.watchDays += 1;
        }
    }
    return summary;
}
