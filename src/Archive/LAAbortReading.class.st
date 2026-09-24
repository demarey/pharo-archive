"
LAAbortReading is a control-flow exception used internally to stop iterating over an
archive's entries early (for example once LAArchiveReader>contentsOf: has found the entry
it is looking for). It is not an error condition; it is caught by LAArchiveReader>entriesDo:
and simply ends the traversal while still freeing the underlying handle.
"
Class {
	#name : 'LAAbortReading',
	#superclass : 'Exception',
	#category : 'Archive',
	#package : 'Archive'
}
