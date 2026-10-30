import path from "node:path";
import { readJson, writeJsonAtomic } from "../../telegram/lib/relay.mjs";

export const ASKS_FILE = "asks.json";
export const ANSWERS_FILE = "answers.json";
const MAX_ASKS = 30;

export function readAsks(dir) {
  const data = readJson(path.join(dir, ASKS_FILE), { asks: [] });
  const asks = Array.isArray(data) ? data : data?.asks;
  return Array.isArray(asks) ? asks : [];
}

export function writeAsks(dir, asks) {
  writeJsonAtomic(path.join(dir, ASKS_FILE), { version: 1, asks: asks.slice(-MAX_ASKS) });
  return asks.length;
}

export function appendAsk(dir, ask) {
  const asks = readAsks(dir).concat(ask);
  return writeAsks(dir, asks);
}

export function removeAsk(dir, id) {
  const asks = readAsks(dir).filter((entry) => entry.id !== id);
  writeAsks(dir, asks);
  return asks;
}

export function readAnswers(dir) {
  const data = readJson(path.join(dir, ANSWERS_FILE), { answers: [] });
  const answers = Array.isArray(data) ? data : data?.answers;
  return Array.isArray(answers) ? answers : [];
}
