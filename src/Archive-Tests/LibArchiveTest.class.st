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

{ #category : 'tests' }
LibArchiveTest >> testListZipContents [

	| arc archive entryHolder paths entry |
	arc := LibArchive uniqueInstance.
	archive := arc read_new.
	[ 
		arc read_support_filter_all: archive.
		arc read_support_format_all: archive.
		arc
			read_open_filenameArg1: archive
			_filename: self sampleZip fullName
			_block_size: 10240.
		paths := OrderedCollection new.
		entryHolder := ArchiveEntry newValueHolder.
		[ (arc read_next_headerArg1: archive arg2: entryHolder) = ARCHIVE_OK ] whileTrue: [
			entry := entryHolder value.
			paths add: (arc entry_pathname: entry).
			arc read_data_skip: archive ].
		self assert: paths asArray equals: #('hello.txt' 'subdir/nested.txt' 'subdir/empty.bin') ]
	ensure: [ arc read_free: archive ]
]

{ #category : 'tests' }
LibArchiveTest >> testVersionString [

	self
		assert: (LibArchive uniqueInstance version_string) isNotEmpty
		description: 'libarchive version string should not be empty'
]
