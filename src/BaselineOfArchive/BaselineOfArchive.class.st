Class {
	#name : 'BaselineOfArchive',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfArchive',
	#package : 'BaselineOfArchive'
}

{ #category : 'baselines' }
BaselineOfArchive >> baseline: spec [
	<baseline>
	
	spec for: #common do: [
		spec package: 'Archive'.
		spec package: 'Archive-Tests' with: [ spec requires: 'Archive' ].
		spec group: 'Tests' with: #('Archive-Tests') ]
]
