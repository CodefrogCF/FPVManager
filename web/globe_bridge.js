/* FPVManager renderer protocol v1. No dynamic code evaluation. */
(function (root) {
    "use strict";
    const VERSION = 1;
    const LIMITS = Object.freeze({ frame: 128 * 1024, command: 64 * 1024 * 1024,
        transfers: 2, pending: 32, idleMs: 30000, commandMs: 120000 });

    function supportsGzipBase64() {
        return typeof DecompressionStream === 'function' &&
            typeof Blob === 'function' && typeof TextDecoder === 'function' &&
            typeof atob === 'function';
    }
    // Use the platform's built-in gzip decoder; no external proxy or script.
    async function expandGzipBase64(encoded, transfer) {
        if (!supportsGzipBase64()) throw new Error('Gzip transport unavailable');
        if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) {
            throw new Error('Invalid base64 transfer');
        }
        const decoded = atob(encoded);
        const bytes = Uint8Array.from(decoded, char => char.charCodeAt(0));
        const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
        const reader = stream.getReader();
        const decoder = new TextDecoder('utf-8', { fatal: true });
        let originalBytes = 0;
        let originalLength = 0;
        const parts = [];
        try {
            while (true) {
                if (transfer.controller.signal.aborted) throw new Error('Transfer cancelled');
                const { value, done } = await reader.read();
                if (done) break;
                originalBytes += value.byteLength;
                if (originalBytes > transfer.originalBytes) throw new Error('Decoded size limit exceeded');
                const text = decoder.decode(value, { stream: true });
                originalLength += text.length;
                if (originalLength > transfer.originalLength) throw new Error('Decoded length limit exceeded');
                parts.push(text);
            }
            const last = decoder.decode();
            originalLength += last.length;
            if (last) parts.push(last);
            if (originalBytes !== transfer.originalBytes ||
                originalLength !== transfer.originalLength) {
                throw new Error('Decoded transfer length mismatch');
            }
            return parts.join('');
        } finally {
            await reader.cancel().catch(() => {});
            reader.releaseLock();
        }
    }

    function createBridge({ send, execute, sessionId, limits = LIMITS, onTransferParsed = null }) {
        const session = sessionId || root.crypto?.randomUUID?.() ||
            `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const transfers = new Map();
        const active = new Map();
        const completed = new Set();
        let reserved = 0;
        let sequence = 0;
        let disposed = false;
        let highestRequest = 0;
        function emit(type, payload = {}) {
            if (disposed) return;
            send(JSON.stringify({ ...payload, source: "fpvmanager-globe",
                version: VERSION, sessionId: session, eventSequence: ++sequence, type }));
        }
        function result(id, type, ok, value) {
            emit("command-result", { requestId: id, commandType: type, ok,
                ...(ok ? { result: value ?? {} } : { error: String(value).slice(0, 2000) }) });
        }
        function remember(id) {
            completed.add(id);
            if (completed.size > 256) completed.delete(completed.values().next().value);
        }
        function release(id) {
            const transfer = transfers.get(id);
            if (!transfer) return;
            clearTimeout(transfer.timer);
            reserved -= transfer.reservation;
            transfers.delete(id);
            transfer.controller.abort();
        }
        function cancel(id) {
            release(id);
            const request = active.get(id);
            if (request) {
                clearTimeout(request.timer);
                request.controller.abort();
                active.delete(id);
            }
            remember(id);
        }
        function arm(id, transfer) {
            clearTimeout(transfer.timer);
            transfer.timer = setTimeout(() => {
                release(id);
                remember(id);
                result(id, transfer.type, false, "Incomplete transfer timed out");
            }, limits.idleMs);
        }
        async function run(command) {
            const id = command.requestId;
            if (active.has(id) || completed.has(id)) return;
            if (active.size >= limits.pending) {
                remember(id);
                result(id, command.type, false, "Too many active commands");
                return;
            }
            const controller = new AbortController();
            const request = { controller, timer: null };
            active.set(id, request);
            request.timer = setTimeout(() => {
                cancel(id);
                result(id, command.type, false, "Renderer command timed out");
            }, limits.commandMs);
            try {
                const value = await execute(command, controller.signal);
                if (!controller.signal.aborted) result(id, command.type, true, value);
            } catch (error) {
                if (!controller.signal.aborted) result(id, command.type, false, error.message || error);
            } finally {
                clearTimeout(request.timer);
                active.delete(id);
                remember(id);
            }
        }
        function valid(command) {
            return command && !Array.isArray(command) && command.version === VERSION &&
                command.sessionId === session && typeof command.type === "string" &&
                typeof command.requestId === "string" && /^[1-9][0-9]{0,15}$/.test(command.requestId);
        }
        function receive(raw) {
            if (disposed || typeof raw !== "string" || raw.length > limits.frame) return;
            let command;
            try {
                command = JSON.parse(raw);
                if (!valid(command)) return;
                const id = command.requestId;
                const number = Number(id);
                if (!Number.isSafeInteger(number) || number < highestRequest - 256) return;
                highestRequest = Math.max(highestRequest, number);
                if (command.type === "cancel-command") { cancel(id); return; }
                if (completed.has(id) || active.has(id)) return;
                if (command.type === "transfer-start") {
                    const gzip = command.encoding === 'gzip-base64';
                    const reservation = gzip ? Math.max(command.originalBytes, command.length) : command.length;
                    if (transfers.has(id) || transfers.size >= limits.transfers ||
                        (command.encoding !== undefined && !gzip) ||
                        (command.flowControl !== undefined && command.flowControl !== true) ||
                        (gzip && (!supportsGzipBase64() ||
                            !['set-uas-zones', 'replace-uas-zones'].includes(command.commandType) ||
                            !Number.isSafeInteger(command.originalLength) ||
                            command.originalLength <= 0 || command.originalLength > limits.command ||
                            !Number.isSafeInteger(command.originalBytes) ||
                            command.originalBytes <= 0 || command.originalBytes > limits.command ||
                            command.length % 4 !== 0)) ||
                        !Number.isSafeInteger(command.length) || command.length <= 0 ||
                        command.length > limits.command || reserved + reservation > limits.command ||
                        typeof command.commandType !== "string") {
                        throw new Error("Invalid transfer or buffer limit exceeded");
                    }
                    const transfer = { length: command.length, type: command.commandType,
                        encoding: gzip ? 'gzip-base64' : 'json',
                        originalLength: gzip ? command.originalLength : command.length,
                        originalBytes: gzip ? command.originalBytes : null,
                        reservation, received: 0, parts: [], timer: null,
                        controller: new AbortController(), decoding: false,
                        flowControl: command.flowControl === true };
                    transfers.set(id, transfer);
                    reserved += reservation;
                    arm(id, transfer);
                    return;
                }
                if (command.type === "transfer-chunk") {
                    const transfer = transfers.get(id);
                    if (!transfer || transfer.decoding || typeof command.data !== "string" ||
                        command.index !== transfer.parts.length ||
                        command.data.length === 0 ||
                        transfer.received + command.data.length > transfer.length) {
                        throw new Error("Invalid or out-of-order transfer chunk");
                    }
                    transfer.parts.push(command.data);
                    transfer.received += command.data.length;
                    arm(id, transfer);
                    if (transfer.flowControl && transfer.parts.length % 8 === 0) {
                        emit('transfer-credit', { requestId: id,
                            nextIndex: transfer.parts.length + 8 });
                    }
                    return;
                }
                if (command.type === "transfer-complete") {
                    const transfer = transfers.get(id);
                    if (!transfer || transfer.decoding || transfer.received !== transfer.length) {
                        throw new Error("Incomplete transfer");
                    }
                    transfer.decoding = true;
                    clearTimeout(transfer.timer);
                    transfer.timer = setTimeout(() => {
                        if (transfers.get(id) !== transfer) return;
                        cancel(id);
                        result(id, transfer.type, false, 'Transfer decode timed out');
                    }, limits.commandMs);
                    // Decoding is asynchronous for gzip. Retain its reservation and
                    // AbortController until complete/cancel/dispose; no stale commits.
                    const decode = async () => {
                        const started = typeof performance !== 'undefined' ? performance.now() : Date.now();
                        try {
                            const text = transfer.encoding === 'gzip-base64'
                                ? await expandGzipBase64(transfer.parts.join(''), transfer)
                                : transfer.parts.join('');
                            if (disposed || transfer.controller.signal.aborted || transfers.get(id) !== transfer) return;
                            const decodedAt = typeof performance !== 'undefined' ? performance.now() : Date.now();
                            const decoded = JSON.parse(text);
                            if (!valid(decoded) || decoded.requestId !== id || decoded.type !== transfer.type ||
                                decoded.type.startsWith('transfer-') || decoded.type === 'cancel-command') {
                                throw new Error('Mismatched transferred command');
                            }
                            const finished = typeof performance !== 'undefined' ? performance.now() : Date.now();
                            const characters = transfer.originalLength;
                            const chunkCount = transfer.parts.length;
                            const transport = transfer.encoding;
                            release(id);
                            if (typeof onTransferParsed === 'function') {
                                try { onTransferParsed({ commandType: decoded.type, characters,
                                    chunkCount, transport, decodeMs: decodedAt - started,
                                    parseMs: finished - decodedAt }); }
                                catch (_) { /* diagnostic observer is best effort */ }
                            }
                            void run(decoded).catch(error => result(id, decoded.type, false, error.message));
                        } catch (error) {
                            if (!disposed && !transfer.controller.signal.aborted && transfers.get(id) === transfer) {
                                cancel(id);
                                result(id, transfer.type, false, error.message || error);
                            }
                        }
                    };
                    void decode();
                    return;
                }
                if (command.type.startsWith("transfer-")) throw new Error("Unknown transfer frame");
                void run(command).catch(error => result(id, command.type, false, error.message));
            } catch (error) {
                if (command && valid(command)) {
                    const type = transfers.get(command.requestId)?.type || command.commandType || command.type;
                    cancel(command.requestId);
                    result(command.requestId, type, false, error.message || error);
                }
            }
        }
        function dispose() {
            disposed = true;
            for (const id of [...transfers.keys(), ...active.keys()]) cancel(id);
        }
        return { receive, emit, dispose };
    }
    root.FPVGlobeBridge = { createBridge, supportsGzipBase64, VERSION, LIMITS };
    if (typeof module !== "undefined") module.exports = root.FPVGlobeBridge;
})(typeof globalThis !== "undefined" ? globalThis : window);
