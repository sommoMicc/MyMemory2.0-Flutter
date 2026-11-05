import catalogData from '../catalog/arenas.v1.json' with { type: 'json' };
import { randomInt } from 'node:crypto';

export function validateArenaCatalog(catalog) {
  if (!catalog || catalog.schemaVersion !== 1 || typeof catalog.rankedEnabled !== 'boolean' ||
      !Array.isArray(catalog.arenas) || !Array.isArray(catalog.decks) || !catalog.rules) {
    throw new TypeError('Catalogo arene non valido');
  }
  if (!Number.isSafeInteger(catalog.rules.friendlyRounds) || catalog.rules.friendlyRounds < 1 ||
      !Number.isSafeInteger(catalog.rules.rankedRounds) || catalog.rules.rankedRounds < 1 ||
      !Number.isSafeInteger(catalog.rules.crownsWin) || catalog.rules.crownsWin < 0 ||
      !Number.isSafeInteger(catalog.rules.crownsLoss) || catalog.rules.crownsLoss > 0 ||
      !Number.isSafeInteger(catalog.rules.crownsDraw) ||
      !Number.isSafeInteger(catalog.rules.crownsFloor) || catalog.rules.crownsFloor < 0) {
    throw new TypeError('Regole corone non valide');
  }
  const arenaIds = new Set();
  let previous = -1;
  for (const arena of catalog.arenas) {
    if (!arena || typeof arena.id !== 'string' || !arena.id || typeof arena.name !== 'string' ||
        !Number.isSafeInteger(arena.minCrowns) || arena.minCrowns < 0 || arena.minCrowns <= previous || arenaIds.has(arena.id)) {
      throw new TypeError('Arena non valida o soglie non ordinate');
    }
    previous = arena.minCrowns;
    arenaIds.add(arena.id);
  }
  if (catalog.arenas.length === 0 || catalog.arenas[0].minCrowns !== 0) throw new TypeError('Serve un arena iniziale a 0 corone');
  const deckIds = new Set();
  for (const deck of catalog.decks) {
    if (!deck || typeof deck.id !== 'string' || !deck.id || deckIds.has(deck.id) ||
        typeof deck.name !== 'string' || typeof deck.contentReady !== 'boolean' ||
        !Number.isSafeInteger(deck.price) || deck.price < 0 ||
        (deck.arenaId !== null && !arenaIds.has(deck.arenaId))) throw new TypeError('Deck non valido');
    deckIds.add(deck.id);
    if (deck.id === 'paola' && deck.arenaId !== null) throw new TypeError('Paola deve restare fuori dalle arene');
  }
  if (!deckIds.has('paola')) throw new TypeError('Il catalogo deve conservare Paola');
  for (const arena of catalog.arenas) {
    if (catalog.decks.filter(deck => deck.arenaId === arena.id && deck.price === 0).length < 3) {
      throw new TypeError(`L'arena ${arena.id} deve avere almeno 3 deck gratuiti`);
    }
  }
  return catalog;
}

function deepFreeze(value) {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value)) deepFreeze(child);
  }
  return value;
}

export const ARENA_CATALOG = deepFreeze(validateArenaCatalog(catalogData));

function nonNegativeSafeInteger(value, name) {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(`${name} deve essere un intero sicuro non negativo`);
}

function valid(catalog) { return validateArenaCatalog(catalog); }

export function arenaForCrowns(crowns) {
  nonNegativeSafeInteger(crowns, 'crowns');
  return arenaForCrownsInCatalog(crowns, ARENA_CATALOG);
}

function arenaForCrownsInCatalog(crowns, catalog) {
  const { arenas } = catalog;
  let result = arenas[0];
  for (const arena of arenas) {
    if (arena.minCrowns > crowns) break;
    result = arena;
  }
  return result;
}

export function unlockedArenas(peakCrowns) {
  nonNegativeSafeInteger(peakCrowns, 'peakCrowns');
  return unlockedArenasInCatalog(peakCrowns, ARENA_CATALOG);
}

function unlockedArenasInCatalog(peakCrowns, catalog) {
  return catalog.arenas.filter(arena => arena.minCrowns <= peakCrowns);
}

export function applyCrownResult(crowns, peakCrowns, outcome, catalog = ARENA_CATALOG) {
  nonNegativeSafeInteger(crowns, 'crowns');
  nonNegativeSafeInteger(peakCrowns, 'peakCrowns');
  if (peakCrowns < crowns) throw new RangeError('peakCrowns deve essere maggiore o uguale a crowns');
  const { rules } = valid(catalog);
  const delta = outcome === 'win' ? rules.crownsWin : outcome === 'loss' ? rules.crownsLoss : outcome === 'draw' ? rules.crownsDraw : null;
  if (delta === null) throw new TypeError('Esito non valido: usare win, loss o draw');
  const nextCrowns = Math.max(rules.crownsFloor, crowns + delta);
  if (!Number.isSafeInteger(nextCrowns)) throw new RangeError('Il risultato supera il limite degli interi sicuri');
  const nextPeak = Math.max(peakCrowns, nextCrowns);
  return {
    crowns: nextCrowns,
    peakCrowns: nextPeak,
    currentArenaId: arenaForCrownsInCatalog(nextCrowns, catalog).id,
    unlockedArenaIds: unlockedArenasInCatalog(nextPeak, catalog).map(arena => arena.id),
  };
}

function asSet(decks) {
  if (decks == null) return new Set();
  if (!(Array.isArray(decks) || decks instanceof Set)) throw new TypeError('I deck posseduti devono essere un array o un Set');
  return new Set(decks);
}

export function buildDeckPool(arenaId, playerDecksA = [], playerDecksB = [], catalog = ARENA_CATALOG) {
  const data = valid(catalog);
  if (!data.arenas.some(arena => arena.id === arenaId)) throw new RangeError(`Arena sconosciuta: ${arenaId}`);
  const owned = new Set([...asSet(playerDecksA), ...asSet(playerDecksB)]);
  return data.decks
    .filter(deck => deck.arenaId === arenaId && deck.id !== 'paola' && deck.contentReady && (deck.price === 0 || owned.has(deck.id)))
    .map(deck => deck.id);
}

export function drawRankedDecks(arenaId, playerDecksA = [], playerDecksB = [], catalog = ARENA_CATALOG, rng = randomInt) {
  if (typeof rng !== 'function') throw new TypeError('rng deve essere una funzione');
  const pool = buildDeckPool(arenaId, playerDecksA, playerDecksB, catalog);
  if (pool.length < 3) throw new RangeError(`Pool insufficiente: servono 3 deck giocabili, disponibili ${pool.length}`);
  for (let i = pool.length - 1; i > 0; i--) {
    const j = rng(i + 1);
    if (!Number.isInteger(j) || j < 0 || j > i) throw new RangeError('rng deve produrre un intero entro il limite richiesto');
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, 3);
}
