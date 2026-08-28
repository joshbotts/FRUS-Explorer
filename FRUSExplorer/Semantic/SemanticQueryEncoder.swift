// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import llama

/// Frees any still-loaded llama allocations at process exit, because ggml aborts if we do not.
///
/// ## The crash this exists for (measured, not theorized)
///
/// ggml's Metal device registry is a C++ STATIC whose destructor runs in `__cxa_finalize` at
/// `exit()` and asserts its residency sets are empty — `ggml-metal-device.m:954:
/// GGML_ASSERT([rsets->data count] == 0)` in `ggml_metal_device_free`. A live llama context
/// still holds residency sets, so **quitting the Mac app while the encoder is resident** (any
/// time inside the 180 s idle window after a Meaning search) aborted with SIGABRT on the main
/// thread. Reproduced outside the app with a probe linking the same framework slice: loading a
/// model+context and exiting without freeing = exit 134; freeing first = clean exit.
///
/// ## Why `atexit`, and why it is registered only AFTER a successful load
///
/// `exit()` runs `__cxa_atexit`-registered handlers in REVERSE registration order, and C++
/// static destructors register at construction. ggml's Metal statics are constructed during the
/// first model load — so a handler registered AFTER that load runs BEFORE ggml's destructor,
/// which is exactly the window where freeing the context empties the residency sets and the
/// assert never fires. Registering earlier (at app launch, say) would invert the order and fix
/// nothing. The probe verified this ordering empirically before it was relied on.
///
/// `atexit` rather than `applicationWillTerminate` because the assert lives in `exit()`'s own
/// finalization — this handler runs on every path that reaches `__cxa_finalize`, AppKit-mediated
/// or not. iOS never terminates through `exit()` in normal operation (suspend/jetsam), so this
/// is inert there — and harmless.
///
/// The registered closure is the ONE definition of freeing an encoder's allocations:
/// `unload()` reclaims it via `unregister` and runs it, so drain-at-exit and deliberate unload
/// cannot disagree about what freeing means.
final class SemanticEncoderExitGuard: @unchecked Sendable {

    static let shared = SemanticEncoderExitGuard()

    private let lock = NSLock()
    private var nextToken = 0
    private var frees: [Int: () -> Void] = [:]
    private var armed = false

    /// Registers a free action for a live allocation; arms the exit handler on first use.
    ///
    /// - Parameter free: Frees the allocation. Runs at most once — via `unregister` or `drain`.
    /// - Returns: The token `unregister` takes.
    func register(_ free: @escaping () -> Void) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let token = nextToken
        nextToken += 1
        frees[token] = free
        if !armed {
            armed = true
            // Non-capturing closure — converts to the C function pointer `atexit` requires.
            atexit { SemanticEncoderExitGuard.shared.drain() }
        }
        return token
    }

    /// Removes and returns a registered free action, or `nil` if it already ran (or never was).
    func unregister(_ token: Int) -> (() -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return frees.removeValue(forKey: token)
    }

    /// Frees everything still registered. Idempotent; called by the exit handler.
    func drain() {
        lock.lock()
        let pending = frees
        frees = [:]
        lock.unlock()
        for free in pending.values { free() }
    }
}

