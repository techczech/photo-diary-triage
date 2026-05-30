import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func thumbnailSchedulerPrioritizesVisibleItems() async {
    let scheduler = ThumbnailScheduler(maxConcurrent: 2)
    let items = makeThumbnailItems(count: 4)

    let firstBatch = await scheduler.enqueue([items[2], items[3]], priority: .background)
    let secondBatch = await scheduler.enqueue([items[0], items[1]], priority: .visible)

    #expect(firstBatch == [items[2], items[3]])
    #expect(secondBatch.isEmpty)

    let afterFirstCompletion = await scheduler.complete(items[2].id)
    let afterSecondCompletion = await scheduler.complete(items[3].id)

    #expect(afterFirstCompletion == [items[0]])
    #expect(afterSecondCompletion == [items[1]])
}

@Test func thumbnailSchedulerAvoidsDuplicateEnqueues() async {
    let scheduler = ThumbnailScheduler(maxConcurrent: 1)
    let items = makeThumbnailItems(count: 2)

    let firstBatch = await scheduler.enqueue([items[0]], priority: .visible)
    let duplicateBatch = await scheduler.enqueue([items[0], items[1]], priority: .visible)
    let afterCompletion = await scheduler.complete(items[0].id)

    #expect(firstBatch == [items[0]])
    #expect(duplicateBatch.isEmpty)
    #expect(afterCompletion == [items[1]])
}

@Test func thumbnailSchedulerPromotesQueuedBackgroundItemsToVisible() async {
    let scheduler = ThumbnailScheduler(maxConcurrent: 1)
    let items = makeThumbnailItems(count: 3)

    let firstBatch = await scheduler.enqueue([items[0], items[1], items[2]], priority: .background)
    let promotionBatch = await scheduler.enqueue([items[2]], priority: .visible)
    let afterCompletion = await scheduler.complete(items[0].id)

    #expect(firstBatch == [items[0]])
    #expect(promotionBatch.isEmpty)
    #expect(afterCompletion == [items[2]])
}

@Test func thumbnailSchedulerResetClearsPendingAndInFlightWork() async {
    let scheduler = ThumbnailScheduler(maxConcurrent: 1)
    let items = makeThumbnailItems(count: 3)

    let firstBatch = await scheduler.enqueue([items[0], items[1]], priority: .background)
    await scheduler.reset()
    let afterReset = await scheduler.enqueue([items[2]], priority: .visible)
    let staleCompletion = await scheduler.complete(items[0].id)

    #expect(firstBatch == [items[0]])
    #expect(afterReset == [items[2]])
    #expect(staleCompletion.isEmpty)
}

private func makeThumbnailItems(count: Int) -> [MediaItem] {
    let sourceRoot = URL(fileURLWithPath: "/tmp/thumbnail-items", isDirectory: true)
    let base = Date(timeIntervalSince1970: 30_000)
    return (0..<count).map { index in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "thumb-\(index).jpg",
            capturedAt: base.addingTimeInterval(Double(index))
        )
    }
}
