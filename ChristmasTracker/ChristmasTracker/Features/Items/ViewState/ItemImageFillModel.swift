//
//  ItemImageFillModel.swift
//  ChristmasTracker
//
//  IMG1-P3: owns the lookup task for one form. The pure ItemImageFillState decides; this model runs
//  the call through LinkPreviewService, then applies the result in the same MainActor turn that
//  finishes the lookup. A new accepted lookup cancels the previous task. Nothing is logged and no
//  error text exists: a failure is simply "no image".
//

import Foundation
import Observation

@MainActor
@Observable
final class ItemImageFillModel {
    private(set) var state: ItemImageFillState

    @ObservationIgnored private var task: Task<Void, Never>?

    var isLooking: Bool { state.isLooking }

    init(mode: ItemFormMode, initialImageUrl: String = "") {
        state = ItemImageFillState(mode: mode, initialImageUrl: initialImageUrl)
    }

    /// Call when editing of the URL field ends. `current` reads the live field values when the
    /// lookup finishes; `apply` receives the image to put in the image field.
    func urlEditingFinished(
        url: String,
        imageUrl: String,
        service: LinkPreviewService,
        current: @escaping @MainActor () -> (url: String, imageUrl: String),
        apply: @escaping @MainActor (String) -> Void
    ) {
        guard let lookup = state.urlEditingFinished(url: url, imageUrl: imageUrl) else { return }
        run(lookup, service: service, current: current, apply: apply)
    }

    var addImageStatus: ItemAddImageStatus { state.addImageStatus }

    /// The explicit "Add image" tap (Edit only; the state decides). Same task handling as the
    /// automatic lookup.
    func addImageRequested(
        url: String,
        imageUrl: String,
        service: LinkPreviewService,
        current: @escaping @MainActor () -> (url: String, imageUrl: String),
        apply: @escaping @MainActor (String) -> Void
    ) {
        guard let lookup = state.addImageRequested(url: url, imageUrl: imageUrl) else { return }
        run(lookup, service: service, current: current, apply: apply)
    }

    private func run(
        _ lookup: ItemImageLookup,
        service: LinkPreviewService,
        current: @escaping @MainActor () -> (url: String, imageUrl: String),
        apply: @escaping @MainActor (String) -> Void
    ) {
        task?.cancel()
        let generation = service.sessionGeneration
        task = Task { [weak self] in
            let result = await service.imageUrl(for: lookup.url)
            guard !Task.isCancelled, let self else { return }
            // A session end looks like "no image"; drop it silently instead of showing a failure.
            guard service.sessionGeneration == generation else {
                state.cancel()
                return
            }
            let now = current()
            if let fill = state.lookupFinished(lookup, result: result, url: now.url, imageUrl: now.imageUrl) {
                apply(fill)
            }
        }
    }

    /// Call for every change of the image field text.
    func imageTextChanged(to text: String) {
        state.imageTextChanged(to: text)
    }

    /// Leaving or saving the form: cancel the task and drop any result.
    func cancel() {
        task?.cancel()
        task = nil
        state.cancel()
    }
}