/// The on-device query encoder: the pinned EmbeddingGemma GGUF through llama.cpp, producing the
/// same 768-d unit vector `llama-embedding` produces for the same text (V-5 s2).
///
/// ## Parity is the contract
///
/// The corpus was embedded through these weights via a llama.cpp-family runtime, and the step-4
/// spike measured a standalone llama.cpp build against the stored corpus vectors at min cosine
/// 0.9999984 over 300 era-stratified chunks with DEFAULT flags — so this wrapper's job is to be
/// the default path, not to tune anything. Every deliberate choice below exists to reproduce what
/// `llama-embedding` does; `QueryEncoderParityTests` pins the output against a committed fixture
/// of that CLI's own vectors for the 25 judged queries, where a miss means a wrapper bug (wrong
/// pooling, missing normalize, wrong prompt, tokenizer misuse), never model drift.
///
/// ## The rules the C API enforces by aborting, enforced here by throwing
///
/// Two `GGML_ASSERT`s abort the process rather than returning an error: batch capacity overflow,
/// and the encoder's `n_ubatch >= n_tokens` (non-causal attention cannot micro-batch, so the whole
/// query must fit one physical batch). This wrapper therefore refuses any query that tokenizes
/// past `maxTokens` — for search queries a refusal the UI can explain beats a silent truncation
/// that quietly searches for half the question.
///
/// ## Load/unload is the memory design
///
/// The spike's CLI-shape ceiling was 639–861 MB; the in-app shape (mmap load, no warmup, encode,
/// release) is what s2 measures. `load()` maps the weights (`LLAMA_LOAD_MODE_MMAP`) and skips the
/// CLI's warmup decode — the first real query pays the page-in instead — and `unload()` releases
/// context and model so the resident cost lives only while the feature is in use.
///
/// Version history:
///   1.0 — V-5 s2: initial implementation
///   1.1 — the Mac quit crash: freeing routed through `SemanticEncoderExitGuard`
actor SemanticQueryEncoder {

    /// The trained context length of the pinned model (GGUF `context_length`); tokenized queries
    /// past this are refused, per the header's abort-rule section.
    static let maxTokens = 2048

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    /// The exit guard's token for the live (model, context) pair — see
    /// `SemanticEncoderExitGuard`; the registered closure is the one definition of freeing.
    private var exitToken: Int?

    /// What can go wrong, in words a caller can show or log.
    enum EncoderError: Error, Equatable {
        /// The model file failed to load — wrong path, damaged file, or out of memory.
        case modelLoadFailed(String)
        /// The context failed to initialize against a loaded model.
        case contextInitFailed
        /// The query tokenized past `maxTokens`.
        case queryTooLong(tokens: Int)
        /// llama_decode returned an error for this batch.
        case encodeFailed(status: Int32)
        /// The context produced no pooled embedding for the sequence.
        case noEmbedding
        /// `encode` was called with no model loaded.
        case notLoaded
    }

    /// Whether the model is currently loaded.
    var isLoaded: Bool { context != nil }

    /// Loads the model and builds an embedding context. Idempotent while loaded.
    ///
    /// - Parameter modelPath: The verified GGUF's path — callers get it from
    ///   `SemanticModelStore.verifiedModelURL()`, which is the only door that vouches for the pin.
    func load(modelPath: String) throws {
        guard context == nil else { return }
        llama_backend_init()

        var modelParams = llama_model_default_params()
        // Pin mmap explicitly rather than trusting AUTO, because lazy paging is the memory design.
        modelParams.load_mode = LLAMA_LOAD_MODE_MMAP
        #if targetEnvironment(simulator)
        // The simulator's paravirtual GPU runs the Metal kernels WRONG, not slowly: measured here,
        // full offload on the iOS simulator returned embeddings at cosine ≈ -0.12 against the CLI
        // reference — garbage with no error raised. llama.cpp's own SwiftUI example forces CPU on
        // the simulator for the same reason. Devices and the Mac keep full Metal offload.
        modelParams.n_gpu_layers = 0
        #endif
        guard let loaded = llama_model_load_from_file(modelPath, modelParams) else {
            throw EncoderError.modelLoadFailed(modelPath)
        }

        var contextParams = llama_context_default_params()
        contextParams.embeddings = true
        // 0 = the model's trained context (2048). Batch sizes must cover the whole query in one
        // physical batch — the encoder path asserts n_ubatch >= n_tokens (see header).
        contextParams.n_ctx = 0
        contextParams.n_batch = UInt32(Self.maxTokens)
        contextParams.n_ubatch = UInt32(Self.maxTokens)
        contextParams.n_seq_max = 1
        // UNSPECIFIED inherits the GGUF's own metadata: mean pooling, non-causal attention.
        // Passing MEAN or CAUSAL here would override what the model declares about itself.
        contextParams.pooling_type = LLAMA_POOLING_TYPE_UNSPECIFIED
        contextParams.attention_type = LLAMA_ATTENTION_TYPE_UNSPECIFIED
        // The raw-API default is 4 threads, not the CLI's physical-core count — set it explicitly.
        let threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads

        guard let created = llama_init_from_model(loaded, contextParams) else {
            llama_model_free(loaded)
            throw EncoderError.contextInitFailed
        }
        model = loaded
        context = created
        // Registered AFTER the successful init on purpose — the guard's ordering argument
        // depends on ggml's Metal statics existing first. The closure owns the freeing.
        exitToken = SemanticEncoderExitGuard.shared.register {
            llama_free(created)
            llama_model_free(loaded)
        }
    }

    /// Releases the context and model. Safe to call when not loaded.
    ///
    /// Freeing happens by reclaiming the exit guard's registered closure and running it, so a
    /// deliberate unload and the at-exit drain can never both free (or disagree about how).
    func unload() {
        if let exitToken, let free = SemanticEncoderExitGuard.shared.unregister(exitToken) {
            free()
        }
        exitToken = nil
        context = nil
        model = nil
    }

    /// Embeds a search query under the pinned QUERY template.
    ///
    /// - Parameter query: The reader's text, appended verbatim to
    ///   `SemanticQueryPrompt.queryPrefix`.
    /// - Returns: The 768-d L2-normalized vector, `[Double]` to match the harness client's shape —
    ///   downstream (`SemanticQuantization.truncate` onward) is identical by construction.
    func encodeQuery(_ query: String) throws -> [Double] {
        try encode(SemanticQueryPrompt.queryPrefix + query)
    }

    /// Embeds already-prefixed text. Internal so the parity test can drive exact CLI prompts.
    func encode(_ text: String) throws -> [Double] {
        guard let context, let model else { throw EncoderError.notLoaded }
        let vocab = llama_model_get_vocab(model)

        // Two-call tokenize: a negative return is the needed size. add_special/parse_special both
        // true — the values common_tokenize passes for embedding input, which is what puts the
        // GGUF-declared EOS on the end.
        let utf8 = Array(text.utf8)
        var tokens = [llama_token](repeating: 0, count: max(16, utf8.count + 8))
        var count = utf8.withUnsafeBufferPointer { buffer in
            llama_tokenize(
                vocab, buffer.baseAddress, Int32(buffer.count),
                &tokens, Int32(tokens.count), true, true)
        }
        if count < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-count))
            count = utf8.withUnsafeBufferPointer { buffer in
                llama_tokenize(
                    vocab, buffer.baseAddress, Int32(buffer.count),
                    &tokens, Int32(tokens.count), true, true)
            }
        }
        guard count > 0 else { throw EncoderError.encodeFailed(status: count) }
        guard count <= Int32(Self.maxTokens) else {
            throw EncoderError.queryTooLong(tokens: Int(count))
        }

        var batch = llama_batch_init(count, 0, 1)
        defer { llama_batch_free(batch) }
        for index in 0..<Int(count) {
            batch.token[index] = tokens[index]
            batch.pos[index] = llama_pos(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]![0] = 0
            // The example marks every token of the sequence for output; with embeddings on, the
            // decode path outputs all tokens anyway — mirror the example rather than economize.
            batch.logits[index] = 1
        }
        batch.n_tokens = count

        // llama_decode routes to the non-causal encode() internally for this architecture — the
        // example's own decision rule is "call decode, let the library route".
        let status = llama_decode(context, batch)
        guard status >= 0 else { throw EncoderError.encodeFailed(status: status) }

        let width = Int(llama_model_n_embd_out(model))
        guard width > 0, let pooled = llama_get_embeddings_seq(context, 0) else {
            throw EncoderError.noEmbedding
        }

        // L2-normalize with double accumulation — common_embd_normalize mode 2, the CLI's default
        // and the one every reference vector in this program was normalized under.
        var sum = 0.0
        for index in 0..<width {
            let value = Double(pooled[index])
            sum += value * value
        }
        let norm = sum > 0 ? 1.0 / sum.squareRoot() : 0.0
        var vector = [Double](repeating: 0, count: width)
        for index in 0..<width {
            vector[index] = Double(pooled[index]) * norm
        }
        return vector
    }
}
