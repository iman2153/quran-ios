//
//  CompositeSearcherTests.swift
//
//
//  Created by Mohamed Afifi on 2022-01-16.
//

import QuranKit
@testable import QuranTextKit
import SnapshotTesting
import XCTest

class CompositeSearcherTests: XCTestCase {
    private var searcher: CompositeSearcher!
    private var translationsRetriever: LocalTranslationsRetrieverMock!
    private let quran = Quran.madani

    private let translations = [
        TestData.khanTranslation,
        TestData.sahihTranslation,
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()

        translationsRetriever = LocalTranslationsRetrieverMock()
        translationsRetriever.getLocalTranslationsHandler = {
            .value(self.translations)
        }
        let persistence = SQLiteQuranVerseTextPersistence(quran: quran, mode: .arabic, fileURL: TestData.quranTextURL)

        searcher = CompositeSearcher(
            quran: quran,
            quranVerseTextPersistence: persistence,
            localTranslationRetriever: translationsRetriever,
            versePersistenceBuilder: TestData.translationsPersistenceBuilder
        )
    }

    func testAutocompleteNumbers() throws {
        autocompleteNumber("4")
        autocompleteNumber("44")
        autocompleteNumber("444")
        autocompleteNumber("4444")
        autocompleteNumber("3:4")
    }

    private func autocompleteNumber(_ number: String) {
        let result = wait(for: searcher.autocomplete(term: number))
        XCTAssertEqual(result, [SearchAutocompletion(text: number, highlightedRange: number.startIndex ..< number.endIndex)])
    }

    func testSearchNumber1() throws {
        let result = wait(for: searcher.search(for: "1"))
        assertSnapshot(matching: result, as: .json)
    }

    func testSearchNumber33() throws {
        let result = wait(for: searcher.search(for: "33"))
        assertSnapshot(matching: result, as: .json)
    }

    func testSearchNumber605() throws {
        let result = wait(for: searcher.search(for: "605"))
        XCTAssertEqual(result, [])
    }

    func testSearchNumberVerse() throws {
        let result = wait(for: searcher.search(for: "68:1"))
        assertSnapshot(matching: result, as: .json)
    }

    func testAutocompleteSura() throws {
        testAutocomplete(term: "Yu")
    }

    func testSearchOneSura() throws {
        let result = wait(for: searcher.search(for: "Al-Ahzab"))
        assertSnapshot(matching: result, as: .json)
    }

    func testSearchMultipleSura() throws {
        let result = wait(for: searcher.search(for: "Yu"))
        assertSnapshot(matching: result, as: .json)
    }

    func testAutocompleteArabicQuran() throws {
        let term = "لكنا"
        testAutocomplete(term: term)
    }

    func testSearchArabicQuran() throws {
        let term = "لكنا"
        let result = wait(for: searcher.search(for: term))
        assertSnapshot(matching: result, as: .json)
    }

    func testAutocompleteTranslation() throws {
        testAutocomplete(term: "All")
    }

    func testSearchTranslation() throws {
        let result = wait(for: searcher.search(for: "All"))
        assertSnapshot(matching: result, as: .json)
    }

    private func testAutocomplete(term: String, testName: String = #function) {
        let result = wait(for: searcher.autocomplete(term: term))

        // assert the range
        let ranges = result.map { Set($0.map(\.highlightedRange)) }
        XCTAssertEqual(ranges, [term.startIndex ..< term.endIndex])

        // assert the text
        assertSnapshot(matching: result?.map(\.text).sorted(), as: .json, testName: testName)
    }
}