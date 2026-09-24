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
		spec package: 'Archive-Bindings'.
		spec package: 'Archive' with: [ spec requires: #('Archive-Bindings') ].
		spec package: 'Archive-Bindings-Tests'
			with: [ spec requires: #('Archive-Bindings') ].
		spec package: 'Archive-Tests' with: [ spec requires: #('Archive') ].
		spec package: 'Archive-PerformanceTests'
			with: [ spec requires: #('Archive') ].

		spec group: 'core' with: #('Archive-Bindings' 'Archive').
		spec group: 'default' with: #('core' 'Archive-Bindings-Tests' 'Archive-Tests').
		spec group: 'Performance' with: #('Archive-PerformanceTests') ]

]
