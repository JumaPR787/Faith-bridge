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

import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { WebSocketServer } from "ws";
import { limitKeyterms } from "../src/providers/stt/deepgram.js";
import { keytermsFor } from "../src/providers/translation/glossary.js";

describe("keyterms de Deepgram", () => {
  it("limita la lista (cantidad y tamaño) y elimina duplicados", () => {
    const many = Array.from({ length: 200 }, (_, i) => `término${i}`);
    const out = limitKeyterms(["gracia", "gracia", ...many]);
    expect(out.length).toBeLessThanOrEqual(50);
    expect(out.join("").length).toBeLessThanOrEqual(1200);
    expect(out.filter((t) => t === "gracia")).toHaveLength(1);
  });

  it("incluye los términos del glosario del usuario en el idioma hablado", () => {
    expect(keytermsFor("en", [{ source: "fellowship", target: "comunión" }])).toContain("fellowship");
  });

  it("si Deepgram rechaza los keyterms (400), reintenta sin ellos y la sesión abre", async () => {
    const urls: string[] = [];
    const http = createServer();
    const wss = new WebSocketServer({ noServer: true });
    http.on("upgrade", (req, socket, head) => {
      urls.push(req.url ?? "");
      if ((req.url ?? "").includes("keyterm=")) {
        socket.end("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
        return;
      }
      wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws));
    });
    await new Promise<void>((r) => http.listen(0, "127.0.0.1", r));
    const port = (http.address() as AddressInfo).port;
    const warnings: string[] = [];
    const p = new DeepgramProvider("k", "nova-3", true, `ws://127.0.0.1:${port}/v1/listen`, (m) => warnings.push(m));
    const noop = () => undefined;
    const stream = await p.open({ language: "es", sampleRate: 16000, keyterms: ["gracia"] }, { onResult: noop, onUtteranceEnd: noop, onError: noop, onClose: noop });
    expect(urls).toHaveLength(2);
    expect(urls[0]).toContain("keyterm=gracia");
    expect(urls[1]).not.toContain("keyterm");
    expect(warnings).toHaveLength(1);
    stream.abort();
    wss.close();
    await new Promise((r) => http.close(r));
  });
});
