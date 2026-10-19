/* FPVManager renderer protocol v1. No dynamic code evaluation. */
(function (root) {
    "use strict";
    const VERSION = 1;
    const LIMITS = Object.freeze({ frame: 128 * 1024, command: 64 * 1024 * 1024,
        transfers: 2, pending: 32, idleMs: 30000, commandMs: 120000 });

    function createBridge({ send, execute, sessionId, limits = LIMITS }) {
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
            reserved -= transfer.length;
            transfers.delete(id);
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
                    if (transfers.has(id) || transfers.size >= limits.transfers ||
                        !Number.isSafeInteger(command.length) || command.length <= 0 ||
                        command.length > limits.command || reserved + command.length > limits.command ||
                        typeof command.commandType !== "string") {
                        throw new Error("Invalid transfer or buffer limit exceeded");
                    }
                    const transfer = { length: command.length, type: command.commandType,
                        received: 0, parts: [], timer: null };
                    transfers.set(id, transfer);
                    reserved += transfer.length;
                    arm(id, transfer);
                    return;
                }
                if (command.type === "transfer-chunk") {
                    const transfer = transfers.get(id);
                    if (!transfer || typeof command.data !== "string" ||
                        command.index !== transfer.parts.length ||
                        command.data.length === 0 ||
                        transfer.received + command.data.length > transfer.length) {
                        throw new Error("Invalid or out-of-order transfer chunk");
                    }
                    transfer.parts.push(command.data);
                    transfer.received += command.data.length;
                    arm(id, transfer);
                    return;
                }
                if (command.type === "transfer-complete") {
                    const transfer = transfers.get(id);
                    if (!transfer || transfer.received !== transfer.length) {
                        throw new Error("Incomplete transfer");
                    }
                    const decoded = JSON.parse(transfer.parts.join(""));
                    if (!valid(decoded) || decoded.requestId !== id || decoded.type !== transfer.type ||
                        decoded.type.startsWith("transfer-") || decoded.type === "cancel-command") {
                        throw new Error("Mismatched transferred command");
                    }
                    release(id);
                    void run(decoded).catch(error => result(id, decoded.type, false, error.message));
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
    root.FPVGlobeBridge = { createBridge, VERSION, LIMITS };
    if (typeof module !== "undefined") module.exports = root.FPVGlobeBridge;
})(typeof globalThis !== "undefined" ? globalThis : window);
