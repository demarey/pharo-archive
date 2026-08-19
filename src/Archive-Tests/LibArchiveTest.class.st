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

{ #category : 'private - reading' }
LibArchiveTest >> listEntriesOf: aPath [

	| libArchive archive entryHolder paths entry |
	libArchive := LibArchive uniqueInstance.
	archive := libArchive read_new.
	[ 
		libArchive read_support_filter_all: archive.
		libArchive read_support_format_all: archive.
		libArchive
			read_open_filenameArg1: archive
			_filename: aPath fullName
			_block_size: 10240.
		paths := OrderedCollection new.
		entryHolder := ArchiveEntry newValueHolder.
		[ (libArchive read_next_headerArg1: archive arg2: entryHolder) = ARCHIVE_OK ] whileTrue: [
			entry := entryHolder value.
			paths add: (self normalizedPathname: (libArchive entry_pathname: entry)).
			libArchive read_data_skip: archive ] ]
	ensure: [ libArchive read_free: archive ].
	^ paths
]

{ #category : 'private - writing' }
LibArchiveTest >> normalizedPathname: aPathname [

	aPathname notEmpty ifFalse: [ ^ aPathname ].
	^ aPathname last = $/
		ifTrue: [ aPathname allButLast ]
		ifFalse: [ aPathname ]
]

{ #category : 'private - memory filesystem' }
LibArchiveTest >> memoryFilesystemFolder [

	| filesystem root |
	filesystem := FileSystem memory.
	root := filesystem / 'payload'.
	root ensureCreateDirectory.
	(root / 'docs') ensureCreateDirectory.
	(root / 'images') ensureCreateDirectory.
	(root / 'hello.txt') writeStreamDo: [ :stream | stream nextPutAll: 'Hello from memory!' ].
	(root / 'docs' / 'notes.md') writeStreamDo: [ :stream | stream nextPutAll: '# Title', String lf, 'Some text.' ].
	(root / 'images' / 'pixel.bin') binaryWriteStreamDo: [ :stream |
		stream nextPutAll: (ByteArray with: 0 with: 1 with: 2 with: 255) ].
	^ root
]

{ #category : 'private - writing' }
LibArchiveTest >> writeArchive: aDirectory to: anOutput format: aFormat [

	| libArchive archive entries |
	libArchive := LibArchive uniqueInstance.
	archive := libArchive write_new.
	[ 
		aFormat = #zip
			ifTrue: [ libArchive write_set_format_zip: archive ]
			ifFalse: [ libArchive write_set_format_pax: archive ].
		libArchive write_open_filenameArg1: archive _file: anOutput fullName.
		entries := aDirectory allChildren
			select: [ :child | (child resolve = aDirectory resolve) not ]
			thenCollect: [ :child | child ].
		entries := entries asSortedCollection: [ :a :b | a pathString <= b pathString ].
		entries do: [ :child |
			| entry typeBits defaultPerms permBits |
			entry := libArchive entry_new.
			libArchive entry_set_pathnameArg1: entry arg2: (child relativeTo: aDirectory) pathString.
			child isDirectory
				ifTrue: [
					typeBits := AE_IFDIR.
					defaultPerms := 8r755 ]
				ifFalse: [
					typeBits := AE_IFREG.
					defaultPerms := 8r644 ].
			permBits := (child fileSystem isMemoryFileSystem)
				ifTrue: [ defaultPerms ]
				ifFalse: [ child permissions posixPermission ].
			libArchive entry_set_modeArg1: entry arg2: (typeBits bitOr: permBits).
			child isFile ifTrue: [
				libArchive entry_set_sizeArg1: entry arg2: child size ].
			libArchive write_headerArg1: archive arg2: entry.
			child isFile ifTrue: [
				libArchive
					write_dataArg1: archive
					arg2: (child binaryReadStreamDo: [ :stream | stream contents ])
					size_t: child size ].
			libArchive write_finish_entry: archive.
			libArchive entry_free: entry ].
		libArchive write_close: archive ]
	ensure: [ libArchive write_free: archive ]
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
LibArchiveTest >> testBuildZipAndTarFromMemoryFilesystem [

	| folder base expected zipEntries tarEntries |
	folder := self memoryFilesystemFolder.
	base := self extractionBaseDirectory.
	base ensureCreateDirectory.
	expected := #('docs' 'docs/notes.md' 'hello.txt' 'images' 'images/pixel.bin').
	[ 
		self writeArchive: folder to: (base / 'test.zip') format: #zip.
		self writeArchive: folder to: (base / 'test.tar') format: #tar.
		zipEntries := self listEntriesOf: (base / 'test.zip').
		tarEntries := self listEntriesOf: (base / 'test.tar').
		self assert: zipEntries asArray equals: expected.
		self assert: tarEntries asArray equals: expected ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LibArchiveTest >> testVersionString [

	self
		assert: (LibArchive uniqueInstance version_string) isNotEmpty
		description: 'libarchive version string should not be empty'
]
