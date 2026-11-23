import { describe, expect, it } from "vitest";
import { Segmenter, type InterimEvent, type SegmentEvent } from "../src/live/segmenter.js";
import type { SttResult } from "../src/providers/stt/types.js";

const r = (text: string, o: Partial<SttResult> = {}): SttResult => ({
  isFinal: true, endOfUtterance: false, text, startMs: 0, endMs: 1000, words: [], ...o,
});

function make() {
  const interims: InterimEvent[] = [];
  const segs: SegmentEvent[] = [];
  const s = new Segmenter((e) => interims.push(e), (e) => segs.push(e));
  return { s, interims, segs };
}

describe("Segmenter", () => {
  it("separa provisionales de confirmados y asigna seq crecientes", () => {
    const { s, interims, segs } = make();
    s.onResult(r("good morn", { isFinal: false }));
    s.onResult(r("Good morning", { startMs: 0, endMs: 900 }));
    s.onResult(r("church", { isFinal: false }));
    s.onResult(r("church.", { startMs: 900, endMs: 1500, endOfUtterance: true }));
    s.onResult(r("Let us", { isFinal: false }));
    expect(segs).toEqual([{ seq: 0, startMs: 0, endMs: 1500, text: "Good morning church.", unclearCount: 0 }]);
    expect(interims.map((i) => i.seq)).toEqual([0, 0, 1]);
    expect(interims[1]!.text).toBe("Good morning church");
  });

  it("no duplica: flush repetido no vuelve a emitir", () => {
    const { s, segs } = make();
    s.onResult(r("Hello", { endOfUtterance: true }));
    s.flush();
    s.onUtteranceEnd();
    expect(segs).toHaveLength(1);
  });

  it("corta segmentos largos sin pausa", () => {
    const { s, segs } = make();
    for (let i = 0; i < 20; i++) s.onResult(r(`word${i}`, { startMs: i * 1000, endMs: (i + 1) * 1000 }));
    expect(segs.length).toBeGreaterThanOrEqual(1);
    expect(segs[0]!.endMs - segs[0]!.startMs).toBeLessThanOrEqual(12_000);
  });

  it("corta en fin de oración con suficientes palabras", () => {
    const { s, segs } = make();
    s.onResult(r("For God so loved the world.", { words: "For God so loved the world.".split(" ").map((w) => ({ word: w, startMs: 0, endMs: 1, confidence: 0.9 })) }));
    expect(segs).toHaveLength(1);
  });

  it("marca palabras de baja confianza como [?] en lugar de inventarlas", () => {
    const { s, segs } = make();
    s.onResult(r("x", {
      endOfUtterance: true,
      words: [
        { word: "Read", startMs: 0, endMs: 1, confidence: 0.98 },
        { word: "Habakuk", startMs: 1, endMs: 2, confidence: 0.2 },
        { word: "zzz", startMs: 2, endMs: 3, confidence: 0.1 },
        { word: "today.", startMs: 3, endMs: 4, confidence: 0.95 },
      ],
    }));
    expect(segs[0]!.text).toBe("Read [?] today.");
    expect(segs[0]!.unclearCount).toBe(2);
  });

  it("aplica desplazamiento de tiempo tras reconexión del proveedor", () => {
    const { s, segs } = make();
    s.setTimeOffset(60_000);
    s.onResult(r("Amen.", { startMs: 100, endMs: 600, endOfUtterance: true }));
    expect(segs[0]!.startMs).toBe(60_100);
  });
});
