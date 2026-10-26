.pragma library

var paper = "#F4F1E7";
var paperDeep = "#EAE5D7";
var paperWarm = "#F7F2E7";
var white = "#FCFAF3";
var forest = "#11251B";
var forestSoft = "#1C3627";
var forestMid = "#2B4D38";
var ink = "#1B2A21";
var inkSoft = "#3C4B40";
var muted = "#6D7B70";
var mutedLight = "#98A298";
var line = "#D9DFD2";
var lineSoft = "#E7EAE1";
var sage = "#DDE5D2";
var sageLight = "#EDF1E4";
var lime = "#D9EF92";
var limeDeep = "#B9D567";
var gold = "#E0B25C";
var goldLight = "#F4E4C5";
var goldDeep = "#9B6D22";
var clay = "#C76B47";
var clayLight = "#F3DED4";
var clayDeep = "#8F452A";
var danger = "#A8442F";
var blue = "#8FA6B2";
var blueLight = "#E3EAEC";
var charcoal = "#2B302C";

var displayFont = "Georgia";
var uiFont = "Helvetica Neue";
var monoFont = "Menlo";

var radiusSmall = 8;
var radiusMedium = 12;
var radiusLarge = 18;
var radiusXL = 24;
var pagePadding = 30;
var sidebarWidth = 238;
var topBarHeight = 78;

function roleColor(role) {
    if (role === "funder") return gold;
    if (role === "dhun") return limeDeep;
    if (role === "steward") return clay;
    return muted;
}

function roleText(role) {
    if (role === "funder") return "#4C3510";
    if (role === "dhun") return "#20320D";
    if (role === "steward") return "#4D2514";
    return ink;
}

function roleSoft(role) {
    if (role === "funder") return goldLight;
    if (role === "dhun") return sageLight;
    if (role === "steward") return clayLight;
    return sage;
}
