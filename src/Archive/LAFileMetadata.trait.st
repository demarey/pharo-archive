"
LAFileMetadata centralizes how POSIX permissions and modification times are derived
from a FileReference. It is a trait used by LAArchive and LAArchiveWriter so they share
one implementation. Memory filesystems use sensible defaults; real files reuse their
on-disk metadata.
"
Trait {
	#name : 'LAFileMetadata',
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'accessing' }
LAFileMetadata >> modeFor: aFileReference ofType: typeBits [
	"Answer the full mode (file type bits ORed with permissions). Memory filesystems get
	defaults (0755 dirs / 0644 files); real files use their actual POSIX permissions.

	AE_IFDIR == 16r4000 is inlined to avoid depending on the ArchiveConstants pool."

	| permBits |
	permBits := (aFileReference fileSystem isMemoryFileSystem)
		ifTrue: [ typeBits = 16r4000 ifTrue: [ 8r755 ] ifFalse: [ 8r644 ] ]
		ifFalse: [ aFileReference permissions posixPermission ].
	^ typeBits bitOr: permBits
]

{ #category : 'accessing' }
LAFileMetadata >> mtimeOf: aFileReference [
	"Answer the Unix modification time of aFileReference, or nil when unavailable
	(in particular on memory filesystems)."

	aFileReference fileSystem isMemoryFileSystem ifTrue: [ ^ nil ].
	^ aFileReference modificationTime
		ifNil: [ nil ]
		ifNotNil: [ :modificationTime | modificationTime asUnixTime ]
]
