import { describe, expect, it } from "vitest";
import { DeepgramProvider, parseDeepgramResult } from "../src/providers/stt/deepgram.js";

describe("Deepgram adapter", () => {
  it("construye URL con no-retención (mip_opt_out) y sin la clave", () => {
    const p = new DeepgramProvider("SECRET_KEY_123", "nova-3", true);
    const url = p.buildUrl({ language: "es", sampleRate: 16000, keyterms: ["Espíritu Santo", "gracia"] });
    expect(url).toContain("mip_opt_out=true");
    expect(url).toContain("language=es");
    expect(url).toContain("interim_results=true");
    expect(url).toContain("keyterm=Esp%C3%ADritu+Santo");
    expect(url).not.toContain("SECRET_KEY_123");
  });
  it("no envía keyterms si están deshabilitados (costo adicional)", () => {
    const url = new DeepgramProvider("k", "nova-3", false).buildUrl({ language: "en", sampleRate: 16000, keyterms: ["grace"] });
    expect(url).not.toContain("keyterm");
  });
  it("normaliza resultados", () => {
    const r = parseDeepgramResult({
      type: "Results", is_final: true, speech_final: true, start: 1.5, duration: 2,
      channel: { alternatives: [{ transcript: "john 3:16", confidence: 0.9, words: [{ word: "john", punctuated_word: "John", start: 1.5, end: 1.9, confidence: 0.97 }] }] },
    });
    expect(r).toMatchObject({ isFinal: true, endOfUtterance: true, startMs: 1500, endMs: 3500, text: "john 3:16" });
    expect(r!.words[0]!.word).toBe("John");
  });
});
