import XCTest
import WhiteboardCore

final class StrokeDraftTests: XCTestCase {
    func testDraftWithoutMovementProducesOneDot() {
        let draft = StrokeDraft(start: .init(x: 10, y: 20), color: .black)
        XCTAssertEqual(draft.stroke.points, [.init(x: 10, y: 20)])
        XCTAssertEqual(draft.stroke.color, .black)
        XCTAssertEqual(draft.stroke.width, 3)
    }

    func testPointerPointsStayInOrderAndKeepStartingColor() {
        var draft = StrokeDraft(start: .init(x: 10, y: 20), color: .red)
        draft.append(.init(x: 11, y: 21))
        draft.append(.init(x: 12, y: 25))
        XCTAssertEqual(draft.stroke.points, [.init(x: 10, y: 20), .init(x: 11, y: 21), .init(x: 12, y: 25)])
        XCTAssertEqual(draft.stroke.color, .red)
    }

    func testJitterIsFilteredButExactReleasePointIsPreserved() {
        var draft = StrokeDraft(start: .init(x: 10, y: 20), color: .black)
        draft.append(.init(x: 10.1, y: 20))
        XCTAssertEqual(draft.stroke.points.count, 1)
        draft.append(.init(x: 10.1, y: 20), isFinal: true)
        XCTAssertEqual(draft.stroke.points.count, 2)
        XCTAssertEqual(draft.stroke.points.last, .init(x: 10.1, y: 20))
    }

    func testDuplicateAndNonFinitePointsAreIgnored() {
        var draft = StrokeDraft(start: .init(x: 10, y: 20), color: .black)
        draft.append(.init(x: 10, y: 20), isFinal: true)
        draft.append(.init(x: .nan, y: 20))
        draft.append(.init(x: 10, y: .infinity))
        XCTAssertEqual(draft.stroke.points.count, 1)
    }
}
