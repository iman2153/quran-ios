//
//  CoreDataNotePersistence.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/8/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import Combine
import CoreData
import CoreDataModel
import CoreDataPersistence
import Foundation
import PromiseKit
import QuranKit
import SystemDependencies

public struct CoreDataNotePersistence: NotePersistence {
    private let context: NSManagedObjectContext
    private let time: SystemTime

    public init(stack: CoreDataStack, time: SystemTime = DefaultSystemTime()) {
        context = stack.newBackgroundContext()
        self.time = time
    }

    public func notes() -> AnyPublisher<[NoteDTO], Never> {
        let request: NSFetchRequest<MO_Note> = MO_Note.fetchRequest()
        request.relationshipKeyPathsForPrefetching = ["verses"]
        request.sortDescriptors = [NSSortDescriptor(key: Schema.Note.modifiedOn, ascending: false)]

        return CoreDataPublisher(request: request, context: context)
            .map { notes in notes.map { NoteDTO($0) } }
            .eraseToAnyPublisher()
    }

    /// Creates or updates an existing note.
    ///
    /// Ensures that a single note is created from the selected verses.
    /// If the selected verses are linked to different notes, and these notes contain verses not included in the selection,
    /// those verses will be incorporated into a unified note. This unified note represents the union of all verses
    /// associated with the notes containing any of the provided `selectedVerses`.
    public func setNote(_ note: String?, verses: [VerseDTO], color: Int) -> Promise<NoteDTO> {
        context.perform { context in
            try createOrUpdateNoteHighlight(verses: verses, color: color, note: note, context: context)
        }
    }

    private func createOrUpdateNoteHighlight(verses selectedVerses: [VerseDTO],
                                             color: Int,
                                             note: String?,
                                             context: NSManagedObjectContext) throws -> NoteDTO
    {
        // get existing notes touching new verses
        let existingNotes = try notes(with: selectedVerses, using: context)

        // take first note or create new note and delete other notes
        let selectedNote = existingNotes.first ?? MO_Note(context: context)
        for oldNote in existingNotes.dropFirst() {
            context.delete(oldNote)
        }

        // early break if no change
        if existingNotes.count == 1 {
            let typedSelectedNote = NoteDTO(selectedNote)
            if typedSelectedNote.verses.isSuperset(of: selectedVerses) &&
                color == typedSelectedNote.color && (note == nil || note == typedSelectedNote.note)
            {
                return typedSelectedNote
            }
        }

        // merge existing notes verses with new verses, this might expand the selected verses
        let existingVerses = existingNotes.flatMap(\.typedVerses).map(VerseDTO.init)
        let allVerses = Set(existingVerses).union(Set(selectedVerses))

        // delete old verses with selected note
        for verse in selectedNote.typedVerses {
            context.delete(verse)
        }

        // associate new verses
        for verse in allVerses {
            let newVerse = MO_Verse(context: context)
            newVerse.ayah = Int32(verse.ayah)
            newVerse.sura = Int32(verse.sura)
            selectedNote.addToVerses(newVerse)
        }

        // merge text of other notes
        let noteText: String
        if let note {
            noteText = note
        } else {
            let existingNotesText = existingNotes.map { $0.note ?? "" }
            noteText = existingNotesText.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        selectedNote.note = noteText
        selectedNote.color = Int32(color)
        selectedNote.createdOn = selectedNote.createdOn ?? time.now
        selectedNote.modifiedOn = time.now

        // save
        try context.save(with: #function)
        return NoteDTO(selectedNote)
    }

    public func removeNotes(with verses: [VerseDTO]) -> Promise<[NoteDTO]> {
        context.perform { context in
            let notes = try notes(with: verses, using: context)
            // get the values before deletion
            let notesToReturn = notes.map { NoteDTO($0) }

            // delete all notes and associated verses
            for note in notes {
                context.delete(note)
                for verse in note.typedVerses {
                    context.delete(verse)
                }
            }
            try context.save(with: #function)
            return notesToReturn
        }
    }

    // MARK: - Helpers

    private func notes(with verses: [VerseDTO], using context: NSManagedObjectContext) throws -> Set<MO_Note> {
        let request = fetchRequestIntersecting(verses)
        request.relationshipKeyPathsForPrefetching = [Schema.Verse.note.rawValue]
        let verses = try context.fetch(request)
        let notes = verses.compactMap(\.note)
        return Set(notes)
    }

    private func fetchRequestIntersecting(_ verses: [VerseDTO]) -> NSFetchRequest<MO_Verse> {
        let fetchRequest: NSFetchRequest<MO_Verse> = MO_Verse.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = [Schema.Verse.note.rawValue]
        let predicates = verses.map { NSPredicate(equals: (Schema.Verse.sura, $0.sura), (Schema.Verse.ayah, $0.ayah)) }
        fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        return fetchRequest
    }
}

private extension NoteDTO {
    init(_ other: MO_Note) {
        self.init(verses: Set(other.typedVerses.map { VerseDTO($0) }),
                  modifiedDate: other.modifiedOn ?? Date(),
                  note: other.note,
                  color: Int(other.color))
    }
}

extension MO_Note {
    var typedVerses: Set<MO_Verse> {
        verses as? Set<MO_Verse> ?? []
    }
}

extension VerseDTO {
    init(_ other: MO_Verse) {
        self.init(ayah: Int(other.ayah), sura: Int(other.sura))
    }
}