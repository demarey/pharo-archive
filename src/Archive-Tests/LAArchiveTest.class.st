"
Tests for the libarchive-backed archive library (LAArchive, LAArchiveReader,
LAArchiveWriter, LAArchiveMember). Covers the document model, streaming read/write,
extraction (content, permissions, timestamps), directory-tree packing, and behavior
originally present in Compression-Tests/ZipArchiveTest.
"
Class {
	#name : 'LAArchiveTest',
	#superclass : 'TestCase',
	#instVars : [
		'fs',
		'subdir',
		'contentFile',
		'base'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'Archive-Tests',
	#package : 'Archive-Tests'
}

{ #category : 'running' }
LAArchiveTest >> setUp [

	super setUp.
	fs := FileSystem memory.
	subdir := fs / 'test-zip-dir'.
	subdir ensureCreateDirectory.
	contentFile := subdir / 'file.txt'.
	contentFile writeStreamDo: [ :stream | stream nextPutAll: 'file contents' ].
	base := self baseTempDirectory.
	base ensureCreateDirectory
]

{ #category : 'running' }
LAArchiveTest >> tearDown [

	super tearDown.
	base ensureDeleteAll
]

{ #category : 'helpers' }
LAArchiveTest >> baseTempDirectory [

	^ FileLocator temp / ('pharoArchiveTest-', UUID new asString)
]

{ #category : 'helpers' }
LAArchiveTest >> expectedEntries [

	^ #('docs' 'docs/notes.md' 'hello.txt' 'images' 'images/pixel.bin')
]

{ #category : 'helpers' }
LAArchiveTest >> memoryFilesystemFolder [

	| filesystem root |
	filesystem := FileSystem memory.
	root := filesystem / 'payload'.
	root ensureCreateDirectory.
	(root / 'docs') ensureCreateDirectory.
	(root / 'images') ensureCreateDirectory.
	(root / 'hello.txt') writeStreamDo: [ :stream | stream nextPutAll: 'Hello from memory!' ].
	(root / 'docs' / 'notes.md') writeStreamDo: [ :stream | stream nextPutAll: '# Title', String lf ].
	(root / 'images' / 'pixel.bin') binaryWriteStreamDo: [ :stream |
		stream nextPutAll: (ByteArray with: 0 with: 1 with: 2 with: 255) ].
	^ root
]

{ #category : 'tests' }
LAArchiveTest >> testEntriesRoundTripTar [

	self assert: (self readArchiveOfFormat: #tar) equals: self expectedEntries
]

{ #category : 'tests' }
LAArchiveTest >> testEntriesRoundTripZip [

	self assert: (self readArchiveOfFormat: #zip) equals: self expectedEntries
]

{ #category : 'tests' }
LAArchiveTest >> testDocumentModelRoundTrip [

	| archive out extracted readBack |
	archive := LAArchive new.
	archive
		addDirectory: 'docs';
		addString: 'Hello document!' as: 'hello.txt';
		addString: ('# Title', String lf) as: 'docs/notes.md'.
	self assert: archive numberOfMembers equals: 3.
	out := base / 'doc.zip'.
	extracted := base / 'out'.
	archive writeToFile: out.
	readBack := LAArchive new readFrom: out.
	self assert: (readBack memberNames asSortedCollection asArray)
		equals: #('docs' 'docs/notes.md' 'hello.txt').
	self assert: (readBack contentsOf: 'hello.txt') equals: 'Hello document!' asByteArray.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'hello.txt') contents equals: 'Hello document!'.
	self assert: (extracted / 'docs') isDirectory
]

{ #category : 'tests' }
LAArchiveTest >> testContentsOfEntry [

	| folder writer reader hello |
	folder := self memoryFilesystemFolder.
	writer := LAArchiveWriter toFile: (base / 'x.zip') format: #zip.
	writer addEntriesFromDirectory: folder.
	writer finish.
	reader := LAArchiveReader onFile: (base / 'x.zip').
	hello := reader entries detect: [ :e | e pathname = 'hello.txt' ].
	self assert: (reader contentsOf: hello) equals: 'Hello from memory!' asByteArray.
	self assert: hello isFile.
	self assert: hello size equals: 'Hello from memory!' size
]

{ #category : 'tests' }
LAArchiveTest >> testExtractToDirectoryPreservesContentAndPermissions [

	| folder writer extracted hello |
	folder := self memoryFilesystemFolder.
	extracted := base / 'out'.
	writer := LAArchiveWriter toFile: (base / 'x.zip') format: #zip.
	writer addEntriesFromDirectory: folder.
	writer finish.
	(LAArchiveReader onFile: (base / 'x.zip')) extractTo: extracted.
	hello := extracted / 'hello.txt'.
	self assert: hello exists.
	self assert: hello contents equals: 'Hello from memory!'.
	self assert: (extracted / 'docs') isDirectory.
	self assert: (extracted / 'docs' / 'notes.md') contents equals: '# Title', String lf.
	OSPlatform current isWindows ifFalse: [
		self assert: (hello permissions posixPermission) equals: 8r644.
		self assert: ((extracted / 'docs') permissions posixPermission) equals: 8r755 ]
]

{ #category : 'tests' }
LAArchiveTest >> testExtractUsesRealFilePermissions [

	| folder writer extracted perms |
	OSPlatform current isWindows ifTrue: [ ^ self ].
	folder := base / 'payload'.
	folder ensureCreateDirectory.
	(folder / 'secret.txt') writeStreamDo: [ :stream | stream nextPutAll: 'secret' ].
	(folder / 'secret.txt') permissions: (FileSystemPermission posixPermissions: 8r600).
	extracted := base / 'out'.
	writer := LAArchiveWriter toFile: (base / 'x.tar') format: #tar.
	writer addEntriesFromDirectory: folder.
	writer finish.
	(LAArchiveReader onFile: (base / 'x.tar')) extractTo: extracted.
	perms := (extracted / 'secret.txt') permissions posixPermission.
	self assert: perms equals: 8r600.
	self assert: (extracted / 'secret.txt') contents equals: 'secret'
]

{ #category : 'tests' }
LAArchiveTest >> testReadBackAndExtractAll [

	| archive out extracted readBack |
	archive := LAArchive new.
	archive
		addDirectory: 'docs';
		addString: 'content one' as: 'docs/a.txt';
		addString: 'content two' as: 'root.txt'.
	out := base / 'doc.zip'.
	extracted := base / 'extracted'.
	archive writeToFile: out.
	readBack := LAArchive new readFrom: out.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'docs' / 'a.txt') contents equals: 'content one'.
	self assert: (extracted / 'root.txt') contents equals: 'content two'
]

{ #category : 'helpers' }
LAArchiveTest >> archiveWithBackingFile [

	| archive out |
	archive := LAArchive new.
	archive
		addDirectory: 'docs';
		addString: 'original content' as: 'docs/a.txt';
		addString: 'root content' as: 'root.txt'.
	out := base / 'doc.zip'.
	archive writeToFile: out.
	^ LAArchive new readFrom: out
]

{ #category : 'tests' }
LAArchiveTest >> testExtractAllReflectsSetContents [

	| readBack extracted |
	readBack := self archiveWithBackingFile.
	extracted := base / 'out'.
	readBack setContentsOf: 'docs/a.txt' to: 'edited content'.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'docs' / 'a.txt') contents equals: 'edited content'.
	self assert: (extracted / 'root.txt') contents equals: 'root content'
]

{ #category : 'tests' }
LAArchiveTest >> testExtractAllReflectsAddedMember [

	| readBack extracted |
	readBack := self archiveWithBackingFile.
	extracted := base / 'out'.
	readBack addString: 'new file' as: 'new.txt'.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'new.txt') contents equals: 'new file'.
	self assert: (extracted / 'root.txt') contents equals: 'root content'
]

{ #category : 'tests' }
LAArchiveTest >> testExtractAllReflectsRemoval [

	| readBack extracted |
	readBack := self archiveWithBackingFile.
	extracted := base / 'out'.
	readBack removeMember: 'root.txt'.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'root.txt') exists not.
	self assert: (extracted / 'docs' / 'a.txt') contents equals: 'original content'
]

{ #category : 'tests' }
LAArchiveTest >> testExtractAllUnchangedUsesNativePath [

	| readBack extracted |
	readBack := self archiveWithBackingFile.
	extracted := base / 'out'.
	self deny: readBack isDirty.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'root.txt') contents equals: 'root content'.
	self assert: (extracted / 'docs' / 'a.txt') contents equals: 'original content'
]

{ #category : 'tests' }
LAArchiveTest >> testWriteToReconcilesModel [

	| readBack extracted |
	readBack := self archiveWithBackingFile.
	extracted := base / 'out'.
	readBack setContentsOf: 'docs/a.txt' to: 'edited content'.
	self assert: readBack isDirty.
	readBack writeToFile: (base / 'doc2.zip').
	self deny: readBack isDirty.
	readBack extractAllTo: extracted.
	self assert: (extracted / 'docs' / 'a.txt') contents equals: 'edited content'
]

{ #category : 'helpers' }
LAArchiveTest >> readFilePathsOfFormat: aFormat [

	| folder writer reader filePaths |
	folder := self memoryFilesystemFolder.
	writer := LAArchiveWriter
		toFile: (base / 'test.archive')
		format: aFormat.
	writer addEntriesFromDirectory: folder.
	writer finish.
	reader := LAArchiveReader onFile: (base / 'test.archive').
	filePaths := reader entries
		reject: #isDirectory
		thenCollect: [ :e | e pathname ].
	^ filePaths asSet
]

{ #category : 'helpers' }
LAArchiveTest >> readArchiveOfFormat: aFormat [

	| folder writer reader |
	folder := self memoryFilesystemFolder.
	writer := LAArchiveWriter
		toFile: (base / 'test.archive')
		format: aFormat.
	writer addEntriesFromDirectory: folder.
	writer finish.
	reader := LAArchiveReader onFile: (base / 'test.archive').
	^ (reader entries collect: [ :e | e pathname ]) asArray
]

{ #category : 'tests' }
LAArchiveTest >> testAddFileWithoutNameUsesBasename [

	| realFile archive member received |
	realFile := base / 'some-file.txt'.
	realFile writeStreamDo: [ :stream | stream nextPutAll: 'payload' ].
	received := base / 'read-back'.
	archive := LAArchive new.
	archive addFile: realFile.
	member := archive memberNamed: 'some-file.txt'.
	self assert: member isNotNil.
	archive extractMember: member to: received.
	self assert: (received / 'some-file.txt') exists.
	self assert: (received / 'some-file.txt') contents equals: 'payload'
]

{ #category : 'tests' }
LAArchiveTest >> testAddDuplicateMemberRaises [

	| archive |
	archive := LAArchive new.
	archive addString: 'first' as: 'dup.txt'.
	self should: [ archive addString: 'second' as: 'dup.txt' ] raise: LAArchiveError
]

{ #category : 'tests' }
LAArchiveTest >> testAddNonExistentFileRaises [

	self should: [ LAArchive new addFile: (base / 'missing-file.txt') ]
		raise: FileDoesNotExistException
]

{ #category : 'tests' }
LAArchiveTest >> testAddTreeWithContentShouldSucceed [

	| out writer extracted |
	out := base / 'out.zip'.
	writer := LAArchiveWriter toFile: out format: #zip.
	writer addEntriesFromDirectory: subdir parent.
	writer finish.
	extracted := base / 'extracted'.
	(LAArchiveReader onFile: out) extractTo: extracted.
	self assert: (extracted / 'test-zip-dir' / 'file.txt') exists.
	self assert: (extracted / 'test-zip-dir' / 'file.txt') contents equals: 'file contents'
]

{ #category : 'tests' }
LAArchiveTest >> testAddTreeWithSubDirectoriesShouldSucceed [

	| out writer extracted subSubDir |
	subSubDir := subdir / 'subSubDir'.
	subSubDir ensureCreateDirectory.
	(subSubDir / 'fileInSubSubDir') ensureCreateFile.
	out := base / 'out.zip'.
	writer := LAArchiveWriter toFile: out format: #zip.
	writer addEntriesFromDirectory: subdir parent.
	writer finish.
	extracted := base / 'extracted'.
	(LAArchiveReader onFile: out) extractTo: extracted.
	self assert: (extracted / 'test-zip-dir' / 'subSubDir') isDirectory.
	self assert: (extracted / 'test-zip-dir' / 'subSubDir' / 'fileInSubSubDir') isFile.
	self deny: (extracted / 'subSubDir') isDirectory
]

{ #category : 'tests' }
LAArchiveTest >> testManyFilesSmoke [

	| out writer reader count |
	out := base / 'many.zip'.
	writer := LAArchiveWriter toFile: out format: #zip.
	1 to: 500 do: [ :i |
		writer
			addFileNamed: ('file-', i asString)
			content: ('content ', i asString) asByteArray ].
	writer finish.
	reader := LAArchiveReader onFile: out.
	count := reader entries size.
	self assert: count equals: 500
]

{ #category : 'tests' }
LAArchiveTest >> testCanUnzipFromStream [

	| stream writer bytes reader extracted |
	stream := (ByteArray new: 0) writeStream.
	writer := LAArchiveWriter toStream: stream format: #zip.
	writer addFileNamed: 'hello.txt' content: 'file contents' asByteArray.
	writer addDirectory: 'docs'.
	writer finish.
	bytes := stream contents.
	reader := LAArchiveReader onBytes: bytes.
	extracted := base / 'extracted'.
	reader extractTo: extracted.
	self assert: (extracted / 'hello.txt') exists.
	self assert: (extracted / 'hello.txt') contents equals: 'file contents'.
	self assert: (extracted / 'docs') isDirectory
]

{ #category : 'tests' }
LAArchiveTest >> testFilePermissionsFromRealFile [

	| realFile archive member |
	OSPlatform current isWindows ifTrue: [ ^ self ].
	realFile := base / 'secret.txt'.
	realFile writeStreamDo: [ :stream | stream nextPutAll: 'secret' ].
	realFile permissions: (FileSystemPermission posixPermissions: 8r600).
	archive := LAArchive new.
	archive addFile: realFile as: 'secret.txt'.
	member := archive memberNamed: 'secret.txt'.
	self assert: (member mode bitAnd: 8r7777) equals: 8r600
]

{ #category : 'tests' }
LAArchiveTest >> testWriteRoundTripFormats [
	"Round-trip general formats. Directory encoding differs per format (7zip reorders,
	cpio omits dir entries), so we compare the set of file pathnames."

	self assert: (self readFilePathsOfFormat: #sevenzip)
		equals: #('docs/notes.md' 'hello.txt' 'images/pixel.bin') asSet.
	self assert: (self readFilePathsOfFormat: #cpio)
		equals: #('docs/notes.md' 'hello.txt' 'images/pixel.bin') asSet
]

{ #category : 'tests' }
LAArchiveTest >> testWriteToFileDuring [

	| out |
	out := base / 'x.zip'.
	LAArchiveWriter writeToFile: out format: #zip during: [ :writer |
		writer addFileNamed: 'a.txt' content: 'hi' asByteArray ].
	self assert: out exists.
	self assert: (LAArchiveReader onFile: out) entries size equals: 1
]

{ #category : 'tests' }
LAArchiveTest >> testWriteToStreamDuring [

	| stream reader |
	stream := (ByteArray new: 0) writeStream.
	LAArchiveWriter writeToStream: stream format: #zip during: [ :writer |
		writer addFileNamed: 'a.txt' content: 'hi' asByteArray ].
	reader := LAArchiveReader onBytes: stream contents.
	self assert: reader entries size equals: 1
]

{ #category : 'tests' }
LAArchiveTest >> testDuringEnsuresFinishOnException [

	| out |
	out := base / 'x.zip'.
	self should: [
		LAArchiveWriter writeToFile: out format: #zip during: [ :writer |
			writer addFileNamed: 'a.txt' content: 'hi' asByteArray.
			self error: 'boom' ] ]
		raise: Error.
	self assert: out exists.
	self assert: (LAArchiveReader onFile: out) entries size equals: 1
]

{ #category : 'tests' }
LAArchiveTest >> testUnknownFormatRaises [

	self should: [ LAArchiveFormat named: #doesNotExist ] raise: LAArchiveError.
	self assert: LAArchiveFormat zip libarchiveName equals: 'zip'.
	self assert: LAArchiveFormat tar libarchiveName equals: 'pax'
]

{ #category : 'tests' }
LAArchiveTest >> testRemoveMember [

	| archive |
	archive := LAArchive new.
	archive
		addString: 'alpha' as: 'a.txt';
		addString: 'beta' as: 'b.txt'.
	self assert: archive numberOfMembers equals: 2.
	archive removeMember: 'a.txt'.
	self assert: archive numberOfMembers equals: 1.
	self assert: (archive memberNamed: 'a.txt') isNil.
	self assert: (archive contentsOf: 'b.txt') equals: 'beta' asByteArray
]

{ #category : 'tests' }
LAArchiveTest >> testReplaceMember [

	| archive replacement |
	archive := LAArchive new.
	archive addString: 'alpha' as: 'a.txt'.
	replacement := LAArchiveMember
		pathname: 'a.txt'
		size: 3
		mtime: 0
		mode: (AE_IFREG bitOr: 8r644)
		filetype: AE_IFREG.
	archive replaceMember: 'a.txt' with: replacement.
	self assert: archive numberOfMembers equals: 1.
	self assert: (archive members first) == replacement.
	self assert: (archive memberNamed: 'a.txt') == replacement
]

{ #category : 'tests' }
LAArchiveTest >> testExtractSingleMember [

	| archive received |
	archive := LAArchive new.
	archive
		addString: 'payload-one' as: 'one.txt';
		addDirectory: 'sub';
		addString: 'payload-two' as: 'sub/two.txt'.
	received := base / 'out'.
	received ensureCreateDirectory.
	archive extractMember: 'one.txt' to: received.
	self assert: (received / 'one.txt') exists.
	self assert: (received / 'one.txt') contents equals: 'payload-one'.
	self deny: (received / 'sub') exists
]

{ #category : 'helpers' }
LAArchiveTest >> assertUnsafeMemberRejected: aName [

	| archive received |
	archive := LAArchive new.
	archive addString: 'evil' as: aName.
	received := base / 'out'.
	received ensureCreateDirectory.
	self should: [ archive extractMember: aName to: received ] raise: LAArchiveError
]

{ #category : 'tests' }
LAArchiveTest >> testExtractMemberRejectsTraversal [

	self assertUnsafeMemberRejected: '../evil.txt'
]

{ #category : 'tests' }
LAArchiveTest >> testExtractMemberRejectsAbsolutePath [

	self assertUnsafeMemberRejected: '/etc/evil.txt'
]

{ #category : 'helpers' }
LAArchiveTest >> runShellCommand: aCommandString [

	^ LibC uniqueInstance runCommand: aCommandString
]

{ #category : 'tests' }
LAArchiveTest >> testReadsSymlinkEntry [

	| archiveFile members |
	(OSPlatform current isWindows
		or: [ (self runShellCommand: 'command -v tar >/dev/null 2>&1') isZero not ])
		ifTrue: [ ^ self ].
	archiveFile := base / 'sample.tar'.
	(base / 'real.txt') writeStreamDo: [ :stream | stream nextPutAll: 'real content' ].
	self runShellCommand: ('cd ', '''', base fullName, '''', ' && ln -s real.txt link.txt').
	self runShellCommand: ('cd ', '''', base fullName, '''', ' && tar -cf sample.tar link.txt real.txt').
	members := (LAArchiveReader onFile: archiveFile) entries.
	self assert: (members anySatisfy: [ :e | e pathname = 'link.txt' and: [ e isSymlink and: [ e symlink = 'real.txt' ] ] ])
]

