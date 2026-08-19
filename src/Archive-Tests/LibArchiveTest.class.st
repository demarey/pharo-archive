Class {
	#name : 'LibArchiveTest',
	#superclass : 'TestCase',
	#pools : [
		'ArchiveConstants'
	],
	#category : 'Archive-Tests',
	#package : 'Archive-Tests'
}

{ #category : 'private - files' }
LibArchiveTest >> extractionBaseDirectory [

	^ FileLocator temp / ('archiveTest-', UUID new asString)
]

{ #category : 'private - files' }
LibArchiveTest >> resourcesFolder [

	^ FileSystem workingDirectory / 'resources'
]

{ #category : 'private - files' }
LibArchiveTest >> sampleZip [

	| folder zip |
	folder := self resourcesFolder.
	self assert: folder exists description: ('No resources folder found. Run this test with the working directory at the pharo-archive repository root. (', folder fullName, ')').
	zip := folder / 'sample.zip'.
	self assert: zip exists description: ('sample.zip not found in resources: ', zip fullName).
	^ zip
]

{ #category : 'private - extraction' }
LibArchiveTest >> writeEntry: aPathname fromArchive: libArchive archive: archive into: aDirectory [

	| target buffer bytes stream |
	target := aDirectory / aPathname.
	target parent ensureCreateDirectory.
	buffer := ByteArray new: 65536.
	stream := target binaryWriteStream.
	[ (bytes := libArchive read_dataArg1: archive arg2: buffer size_t: buffer size) > 0 ]
		whileTrue: [ stream nextPutAll: (buffer copyFrom: 1 to: bytes) ].
	stream close
]

{ #category : 'tests' }
LibArchiveTest >> testListZipContents [

	| libArchive archive entryHolder paths entry |
	libArchive := LibArchive uniqueInstance.
	archive := libArchive read_new.
	[ 
		libArchive read_support_filter_all: archive.
		libArchive read_support_format_all: archive.
		libArchive
			read_open_filenameArg1: archive
			_filename: self sampleZip fullName
			_block_size: 10240.
		paths := OrderedCollection new.
		entryHolder := ArchiveEntry newValueHolder.
		[ (libArchive read_next_headerArg1: archive arg2: entryHolder) = ARCHIVE_OK ] whileTrue: [
			entry := entryHolder value.
			paths add: (libArchive entry_pathname: entry).
			libArchive read_data_skip: archive ].
		self assert: paths asArray equals: #('hello.txt' 'subdir/nested.txt' 'subdir/empty.bin') ]
	ensure: [ libArchive read_free: archive ]
]

{ #category : 'tests' }
LibArchiveTest >> testExtractZipContents [

	| libArchive archive entryHolder entry dir pathname |
	libArchive := LibArchive uniqueInstance.
	archive := libArchive read_new.
	dir := self extractionBaseDirectory.
	dir ensureCreateDirectory.
	[ 
		libArchive read_support_filter_all: archive.
		libArchive read_support_format_all: archive.
		libArchive
			read_open_filenameArg1: archive
			_filename: self sampleZip fullName
			_block_size: 10240.
		entryHolder := ArchiveEntry newValueHolder.
		[ (libArchive read_next_headerArg1: archive arg2: entryHolder) = ARCHIVE_OK ] whileTrue: [
			entry := entryHolder value.
			pathname := libArchive entry_pathname: entry.
			self writeEntry: pathname fromArchive: libArchive archive: archive into: dir ].
		self assert: (dir / 'hello.txt') contents equals: 'Hello, libarchive!', String lf.
		self assert: (dir / 'subdir/nested.txt') contents equals: 'nested content', String lf.
		self assert: (dir / 'subdir/empty.bin') size equals: 0 ]
	ensure: [
		libArchive read_free: archive.
		dir ensureDeleteAll ]
]

{ #category : 'tests' }
LibArchiveTest >> testVersionString [

	self
		assert: (LibArchive uniqueInstance version_string) isNotEmpty
		description: 'libarchive version string should not be empty'
]
