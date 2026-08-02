import Foundation

private actor OrderDesignPromotionCoordinator {
    static let shared = OrderDesignPromotionCoordinator()
    private var lockedPhotoIds: Set<String> = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func acquire(photoId: String) async {
        guard lockedPhotoIds.contains(photoId) else {
            lockedPhotoIds.insert(photoId)
            return
        }
        await withCheckedContinuation { continuation in
            waiters[photoId, default: []].append(continuation)
        }
    }

    func release(photoId: String) {
        if var queued = waiters[photoId], !queued.isEmpty {
            let next = queued.removeFirst()
            waiters[photoId] = queued.isEmpty ? nil : queued
            next.resume()
        } else {
            lockedPhotoIds.remove(photoId)
        }
    }
}

struct OrderPhotoWorkflowError: Error, Equatable {
    let ownerMessage: String
}

struct OrderPhotoPromotionOutcome {
    let linkedOrder: Order?
    let ownerMessage: String?
}

struct OrderPhotoWorkflow {
    private let repository: any OrderRepository & CakeDesignRepository & OrderPhotoRepository
    private let fileStore: OrderPhotoFileStore
    private let photoLibrary: DesignPhotoLibrary
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any OrderRepository & CakeDesignRepository & OrderPhotoRepository,
        fileStore: OrderPhotoFileStore,
        photoLibrary: DesignPhotoLibrary,
        idGenerator: @escaping () -> String,
        dateProvider: @escaping () -> Date
    ) {
        self.repository = repository
        self.fileStore = fileStore
        self.photoLibrary = photoLibrary
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func add(
        to order: Order,
        kind: OrderPhotoKind,
        imageData: Data,
        caption: String?
    ) async -> Result<Void, OrderPhotoWorkflowError> {
        guard !imageData.isEmpty else {
            return .failure(error("Order photo is required."))
        }

        let now = dateProvider()
        do {
            let photoReference = try await photoLibrary.savePhoto(data: imageData)
            try repository.save(
                OrderPhoto(
                    id: idGenerator(),
                    orderId: order.id,
                    kind: kind,
                    localPhotoPath: photoReference,
                    caption: TextInputFormatting.optionalText(caption ?? ""),
                    createdAt: now,
                    updatedAt: now
                )
            )
            return .success(())
        } catch {
            return .failure(self.error("Order photo could not be saved."))
        }
    }

    func delete(_ photo: OrderPhoto) -> Result<Void, OrderPhotoWorkflowError> {
        do {
            try repository.deleteOrderPhoto(id: photo.id)
            if PhotoKitDesignPhotoLibrary.assetIdentifier(from: photo.localPhotoPath) == nil {
                try fileStore.deleteOrderPhoto(relativePath: photo.localPhotoPath)
            }
            return .success(())
        } catch {
            return .failure(self.error("Order photo could not be deleted."))
        }
    }

    func updateCaption(
        of photo: OrderPhoto,
        to caption: String
    ) -> Result<Void, OrderPhotoWorkflowError> {
        do {
            guard let currentPhoto = try repository.fetchOrderPhoto(id: photo.id) else {
                return .failure(error("Order photo could not be found."))
            }
            try repository.save(
                OrderPhoto(
                    id: currentPhoto.id,
                    orderId: currentPhoto.orderId,
                    kind: currentPhoto.kind,
                    localPhotoPath: currentPhoto.localPhotoPath,
                    caption: TextInputFormatting.optionalText(caption),
                    tags: currentPhoto.tags,
                    isFavorite: currentPhoto.isFavorite,
                    createdAt: currentPhoto.createdAt,
                    updatedAt: dateProvider()
                )
            )
            return .success(())
        } catch {
            return .failure(self.error("Order photo caption could not be saved."))
        }
    }

    func promoteFinalCakePhoto(
        _ photo: OrderPhoto,
        from order: Order,
        name: String,
        notes: String,
        knownDesigns: [CakeDesign]
    ) async -> Result<OrderPhotoPromotionOutcome, OrderPhotoWorkflowError> {
        guard order.id == photo.orderId else {
            return .failure(error("Order could not be found."))
        }
        guard photo.kind == .finalCake else {
            return .failure(error("Only final cake photos can be saved as designs."))
        }
        guard let designName = TextInputFormatting.optionalText(name) else {
            return .failure(error("Design name is required."))
        }
        guard !knownDesigns.contains(where: { $0.originatingOrderPhotoId == photo.id }) else {
            return .failure(error("This final cake photo is already saved as a design."))
        }

        await OrderDesignPromotionCoordinator.shared.acquire(photoId: photo.id)
        defer {
            Task { await OrderDesignPromotionCoordinator.shared.release(photoId: photo.id) }
        }
        switch existingDesignCheck(
            for: photo.id,
            duplicateMessage: "This final cake photo is already saved as a design.",
            failureMessage: "Design history could not be checked."
        ) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }

        let photoPreparation: PreparedDesignPhoto
        do {
            photoPreparation = try await preparePhoto(
                photo,
                unavailableMessage: "Design photo is no longer available in Photos.",
                saveFailureMessage: "Design photo could not be saved to Photos."
            )
        } catch let error as OrderPhotoWorkflowError {
            return .failure(error)
        } catch {
            return .failure(self.error("Design photo could not be saved to Photos."))
        }

        let now = dateProvider()
        let designId = idGenerator()
        let updatedOrder = copy(
            order,
            cakeDesignId: designId,
            updatedAt: now
        )
        let migratedPhoto = migratedPhoto(
            photo,
            reference: photoPreparation.reference,
            updatedAt: now
        )
        let design = CakeDesign(
            id: designId,
            name: designName,
            notes: TextInputFormatting.optionalText(notes),
            photoReference: photoPreparation.reference,
            sourceKind: .ownerMade,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: order.id,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.savePromotedDesign(
                design,
                linking: updatedOrder,
                photo: migratedPhoto,
                cleanupRelativePath: photoPreparation.cleanupRelativePath
            )
            let didCleanup = photoPreparation.cleanupRelativePath.map(cleanupPhoto(at:)) ?? true
            return .success(
                OrderPhotoPromotionOutcome(
                    linkedOrder: updatedOrder,
                    ownerMessage: didCleanup
                        ? nil
                        : "Design saved. The old local photo copy will be removed automatically."
                )
            )
        } catch CakeDesignPromotionError.originatingPhotoAlreadyPromoted {
            return .failure(error("This final cake photo is already saved as a design."))
        } catch {
            return .failure(self.error("Design could not be saved."))
        }
    }

    func addCustomerReference(
        _ photo: OrderPhoto,
        from order: Order,
        tags: String
    ) async -> Result<OrderPhotoPromotionOutcome, OrderPhotoWorkflowError> {
        guard order.id == photo.orderId else {
            return .failure(error("Order could not be found."))
        }
        guard photo.kind == .customerReference else {
            return .failure(error("Only customer reference photos can be added to References."))
        }

        await OrderDesignPromotionCoordinator.shared.acquire(photoId: photo.id)
        defer {
            Task { await OrderDesignPromotionCoordinator.shared.release(photoId: photo.id) }
        }
        switch existingDesignCheck(
            for: photo.id,
            duplicateMessage: "This photo is already in Design References.",
            failureMessage: "Reference history could not be checked."
        ) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }

        let photoPreparation: PreparedDesignPhoto
        do {
            photoPreparation = try await preparePhoto(
                photo,
                unavailableMessage: "Reference photo is no longer available in Photos.",
                saveFailureMessage: "Reference photo could not be saved to Photos."
            )
        } catch let error as OrderPhotoWorkflowError {
            return .failure(error)
        } catch {
            return .failure(self.error("Reference photo could not be saved to Photos."))
        }

        let now = dateProvider()
        let design = CakeDesign(
            id: idGenerator(),
            name: photo.caption ?? "Reference",
            notes: nil,
            photoReference: photoPreparation.reference,
            sourceKind: .customerReference,
            originatingOrderPhotoId: photo.id,
            originatingOrderId: order.id,
            tags: DesignTags.parsed(tags),
            createdAt: now,
            updatedAt: now
        )
        let migratedPhoto = migratedPhoto(
            photo,
            reference: photoPreparation.reference,
            updatedAt: now
        )

        do {
            try repository.savePromotedDesign(
                design,
                linking: order,
                photo: migratedPhoto,
                cleanupRelativePath: photoPreparation.cleanupRelativePath
            )
            let didCleanup = photoPreparation.cleanupRelativePath.map(cleanupPhoto(at:)) ?? true
            return .success(
                OrderPhotoPromotionOutcome(
                    linkedOrder: nil,
                    ownerMessage: didCleanup
                        ? nil
                        : "Reference saved. The old local photo copy will be removed automatically."
                )
            )
        } catch CakeDesignPromotionError.originatingPhotoAlreadyPromoted {
            return .failure(error("This photo is already in Design References."))
        } catch {
            return .failure(self.error("Reference could not be saved."))
        }
    }

    func source(for photo: OrderPhoto) -> CakeDesignPhotoSource? {
        source(forReference: photo.localPhotoPath)
    }

    func source(forReference reference: String) -> CakeDesignPhotoSource? {
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(from: reference) {
            return photoLibrary.containsAsset(identifier: identifier)
                ? .photosAsset(identifier)
                : nil
        }
        let url = fileStore.fileURL(for: reference)
        return FileManager.default.fileExists(atPath: url.path)
            ? .legacyFile(url)
            : nil
    }

    func fileURL(for photo: OrderPhoto) -> URL {
        fileStore.fileURL(for: photo.localPhotoPath)
    }

    func retryPendingCleanups() -> Bool {
        guard let paths = try? repository.fetchPendingDesignPhotoCleanupPaths() else {
            return false
        }
        return paths.reduce(true) { result, path in
            cleanupPhoto(at: path) && result
        }
    }

    private func existingDesignCheck(
        for photoId: String,
        duplicateMessage: String,
        failureMessage: String
    ) -> Result<Void, OrderPhotoWorkflowError> {
        do {
            guard try repository.fetchCakeDesign(originatingOrderPhotoId: photoId) == nil else {
                return .failure(error(duplicateMessage))
            }
            return .success(())
        } catch {
            return .failure(self.error(failureMessage))
        }
    }

    private func preparePhoto(
        _ photo: OrderPhoto,
        unavailableMessage: String,
        saveFailureMessage: String
    ) async throws -> PreparedDesignPhoto {
        if let identifier = PhotoKitDesignPhotoLibrary.assetIdentifier(
            from: photo.localPhotoPath
        ) {
            guard photoLibrary.containsAsset(identifier: identifier) else {
                throw error(unavailableMessage)
            }
            return PreparedDesignPhoto(
                reference: photo.localPhotoPath,
                cleanupRelativePath: nil
            )
        }

        do {
            return PreparedDesignPhoto(
                reference: try await photoLibrary.savePhoto(at: fileURL(for: photo)),
                cleanupRelativePath: photo.localPhotoPath
            )
        } catch {
            throw self.error(saveFailureMessage)
        }
    }

    private func cleanupPhoto(at relativePath: String) -> Bool {
        do {
            try fileStore.deleteOrderPhoto(relativePath: relativePath)
            try repository.deletePendingDesignPhotoCleanupPath(relativePath)
            return true
        } catch {
            return false
        }
    }

    private func migratedPhoto(
        _ photo: OrderPhoto,
        reference: String,
        updatedAt: Date
    ) -> OrderPhoto {
        OrderPhoto(
            id: photo.id,
            orderId: photo.orderId,
            kind: photo.kind,
            localPhotoPath: reference,
            caption: photo.caption,
            tags: photo.tags,
            isFavorite: photo.isFavorite,
            createdAt: photo.createdAt,
            updatedAt: updatedAt
        )
    }

    private func copy(
        _ order: Order,
        cakeDesignId: String,
        updatedAt: Date
    ) -> Order {
        Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: cakeDesignId,
            customerReferencePhotoId: order.customerReferencePhotoId,
            recipeId: order.recipeId,
            recipeScaleMultiplier: order.recipeScaleMultiplier,
            title: order.title,
            customerName: order.customerName,
            status: order.status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            cakeMessage: order.cakeMessage,
            cakeSpecification: order.cakeSpecification,
            quotedPrice: order.quotedPrice,
            depositPaid: order.depositPaid,
            paymentNotes: order.paymentNotes,
            completedAt: order.completedAt,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )
    }

    private func error(_ message: String) -> OrderPhotoWorkflowError {
        OrderPhotoWorkflowError(ownerMessage: message)
    }
}

private struct PreparedDesignPhoto {
    let reference: String
    let cleanupRelativePath: String?
}
