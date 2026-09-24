"
A LAArchiveMember is an immutable, high-level description of a single entry (a file,
directory or symlink) inside an archive. It is built from the raw FFI archive_entry
handle and exposes pathname, size, mtime, mode, filetype and convenience predicates
such as isDirectory, isFile and isSymlink.
"
Class {
	#name : 'LAArchiveMember',
	#superclass : 'Object',
	#instVars : [
		'pathname',
		'size',
		'mtime',
		'mode',
		'filetype',
		'symlink'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'instance creation' }
LAArchiveMember class >> fromHandle: ffiArchiveEntry library: libArchive [

	^ self new
		initializeFromHandle: ffiArchiveEntry library: libArchive;
		yourself
]

{ #category : 'instance creation' }
LAArchiveMember class >> pathname: aPathname size: aSize mtime: aMtime mode: aMode filetype: aFiletype [

	^ self new
		setPathname: aPathname
		size: aSize
		mtime: aMtime
		mode: aMode
		filetype: aFiletype
]

{ #category : 'comparing' }
LAArchiveMember >> = anObject [

	^ anObject class = self class
		and: [ pathname = anObject pathname
			and: [ size = anObject size
				and: [ mtime = anObject mtime
					and: [ mode = anObject mode
						and: [ filetype = anObject filetype
							and: [ symlink = anObject symlink ] ] ] ] ] ]
]

{ #category : 'comparing' }
LAArchiveMember >> hash [

	^ pathname hash
		bitXor: (size hash
				bitXor: (mtime hash
						bitXor: (mode hash
								bitXor: (filetype hash bitXor: symlink hash))))
]

{ #category : 'accessing' }
LAArchiveMember >> filetype [

	^ filetype
]

{ #category : 'initialization' }
LAArchiveMember >> initializeFromHandle: ffiArchiveEntry library: libArchive [

	| symlinkValue |
	pathname := libArchive entry_pathname: ffiArchiveEntry.
	symlinkValue := libArchive entry_symlink: ffiArchiveEntry.
	pathname := self normalizedPathname: pathname.
	size := libArchive entry_size: ffiArchiveEntry.
	mtime := libArchive entry_mtime: ffiArchiveEntry.
	mode := libArchive entry_mode: ffiArchiveEntry.
	filetype := libArchive entry_filetype: ffiArchiveEntry.
	symlink := (symlinkValue isNil or: [ symlinkValue isEmpty ])
		ifTrue: [ nil ]
		ifFalse: [ symlinkValue ]
]

{ #category : 'testing' }
LAArchiveMember >> isDirectory [

	^ filetype = AE_IFDIR
]

{ #category : 'testing' }
LAArchiveMember >> isFile [

	^ filetype = AE_IFREG
]

{ #category : 'testing' }
LAArchiveMember >> isSymlink [

	^ filetype = AE_IFLNK
]

{ #category : 'accessing' }
LAArchiveMember >> mode [

	^ mode
]

{ #category : 'accessing' }
LAArchiveMember >> mtime [

	^ mtime
]
{ #category : 'private' }
LAArchiveMember >> normalizedPathname: aPathname [

	aPathname ifNil: [ ^ aPathname ].
	aPathname ifEmpty: [ ^ aPathname ].
	^ aPathname last = $/
		ifTrue: [ aPathname allButLast ]
		ifFalse: [ aPathname ]
]

{ #category : 'private' }
LAArchiveMember >> setPathname: aPathname size: aSize mtime: aMtime mode: aMode filetype: aFiletype [

	pathname := aPathname.
	size := aSize.
	mtime := aMtime.
	mode := aMode.
	filetype := aFiletype
]

{ #category : 'accessing' }
LAArchiveMember >> pathname [

	^ pathname
]

{ #category : 'accessing' }
LAArchiveMember >> size [

	^ size
]

{ #category : 'accessing' }
LAArchiveMember >> symlink [

	^ symlink
]
