"
LAArchive is the high-level, in-memory document model of an archive, mirroring the
Compression package's Archive API but backed by libarchive. It keeps a collection of
LAArchiveMember value objects (with their content held in memory) so an archive can
be built, inspected, edited and written/read/extracted to/from disk. Low-level and
streaming operations delegate to LAArchiveReader and LAArchiveWriter.
"
Class {
	#name : 'LAArchive',
	#superclass : 'Object',
	#traits : 'LAFileMetadata',
	#classTraits : 'LAFileMetadata classTrait',
	#instVars : [
		'members',
		'contents',
		'file',
		'isDirty'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'instance creation' }
LAArchive class >> new [

	^ super new initialize
]

{ #category : 'archive operations' }
LAArchive >> addDirectory: aName [

	| member |
	member := LAArchiveMember
		pathname: aName
		size: 0
		mtime: 0
		mode: (AE_IFDIR bitOr: 8r755)
		filetype: AE_IFDIR.
	self addMember: member.
	^ member
]

{ #category : 'archive operations' }
LAArchive >> addFile: aFileReference [

	^ self addFile: aFileReference as: aFileReference basename
]

{ #category : 'archive operations' }
LAArchive >> addFile: aFileReference as: aName [

	| member bytes mtimeValue |
	bytes := aFileReference binaryReadStreamDo: [ :stream | stream contents ].
	mtimeValue := (self mtimeOf: aFileReference) ifNil: [ 0 ].
	member := LAArchiveMember
		pathname: aName
		size: bytes size
		mtime: mtimeValue
		mode: (self modeFor: aFileReference ofType: AE_IFREG)
		filetype: AE_IFREG.
	contents at: aName put: bytes.
	self addMember: member.
	^ member
]

{ #category : 'archive operations' }
LAArchive >> addMember: aMember [

	(self memberNamed: aMember pathname) ifNotNil: [
		LAArchiveError signal: 'Member already present in archive: ', aMember pathname ].
	isDirty := true.
	^ members addLast: aMember
]

{ #category : 'archive operations' }
LAArchive >> addString: aString as: aName [

	| bytes member |
	bytes := aString asByteArray.
	member := LAArchiveMember
		pathname: aName
		size: bytes size
		mtime: 0
		mode: (AE_IFREG bitOr: 8r644)
		filetype: AE_IFREG.
	contents at: aName put: bytes.
	self addMember: member.
	^ member
]

{ #category : 'private' }
LAArchive >> assertSafeRelativePathname: aPathname [
	"Reject archive pathnames that could escape the extraction directory when written
	to disk: absolute paths and any '..' or empty path segment."

	aPathname ifEmpty: [ ^ self ].
	aPathname first = $/
		ifTrue: [ LAArchiveError signal: 'Absolute path in archive entry: ', aPathname ].
	(aPathname splitOn: $/)
		withIndexDo: [ :segment :index |
			segment = '..'
				ifTrue: [ LAArchiveError signal: 'Unsafe path (''..'') in archive entry: ', aPathname ].
			(index > 1 and: [ segment isEmpty ])
				ifTrue: [ LAArchiveError signal: 'Unsafe path (empty segment) in archive entry: ', aPathname ] ]
]

{ #category : 'private' }
LAArchive >> assertHasBackingFile [

	file ifNil: [ LAArchiveError signal: 'LAArchive has no backing file; writeToFile: it first' ].
	^ true
]

{ #category : 'archive operations' }
LAArchive >> contentsOf: aMemberOrName [

	| member |
	member := self member: aMemberOrName.
	member ifNil: [ ^ nil ].
	member isDirectory ifTrue: [ ^ nil ].
	^ contents at: member pathname ifAbsent: [
		file ifNil: [ nil ] ifNotNil: [ (LAArchiveReader onFile: file) contentsOf: member ] ]
]

{ #category : 'extracting' }
LAArchive >> extractAllTo: aDirectoryReference [
	"Extract all entries into aDirectoryReference. When the document model still matches the
	backing file (no edits since readFrom:), entries are extracted natively (fast, preserving
	permissions and timestamps). Once the model diverges from the backing file, the model is
	the source of truth and is extracted instead."

	self assertHasBackingFile.
	aDirectoryReference ensureCreateDirectory.
	isDirty
		ifTrue: [ self extractAllFromModelTo: aDirectoryReference ]
		ifFalse: [ (LAArchiveReader onFile: file) extractTo: aDirectoryReference ].
	^ self
]

{ #category : 'extracting' }
LAArchive >> extractAllFromModelTo: aDirectoryReference [
	"Serialize the document model to a temporary archive and extract it natively, so the
	model determines the extracted content while still going through libarchive's permission
	and timestamp handling. The temporary archive is removed afterwards."

	| tempArchive |
	tempArchive := aDirectoryReference parent / ('__LAArchiveTemp_', UUID new asString, '.zip').
	[ 
		self writeMembersToFile: tempArchive format: #zip.
		(LAArchiveReader onFile: tempArchive) extractTo: aDirectoryReference ]
	ensure: [ tempArchive ensureDeleteAll ]
]

{ #category : 'extracting' }
LAArchive >> extractMember: aMemberOrName to: aDirectoryReference [

	| member bytes target |
	member := self member: aMemberOrName.
	member ifNil: [ ^ nil ].
	member isDirectory ifTrue: [ ^ member ].
	self assertSafeRelativePathname: member pathname.
	bytes := self contentsOf: member.
	target := aDirectoryReference / member pathname.
	target parent ensureCreateDirectory.
	target binaryWriteStreamDo: [ :stream | stream nextPutAll: bytes ].
	^ member
]

{ #category : 'initialization' }
LAArchive >> initialize [

	members := OrderedCollection new.
	contents := Dictionary new.
	file := nil.
	isDirty := false
]

{ #category : 'private' }
LAArchive >> member: aMemberOrName [

	^ (members includes: aMemberOrName)
		ifTrue: [ aMemberOrName ]
		ifFalse: [ self memberNamed: aMemberOrName ]
]

{ #category : 'archive operations' }
LAArchive >> memberNamed: aString [

	^ members detect: [ :each | each pathname = aString ] ifNone: [ nil ]
]

{ #category : 'archive operations' }
LAArchive >> memberNames [

	^ members collect: [ :each | each pathname ]
]

{ #category : 'archive operations' }
LAArchive >> members [

	^ members
]

{ #category : 'accessing' }
LAArchive >> isDirty [

	^ isDirty
]

{ #category : 'archive operations' }
LAArchive >> numberOfMembers [

	^ members size
]

{ #category : 'reading' }
LAArchive >> readFrom: aFileReference [
	"Read an existing archive, auto-detecting its format. Member metadata is snapshotted
	into members; file content is read lazily on demand via contentsOf:."

	self initialize.
	file := aFileReference.
	members addAll: (LAArchiveReader onFile: aFileReference) entries.
	^ self
]

{ #category : 'archive operations' }
LAArchive >> removeMember: aMemberOrName [

	| member |
	member := self member: aMemberOrName.
	member ifNotNil: [
		isDirty := true.
		contents removeKey: member pathname ifAbsent: [ ].
		members remove: member ].
	^ member
]

{ #category : 'archive operations' }
LAArchive >> replaceMember: aMemberOrName with: newMember [

	| member |
	member := self member: aMemberOrName.
	member ifNotNil: [
		isDirty := true.
		members replaceAll: member with: newMember ].
	^ member
]

{ #category : 'archive operations' }
LAArchive >> setContentsOf: aMemberOrName to: aString [

	| member index |
	member := self member: aMemberOrName.
	member ifNil: [ ^ nil ].
	isDirty := true.
	index := members indexOf: member.
	members at: index put: (LAArchiveMember
			pathname: member pathname
			size: aString size
			mtime: member mtime
			mode: member mode
			filetype: member filetype).
	contents at: member pathname put: aString asByteArray.
	^ aString
]

{ #category : 'writing' }
LAArchive >> writeTo: aFileReference format: aFormat [

	self writeMembersToFile: aFileReference format: aFormat.
	file := aFileReference.
	isDirty := false.
	^ self
]

{ #category : 'writing' }
LAArchive >> writeMembersToFile: aFileReference format: aFormat [

	| writer |
	writer := LAArchiveWriter toFile: aFileReference format: aFormat.
	members do: [ :member |
		member isDirectory
			ifTrue: [ writer addDirectory: member pathname mode: member mode ]
			ifFalse: [
				| bytes mtimeValue |
				bytes := self contentsOf: member.
				bytes ifNil: [ LAArchiveError signal: 'no content for member ', member pathname ].
				mtimeValue := member mtime = 0 ifTrue: [ nil ] ifFalse: [ member mtime ].
				writer
					addFileNamed: member pathname
					content: bytes
					mode: member mode
					mtime: mtimeValue ] ].
	writer finish.
	^ self
]

{ #category : 'writing' }
LAArchive >> writeToFile: aFileReference [

	^ self writeTo: aFileReference format: #zip
]
