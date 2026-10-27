.pragma library

var paper = "#F1EDE0";
var paperDeep = "#E4DECC";
var paperWarm = "#F6F1E4";
var white = "#FFFDF6";
var forest = "#0E2118";
var forestSoft = "#183425";
var forestMid = "#2A5039";
var ink = "#15231A";
var inkSoft = "#35443A";
var muted = "#63736A";
var mutedLight = "#8F9B91";
var line = "#D2DAC7";
var lineSoft = "#E3E7DA";
var sage = "#D8E1CB";
var sageLight = "#EAF0DF";
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
var radiusLarge = 20;
var radiusXL = 26;
var pagePadding = 36;
var sidebarWidth = 252;
var topBarHeight = 88;

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
