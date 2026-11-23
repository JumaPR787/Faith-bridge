import type { Lang } from "../stt/types.js";

export interface GlossaryTerm {
  source: string;
  target: string;
}

/**
 * Glosario cristiano por defecto (inglés → español). Configurable por usuario.
 * Son equivalencias terminológicas comunes; no contienen texto bíblico.
 */
export const DEFAULT_GLOSSARY_EN_ES: ReadonlyArray<readonly [string, string]> = [
  ["grace", "gracia"],
  ["salvation", "salvación"],
  ["discipleship", "discipulado"],
  ["Holy Spirit", "Espíritu Santo"],
  ["apostle", "apóstol"],
  ["resurrection", "resurrección"],
  ["gospel", "evangelio"],
  ["repentance", "arrepentimiento"],
  ["righteousness", "justicia"],
  ["sanctification", "santificación"],
  ["redemption", "redención"],
  ["atonement", "expiación"],
  ["covenant", "pacto"],
  ["faith", "fe"],
  ["forgiveness", "perdón"],
  ["worship", "adoración"],
  ["praise", "alabanza"],
  ["Lord", "Señor"],
  ["Savior", "Salvador"],
  ["Kingdom of God", "Reino de Dios"],
  ["baptism", "bautismo"],
  ["Lord's Supper", "Santa Cena"],
  ["Scripture", "Escritura"],
  ["disciple", "discípulo"],
  ["blessing", "bendición"],
  ["prayer", "oración"],
  ["amen", "amén"],
  ["hallelujah", "aleluya"],
];

/** Nombres de los 66 libros (inglés, español). Solo nombres, sin texto. */
export const BIBLE_BOOKS: ReadonlyArray<readonly [string, string]> = [
  ["Genesis", "Génesis"], ["Exodus", "Éxodo"], ["Leviticus", "Levítico"], ["Numbers", "Números"],
  ["Deuteronomy", "Deuteronomio"], ["Joshua", "Josué"], ["Judges", "Jueces"], ["Ruth", "Rut"],
  ["1 Samuel", "1 Samuel"], ["2 Samuel", "2 Samuel"], ["1 Kings", "1 Reyes"], ["2 Kings", "2 Reyes"],
  ["1 Chronicles", "1 Crónicas"], ["2 Chronicles", "2 Crónicas"], ["Ezra", "Esdras"], ["Nehemiah", "Nehemías"],
  ["Esther", "Ester"], ["Job", "Job"], ["Psalms", "Salmos"], ["Proverbs", "Proverbios"],
  ["Ecclesiastes", "Eclesiastés"], ["Song of Songs", "Cantares"], ["Isaiah", "Isaías"], ["Jeremiah", "Jeremías"],
  ["Lamentations", "Lamentaciones"], ["Ezekiel", "Ezequiel"], ["Daniel", "Daniel"], ["Hosea", "Oseas"],
  ["Joel", "Joel"], ["Amos", "Amós"], ["Obadiah", "Abdías"], ["Jonah", "Jonás"], ["Micah", "Miqueas"],
  ["Nahum", "Nahúm"], ["Habakkuk", "Habacuc"], ["Zephaniah", "Sofonías"], ["Haggai", "Hageo"],
  ["Zechariah", "Zacarías"], ["Malachi", "Malaquías"], ["Matthew", "Mateo"], ["Mark", "Marcos"],
  ["Luke", "Lucas"], ["John", "Juan"], ["Acts", "Hechos"], ["Romans", "Romanos"],
  ["1 Corinthians", "1 Corintios"], ["2 Corinthians", "2 Corintios"], ["Galatians", "Gálatas"],
  ["Ephesians", "Efesios"], ["Philippians", "Filipenses"], ["Colossians", "Colosenses"],
  ["1 Thessalonians", "1 Tesalonicenses"], ["2 Thessalonians", "2 Tesalonicenses"],
  ["1 Timothy", "1 Timoteo"], ["2 Timothy", "2 Timoteo"], ["Titus", "Tito"], ["Philemon", "Filemón"],
  ["Hebrews", "Hebreos"], ["James", "Santiago"], ["1 Peter", "1 Pedro"], ["2 Peter", "2 Pedro"],
  ["1 John", "1 Juan"], ["2 John", "2 Juan"], ["3 John", "3 Juan"], ["Jude", "Judas"], ["Revelation", "Apocalipsis"],
];

function orient(pairs: ReadonlyArray<readonly [string, string]>, source: Lang, target: Lang): GlossaryTerm[] {
  if (source === "en" && target === "es") return pairs.map(([s, t]) => ({ source: s, target: t }));
  if (source === "es" && target === "en") return pairs.map(([t, s]) => ({ source: s, target: t }));
  return [];
}

export function defaultGlossary(source: Lang, target: Lang): GlossaryTerm[] {
  return orient(DEFAULT_GLOSSARY_EN_ES, source, target);
}

export function bibleBooks(source: Lang, target: Lang): GlossaryTerm[] {
  return orient(BIBLE_BOOKS, source, target);
}

/** Términos del glosario en el idioma hablado: sirven como "keyterms" del STT. */
export function keytermsFor(lang: Lang, userTerms: GlossaryTerm[] = []): string[] {
  const base = DEFAULT_GLOSSARY_EN_ES.map(([en, es]) => (lang === "en" ? en : es));
  const set = new Set([...base, ...userTerms.map((t) => t.source)]);
  return [...set].filter((t) => t.length >= 3);
}

/** Une glosario del usuario (prioridad) con el predeterminado, sin duplicados. */
export function mergeGlossary(userTerms: GlossaryTerm[], defaults: GlossaryTerm[]): GlossaryTerm[] {
  const seen = new Set<string>();
  const out: GlossaryTerm[] = [];
  for (const t of [...userTerms, ...defaults]) {
    const k = t.source.trim().toLowerCase();
    if (!k || seen.has(k)) continue;
    seen.add(k);
    out.push({ source: t.source.trim(), target: t.target.trim() });
  }
  return out.slice(0, 200);
}
