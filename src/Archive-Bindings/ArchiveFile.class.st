Class {
	#name : 'ArchiveFile',
	#superclass : 'ArchiveBaseObject',
	#category : 'Archive-Base',
	#package : 'Archive-Bindings',
	#tag : 'Base'
}

{ #category : 'finalizing' }
ArchiveFile >> dispose [

	self ffiCall: #(void archive_dispose(archive* self))
]
