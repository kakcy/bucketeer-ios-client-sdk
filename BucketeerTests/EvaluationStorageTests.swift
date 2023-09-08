import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class EvaluationStorageTests: XCTestCase {
    func testGetByUserId() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let cacheDao = EvaluationMemCacheDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: cacheDao,
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Check cache
        let expected : [Evaluation] = [.mock1, .mock2]
        XCTAssertEqual(expected, cacheDao.get(key: testUserId1))
        XCTAssertEqual(expected, try? storage.get(userId: testUserId1))
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetByUserIdAndFeatureId() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Should return first evaluation has `feature_id` == Evaluation.mock2.featureId
        let expected = storage.getBy(userId: testUserId1, featureId: Evaluation.mock2.featureId)
        XCTAssertEqual(expected, .mock2)
        wait(for: [expectation], timeout: 0.1)
    }

    func testDeleteAllAndInsert() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 4
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(putHandler: { userId, evaluations in
            // 2. put new data
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            XCTAssertEqual(evaluations, [.mock1, .mock2])
        }, getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        }, deleteAllHandler: { userId in
            // 1. delete all
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
        }, deleteByIdsHandlder: { _ in
            XCTFail("should not called")
        }, startTransactionHandler: { block in
            // Should use use transaction
            try block()
            expectation.fulfill()
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        try storage.deleteAllAndInsert(userId: testUserId1, evaluations: [.mock1, .mock2], evaluatedAt: "1024")
        let expected = try storage.get(userId: testUserId1)
        XCTAssertEqual(expected, [.mock1, .mock2])
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        wait(for: [expectation], timeout: 0.1)
    }

    func testUpdate() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 5
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mock2Updated = Evaluation(
            id: "evaluation2",
            featureId: "feature2",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation2_updated",
            variationName: "variation name2 updated",
            variationValue: "2",
            reason: .init(
                type: .rule,
                ruleId: "rule2"
            )
        )
        var getHandlerAccessCount = 0
        let mockDao = MockEvaluationDao(putHandler: { userId, evaluations in
            // Should update .mock2Updated
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            XCTAssertEqual(evaluations, [mock2Updated])
        }, getHandler: { userId in
            // Should fullfill 2 times
            // 1 for init cache
            // 2 for prepare for update by loading the valid data from database
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            getHandlerAccessCount+=1
            switch getHandlerAccessCount {
            case 1 :
                if userId == testUserId1 {
                    // From the first time in the database has 2 items
                    return [ .mock1, .mock2]
                }
            case 2 :
                if userId == testUserId1 {
                    // .mock2 get some update
                    return [.mock1, mock2Updated]
                }
            // Finally, we should expected only mock2updated in the database
            default: return [mock2Updated]
            }
            return []
        }, deleteAllHandler: { _ in
            XCTFail("should not called")
        }, deleteByIdsHandlder: { ids in
            // Should delete .mock1
            expectation.fulfill()
            XCTAssertEqual(ids, [Evaluation.mock1.id])
        }, startTransactionHandler: { block in
            // Should use use transaction
            try block()
            expectation.fulfill()
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Should update Evaluation.mock2 & remove Evaluation.mock1
        let result = try storage.update(evaluations: [mock2Updated], archivedFeatureIds: [Evaluation.mock1.featureId], evaluatedAt: "1024")
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        XCTAssertEqual(try storage.get(userId: testUserId1), [mock2Updated], "Finally, we should expected only mock2updated in the database")
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetStorageValues() throws {
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao()
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )

        XCTAssertEqual(storage.evaluatedAt, "0", "should = 0")
        XCTAssertEqual(storage.currentEvaluationsId, "")
        XCTAssertFalse(storage.userAttributesUpdated)
        XCTAssertEqual(storage.featureTag, "")

        storage.currentEvaluationsId = "evaluationIdForTest"
        storage.userAttributesUpdated = true
        storage.featureTag = "featureTagForTest"
        let result = try storage.update(evaluations: [.mock2], archivedFeatureIds: [Evaluation.mock1.featureId], evaluatedAt: "1024")
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        XCTAssertEqual(storage.currentEvaluationsId, "evaluationIdForTest")
        XCTAssertTrue(storage.userAttributesUpdated)
        XCTAssertEqual(storage.featureTag, "featureTagForTest")
    }
}