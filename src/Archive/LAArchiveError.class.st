"
A LAArchiveError is raised whenever libarchive reports a failure. It carries the
underlying error message coming from archive_error_string(), so callers get a
meaningful description instead of a raw return code.
"
Class {
	#name : 'LAArchiveError',
	#superclass : 'Error',
	#category : 'Archive',
	#package : 'Archive'
}

{ #category : 'instance creation' }
LAArchiveError class >> signalOn: aReference errorString: aString [

	^ self
		signal: 'Libarchive error while handling ', aReference printString,
			': ', aString
]
