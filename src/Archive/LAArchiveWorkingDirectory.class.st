"
LAArchiveWorkingDirectory temporarily changes the process working directory for the
duration of a block and faithfully restores it afterwards. The underlying chdir call
is dispatched according to the platform (POSIX chdir on Linux/macOS, wide-character
_wchdir on Windows), since libarchive's native extraction writes relative to the
current working directory.

Note: changing the working directory affects the whole Pharo process (there is a single
native thread by default). A shared mutex ensures that concurrent extractions cannot
interleave their directory switches, but code outside this class that resolves relative
paths during the switch may still be affected.
"
Class {
	#name : 'LAArchiveWorkingDirectory',
	#superclass : 'Object',
	#classVars : [
		'SwitchingMutex'
	],
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'private' }
LAArchiveWorkingDirectory class >> ffiLibrary [
	"ffiCall: on a plain class needs an FFILibrary to resolve the foreign symbol. Reuse
	LibC, which wraps the C library providing chdir and _wchdir, without extending LibC."

	^ LibC uniqueInstance
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> chdir: aPathString [
	"Change the process working directory. Dispatches on the current platform because the
	symbol differs between POSIX (chdir) and Windows (_wchdir, wide-character)."

	^ OSPlatform current isWindows
		ifTrue: [ self wchdirUtf16: aPathString ]
		ifFalse: [ self chdirPosix: aPathString ]
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> chdirPosix: aPathString [

	^ self ffiCall: #(int chdir(const char* aPathString))
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> chdirTo: aPathString [

	(self chdir: aPathString) = 0
		ifFalse: [ LAArchiveError signal: 'chdir failed for: ', aPathString ]
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> switchingMutex [

	^ SwitchingMutex ifNil: [ SwitchingMutex := Mutex new ]
]

{ #category : 'accessing' }
LAArchiveWorkingDirectory class >> currentWorkingDirectory [

	^ OSPlatform current currentWorkingDirectoryPath
]

{ #category : 'convenience' }
LAArchiveWorkingDirectory class >> in: aDirectoryReference during: aBlock [
	"Change the process working directory to aDirectoryReference for the duration of aBlock,
	then restore it. Raises LAArchiveError if the directory change fails. A shared mutex
	serializes concurrent extractions so their process-global directory switches cannot
	interleave and corrupt each other's restore."

	| previous |
	self switchingMutex critical: [
		previous := self currentWorkingDirectory.
		[ self chdirTo: aDirectoryReference fullName.
		  aBlock value ]
		ensure: [ self chdirTo: previous ] ]
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> primWchdirUtf16Bytes: aUtf16ByteArray [

	^ self ffiCall: #(int _wchdir(const int* aUtf16ByteArray))
]

{ #category : 'private' }
LAArchiveWorkingDirectory class >> wchdirUtf16: aPathString [
	"Change the process working directory using the wide-character _wchdir. Pharo's FFI has
	no wchar_t external type and cannot bind method temporaries, so UTF-16LE (null-terminated)
	bytes are built here and forwarded as an argument to a pointer parameter."

	| stream |
	stream := WriteStream on: (ByteArray new: (aPathString size * 2) + 2).
	aPathString do: [ :char |
		| scalar |
		scalar := char asInteger.
		scalar < 16r10000
			ifTrue: [ stream
				nextPut: (scalar bitAnd: 16rFF);
				nextPut: ((scalar bitShift: -8) bitAnd: 16rFF) ]
			ifFalse: [ | adjusted |
				adjusted := scalar - 16r10000.
				stream
					nextPut: ((16rD800 + (adjusted bitShift: -10)) bitAnd: 16rFF);
					nextPut: (((16rD800 + (adjusted bitShift: -10)) bitShift: -8) bitAnd: 16rFF);
					nextPut: ((16rDC00 + (adjusted bitAnd: 16r3FF)) bitAnd: 16rFF);
					nextPut: (((16rDC00 + (adjusted bitAnd: 16r3FF)) bitShift: -8) bitAnd: 16rFF) ] ].
	stream nextPut: 0; nextPut: 0.
	^ self primWchdirUtf16Bytes: stream contents
]
