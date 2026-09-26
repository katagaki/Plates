import Foundation
import llama

/// What can go wrong while Granite writes, in words a cook can act on.
enum WriterError: LocalizedError {
    case load
    case empty
    case tooLong
    case decode

    var errorDescription: String? {
        switch self {
        case .load: String(culinary: "Generate.Error.WriterLoad")
        case .empty: String(culinary: "Generate.Error.WriterEmpty")
        case .tooLong: String(culinary: "Generate.Error.TooLarge")
        case .decode: String(culinary: "Generate.Error.WriterFailed")
        }
    }
}

/// Runs Granite through llama.cpp and streams back what it writes.
///
/// The settings are the ones the Plates Kitchen evals ran Granite with: a 4,096 token window,
/// up to 1,400 tokens written, and a temperature of 0.7 over llama-server's default top-k, top-p
/// and min-p. The model is loaded for one recipe and let go as soon as it is written, so it is
/// not holding a gigabyte while Apple Intelligence sorts what it wrote.
nonisolated enum RecipeWriter {
    private static let contextLength: UInt32 = 4096
    private static let batchLength: Int32 = 512
    private static let maximumTokens = 1400
    private static let temperature: Float = 0.7

    /// Every piece of text Granite writes, in order. Cancelling the task that reads the stream
    /// stops the model at the next token.
    static func write(instructions: String, prompt: String, model: URL) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try run(instructions: instructions, prompt: prompt, model: model) {
                        continuation.yield($0)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Set up once per process, the first time a recipe is written.
    private static let backend: Void = llama_backend_init()

    private static func run(
        instructions: String,
        prompt: String,
        model url: URL,
        emit: (String) -> Void
    ) throws {
        _ = backend
        var modelParameters = llama_model_default_params()
        #if targetEnvironment(simulator)
        // Simulator's Metal cannot run llama.cpp's kernels, so the model runs on the CPU there.
        modelParameters.n_gpu_layers = 0
        #else
        modelParameters.n_gpu_layers = 99
        #endif
        guard let model = llama_model_load_from_file(url.path, modelParameters) else {
            throw WriterError.load
        }
        defer { llama_model_free(model) }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = contextLength
        contextParameters.n_batch = UInt32(batchLength)
        let threads = Int32(max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
        contextParameters.n_threads = threads
        contextParameters.n_threads_batch = threads
        guard let context = llama_init_from_model(model, contextParameters) else {
            throw WriterError.load
        }
        defer { llama_free(context) }

        guard let vocab = llama_model_get_vocab(model) else { throw WriterError.load }
        var tokens = tokenize(chat(model: model, instructions: instructions, prompt: prompt), vocab: vocab)
        guard !tokens.isEmpty, tokens.count + maximumTokens <= Int(contextLength) else {
            throw WriterError.tooLong
        }

        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw WriterError.load
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))

        var start = 0
        while start < tokens.count {
            try Task.checkCancellation()
            let end = min(start + Int(batchLength), tokens.count)
            try decode(&tokens[start..<end], in: context)
            start = end
        }

        // A character can be split across tokens, so bytes wait here until they make one.
        var pending: [UInt8] = []
        for _ in 0..<maximumTokens {
            try Task.checkCancellation()
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            pending += piece(token, vocab: vocab)
            if let text = String(validating: pending, as: UTF8.self) {
                emit(text)
                pending.removeAll()
            } else if pending.count > 8 {
                emit(String(decoding: pending, as: UTF8.self))
                pending.removeAll()
            }
            try withUnsafeMutablePointer(to: &token) { pointer in
                guard llama_decode(context, llama_batch_get_one(pointer, 1)) == 0 else {
                    throw WriterError.decode
                }
            }
        }
        if !pending.isEmpty {
            emit(String(decoding: pending, as: UTF8.self))
        }
    }

    private static func decode(_ tokens: inout ArraySlice<llama_token>, in context: OpaquePointer) throws {
        try tokens.withUnsafeMutableBufferPointer { buffer in
            guard llama_decode(context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count))) == 0 else {
                throw WriterError.decode
            }
        }
    }

    /// The conversation in the model's own chat template. Granite's template is one llama.cpp
    /// knows by its role markers, and it is written out by hand should that ever not hold.
    private static func chat(model: OpaquePointer, instructions: String, prompt: String) -> String {
        let messages = [("system", instructions), ("user", prompt)]
        let strings = messages.flatMap { [strdup($0.0), strdup($0.1)] }
        defer { strings.forEach { free($0) } }
        let chat = stride(from: 0, to: strings.count, by: 2).map {
            llama_chat_message(role: strings[$0], content: strings[$0 + 1])
        }
        let template = llama_model_chat_template(model, nil)
        var buffer = [CChar](repeating: 0, count: (instructions.utf8.count + prompt.utf8.count) * 2 + 256)
        var length = llama_chat_apply_template(template, chat, chat.count, true, &buffer, Int32(buffer.count))
        if length > Int32(buffer.count) {
            buffer = [CChar](repeating: 0, count: Int(length) + 1)
            length = llama_chat_apply_template(template, chat, chat.count, true, &buffer, Int32(buffer.count))
        }
        guard length > 0 else {
            return messages.map { "<|start_of_role|>\($0.0)<|end_of_role|>\($0.1)<|end_of_text|>\n" }.joined()
                + "<|start_of_role|>assistant<|end_of_role|>"
        }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func tokenize(_ text: String, vocab: OpaquePointer) -> [llama_token] {
        let count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(count) + 8)
        var written = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), true, true)
        if written < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-written))
            written = llama_tokenize(vocab, text, count, &tokens, Int32(tokens.count), true, true)
        }
        return written > 0 ? Array(tokens.prefix(Int(written))) : []
    }

    private static func piece(_ token: llama_token, vocab: OpaquePointer) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 32)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if length < 0 {
            buffer = [CChar](repeating: 0, count: Int(-length))
            length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        return length > 0 ? buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) } : []
    }
}
