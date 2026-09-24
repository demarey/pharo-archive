"
LAArchiveFFI is a trait with small shared helpers used by both LAArchiveReader and
LAArchiveWriter to check libarchive result codes and raise LAArchiveError. Trait methods
are instance-side, so each using class calls them directly as self assertOk: ... / self
assertExtractOk: ...
"
Trait {
	#name : 'LAArchiveFFI',
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'checks' }
LAArchiveFFI >> assertOk: aResult lib: lib archive: archive reference: aReference [
	"ARCHIVE_OK == 0 is inlined to avoid depending on the ArchiveConstants pool."

	aResult = 0 ifFalse: [
		LAArchiveError signalOn: aReference errorString: (lib error_string: archive) ]
]

{ #category : 'checks' }
LAArchiveFFI >> assertExtractOk: aResult lib: lib archive: archive reference: aReference [
	"archive_read_extract may return warnings (positive values) besides ARCHIVE_OK (0), so
	only fail on strictly negative results."

	aResult >= 0 ifFalse: [
		LAArchiveError signalOn: aReference errorString: (lib error_string: archive) ]
]
