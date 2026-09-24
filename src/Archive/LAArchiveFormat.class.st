"
LAArchiveFormat is a value object describing the container format used when writing an
archive. It wraps the libarchive format name (e.g. ''zip'', ''pax'' for tar, ''7zip'')
so the writer can configure the underlying archive through archive_write_set_format_by_name.

Because libarchive auto-detects formats when reading, this is only needed on the writing
side. Use the registry (LAArchiveFormat named: #zip) or the convenience accessors such as
LAArchiveFormat zip.
"
Class {
	#name : 'LAArchiveFormat',
	#superclass : 'Object',
	#instVars : [
		'libarchiveName'
	],
	#classInstVars : [
		'namesCache'
	],
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'registry' }
LAArchiveFormat class >> named: aSymbol [
	"Answer the LAArchiveFormat corresponding to aSymbol, or raise LAArchiveError if it is
	not a recognized format."

	| name |
	name := [ self libarchiveNameForSymbol: aSymbol ]
		on: NotFound
		do: [ :exception | LAArchiveError signal: 'Unknown archive format: ', aSymbol asString ].
	^ self new initializeLibarchiveName: name
]

{ #category : 'registry' }
LAArchiveFormat class >> libarchiveNameForSymbol: aSymbol [
	"Answer the libarchive format name for aSymbol, raising NotFound if unknown."

	^ self names at: aSymbol
]

{ #category : 'registry' }
LAArchiveFormat class >> names [
	"Answer the symbol-to-libarchive-name map, built once and cached."

	^ namesCache ifNil: [
		namesCache := Dictionary new
			at: #zip put: 'zip';
			at: #tar put: 'pax';
			at: #sevenzip put: '7zip';
			at: #cpio put: 'cpio';
			at: #gnutar put: 'gnutar';
			at: #ustar put: 'ustar';
			at: #iso9660 put: 'iso9660';
			at: #xar put: 'xar';
			yourself ]
]

{ #category : 'convenience' }
LAArchiveFormat class >> cpio [

	^ self named: #cpio
]

{ #category : 'convenience' }
LAArchiveFormat class >> gnutar [

	^ self named: #gnutar
]

{ #category : 'convenience' }
LAArchiveFormat class >> iso9660 [

	^ self named: #iso9660
]

{ #category : 'convenience' }
LAArchiveFormat class >> sevenZip [

	^ self named: #sevenzip
]

{ #category : 'convenience' }
LAArchiveFormat class >> tar [

	^ self named: #tar
]

{ #category : 'convenience' }
LAArchiveFormat class >> xar [

	^ self named: #xar
]

{ #category : 'convenience' }
LAArchiveFormat class >> zip [

	^ self named: #zip
]

{ #category : 'configuring' }
LAArchiveFormat >> configure: anArchive with: lib [
	"Set this format on anArchive. Answers the libarchive result code (ARCHIVE_OK == 0)."

	^ lib write_set_format_by_nameArg1: anArchive name: self libarchiveName
]

{ #category : 'initialization' }
LAArchiveFormat >> initializeLibarchiveName: aString [

	libarchiveName := aString
]

{ #category : 'accessing' }
LAArchiveFormat >> libarchiveName [

	^ libarchiveName
]
