"
Performance comparison between three ways of building/extracting a zip of many small
files:
  * the libarchive-backed writer/reader (LAArchiveWriter, LAArchiveReader, via FFI),
  * Pharo's built-in pure-Pharo ZipArchive,
  * the system-native tools (zip/unzip).

The test builds a realistic nested directory tree of semi-compressible text files,
creates and extracts a zip with each implementation, measures wall-clock time of each,
asserts correctness of archive size and content counts (including cross-reads between
the implementations), then checks that the libarchive timings stay within a generous
ratio of the native tools. ZipArchive is the pure-Pharo baseline and is reported without
an aggressive time budget, since it is expected to be slower than C-backed code.

The native tools are a hard requirement: if either zip or unzip is missing on the system,
the test fails rather than being skipped, because the comparison is the very purpose of
the test.
"
Class {
	#name : 'LAArchivePerformanceTest',
	#superclass : 'TestCase',
	#instVars : [
		'workingRoot',
		'payloadDirectory',
		'payloadFileNumber',
		'expectedPayloadSizeInBytes',
		'performanceRatioLimit'
	],
	#category : 'Archive-Performance-Tests',
	#package : 'Archive-Performance-Tests'
}

{ #category : 'config' }
LAArchivePerformanceTest class >> archiveSizeToleranceFraction [
	"Allowed relative size difference between two implementations of the same archive."

	^ 0.1
]

{ #category : 'config' }
LAArchivePerformanceTest class >> defaultFileNumber [

	^ 500
]

{ #category : 'config' }
LAArchivePerformanceTest class >> expectedPayloadSizeInBytes [

	^ 46 * 1024 * 1024
]

{ #category : 'config' }
LAArchivePerformanceTest class >> maximumArchiveSizeInBytes [

	^ 42 * 1024 * 1024
]

{ #category : 'config' }
LAArchivePerformanceTest class >> minimumArchiveSizeInBytes [

	^ 28 * 1024 * 1024
]

{ #category : 'config' }
LAArchivePerformanceTest class >> performanceRatioLimit [

	^ 20
]

{ #category : 'config' }
LAArchivePerformanceTest class >> sampleFileRelativePath [

	^ 'subdir-1/file-0001.txt'
]

{ #category : 'config' }
LAArchivePerformanceTest class >> subdirectoryCount [

	^ 4
]

{ #category : 'accessing' }
LAArchivePerformanceTest >> defaultTimeLimit [
	"Allow the payload build, compression and extraction to take their time: the SUnit
	watchdog default of a few seconds is far too short for building and zipping ~46 MB."

	^ 15 minutes
]

{ #category : 'running' }
LAArchivePerformanceTest >> setUp [

	super setUp.
	self assertNativeToolsAvailable.
	workingRoot := FileLocator temp / ('pharoArchivePerformanceTest-', UUID new asString).
	workingRoot ensureCreateDirectory.
	payloadDirectory := workingRoot / 'payload'.
	payloadFileNumber := self class defaultFileNumber.
	expectedPayloadSizeInBytes := self class expectedPayloadSizeInBytes.
	performanceRatioLimit := self class performanceRatioLimit.
	self buildPayloadDirectory
]

{ #category : 'running' }
LAArchivePerformanceTest >> tearDown [

	workingRoot ifNotNil: [ workingRoot ensureDeleteAll ].
	super tearDown
]

{ #category : 'assertions' }
LAArchivePerformanceTest >> assertArchiveSize: aFileReference [
	"Assert aFileReference is a zip of roughly the payload's size range."

	| size |
	size := aFileReference size.
	self assert: (size between: self class minimumArchiveSizeInBytes and: self class maximumArchiveSizeInBytes)
		description: ('Archive bytes out of expected range: ', size printString)
]

{ #category : 'assertions' }
LAArchivePerformanceTest >> assertNativeToolsAvailable [
	"Fail the test if either native tool used for the comparison is not on the system,
	since without them the comparison cannot be performed at all."

	| missingTools |
	missingTools := #('zip' 'unzip') select: [ :tool |
		(self runNativeCommand: 'command -v ', tool, ' >/dev/null 2>&1') isZero not ].
	self assert: missingTools isEmpty
		description: ('Native tool(s) required for the performance comparison are missing: ', missingTools printString)
]

{ #category : 'assertions' }
LAArchivePerformanceTest >> assertSampleFile: aFileReference [
	"Assert the sample file was extracted with its content intact."

	self assert: aFileReference exists
		description: ('Extraction missing sample file: ', aFileReference fullName).
	self assert: (aFileReference size = (payloadDirectory / self class sampleFileRelativePath) size)
		description: ('Sample file size mismatch after extraction: ', aFileReference fullName,
			' (got ', aFileReference size printString, ', expected ',
			(payloadDirectory / self class sampleFileRelativePath) size printString, ')')
]

{ #category : 'assertions' }
LAArchivePerformanceTest >> assertSimilarSizes: aFileReference and: anotherFileReference [
	"Both implementations must produce a comparable archive; if the compression levels
	differed the archives would not be of comparable size and the timing comparison would
	not be apples-to-apples."

	| size other tolerance |
	size := aFileReference size.
	other := anotherFileReference size.
	tolerance := self class archiveSizeToleranceFraction.
	self assert: (size between: other * (1 - tolerance) and: other * (1 + tolerance))
		description: ('Archive sizes differ beyond tolerance: ', size printString, ' vs ', other printString)
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> assertSampleFileMatchesPayloadIn: anExtractionDirectory [
	"Assert the sample file (payload-relative, no prefix) round-tripped correctly."

	self assertSampleFile: (self sampleFileIn: anExtractionDirectory prefixedWithPayload: false)
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> buildPayloadDirectory [
	"Create a nested tree of payloadFileNumber semi-compressible text files totalling about
	expectedPayloadSizeInBytes bytes, spread across subdirectoryCount subdirectories."

	| random totalBytesPerFile subdirectoryNames subdirectoryCount |
	payloadDirectory ensureCreateDirectory.
	subdirectoryCount := self class subdirectoryCount.
	1 to: subdirectoryCount do: [ :index |
		(payloadDirectory / 'subdir-', index asString) ensureCreateDirectory ].
	subdirectoryNames := (1 to: subdirectoryCount) collect: [ :index | 'subdir-', index asString ].
	totalBytesPerFile := expectedPayloadSizeInBytes // payloadFileNumber.
	random := Random new.
	random seed: 42.
	1 to: payloadFileNumber do: [ :index |
		| jitteredSize directoryName fileReference payloadBytes |
		jitteredSize := totalBytesPerFile
			+ (random nextInteger: totalBytesPerFile // 2)
			- (totalBytesPerFile // 4).
		directoryName := subdirectoryNames at: (index - 1 \\ subdirectoryNames size) + 1.
		fileReference := payloadDirectory
			/ directoryName
			/ ('file-', (index asString padLeftTo: 4 with: $0), '.txt').
		payloadBytes := self compressiblePayloadBytesOfSize: jitteredSize random: random.
		fileReference ensureCreateFile.
		fileReference binaryWriteStreamDo: [ :stream | stream nextPutAll: payloadBytes ] ]
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> compressiblePayloadBytesOfSize: aByteCount random: aRandom [
	"Answer a ByteArray of about aByteCount bytes of pseudo-random text-like content, drawn
	from a seeded generator so the build is deterministic across runs. The variety keeps the
	content from compressing aggressively, so the resulting archive size stays close to the
	raw payload size."

	| result index characterCode |
	result := ByteArray new: aByteCount.
	index := 1.
	[ index <= aByteCount ] whileTrue: [
		characterCode := $a asciiValue + (aRandom nextInteger: 26) - 1.
		result at: index put: characterCode.
		index := index + 1.
		(aRandom nextInteger: 12) = 1
			ifTrue: [
				index <= aByteCount
					ifTrue: [ result at: index put: Character space asciiValue.
						index := index + 1 ] ] ].
	^ result
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> createLibarchiveArchiveToFile: aFileReference fromDirectory: aDirectoryReference [

	LAArchiveWriter writeToFile: aFileReference format: #zip during: [ :writer |
		writer addEntriesFromDirectory: aDirectoryReference ]
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> createNativeArchiveToFile: aFileReference fromDirectory: aDirectoryReference [
	"Create aFileReference using the native zip tool, invoked from workingRoot so both the
	archive and the directory are addressed by basename and entries carry a payload/ prefix."

	self runNativeShellCommand:
		('cd ', (self shellQuotedPath: workingRoot),
			' && zip -q -r ', aFileReference basename, ' ', aDirectoryReference basename,
			' >/dev/null 2>&1')
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> createZipArchiveToFile: aFileReference fromDirectory: aDirectoryReference [
	"Build a zip of aDirectoryReference using Pharo's built-in ZipArchive, naming each
	member by its path relative to aDirectoryReference so extraction reproduces the tree."

	| zip |
	zip := ZipArchive new.
	aDirectoryReference allChildren
		select: [ :child | child isFile ]
		thenDo: [ :child |
			zip addFile: child as: (child relativeTo: aDirectoryReference) pathString ].
	aFileReference binaryWriteStreamDo: [ :stream | zip writeTo: stream ].
	zip close
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> extractLibarchiveArchive: aFileReference to: aDirectoryReference [

	(LAArchiveReader onFile: aFileReference) extractTo: aDirectoryReference
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> extractNativeArchive: aFileReference to: aDirectoryReference [
	"Extract aFileReference with the native unzip tool into aDirectoryReference."

	self runNativeShellCommand:
		('cd ', (self shellQuotedPath: workingRoot),
			' && unzip -q -o ', aFileReference basename, ' -d ',
			(self shellQuotedPath: aDirectoryReference), ' >/dev/null 2>&1')
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> extractZipArchive: aFileReference to: aDirectoryReference [
	"Extract aFileReference (a zip) into aDirectoryReference using Pharo's built-in
	ZipArchive."

	| zip |
	zip := ZipArchive new.
	zip readFrom: aFileReference.
	zip extractAllTo: aDirectoryReference overwrite: false.
	zip close
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> extractionDirectoryOf: aRootDirectoryName [
	"Answer the directory (created on demand) into which an archive is extracted."

	^ (workingRoot / aRootDirectoryName) ensureCreateDirectory
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> fileCountInDirectory: aDirectoryReference [
	"Answer the number of files (recursively) contained in aDirectoryReference."

	^ aDirectoryReference allChildren count: [ :child | child isFile ]
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> millisecondsOf: aBlock [
	"Evaluate aBlock and answer its wall-clock duration in whole milliseconds."

	^ aBlock timeToRun asMilliSeconds
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> ratio: aNumeratorMilliseconds over: aDenominatorMilliseconds [

	^ aNumeratorMilliseconds asFloat / aDenominatorMilliseconds
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> readFileCountOfArchiveFile: aFileReference [
	"Answer the number of file entries libarchive can read from aFileReference."

	^ (LAArchiveReader onFile: aFileReference) entries
		count: [ :entry | entry isFile ]
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> runNativeCommand: aCommandString [
	"Run aCommandString through a shell and answer the shell exit status. On Windows the
	POSIX tooling the test relies on (command -v, zip, unzip) is provided by Git Bash, so
	commands are delegated to it there; elsewhere the system shell is used directly."

	^ OSPlatform current isWindows
		ifTrue: [ LibC uniqueInstance runCommand: (self windowsBashCommand: aCommandString) ]
		ifFalse: [ LibC uniqueInstance runCommand: aCommandString ]
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> runNativeShellCommand: aCommandString [
	"Run aCommandString through a shell and fail if it exits with a non-zero status."

	| exitStatus |
	exitStatus := self runNativeCommand: aCommandString.
	self assert: exitStatus isZero
		description: ('Native command failed with status ', exitStatus printString, ': ', aCommandString)
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> windowsBashCommand: aCommandString [
	"Answer aCommandString wrapped so Git Bash runs it on Windows. The wrapped command must
	not contain double quotes (the call sites build single-quoted commands only)."

	^ self windowsBashPath, ' -lc "', aCommandString, '"'
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> windowsBashPath [
	"Answer the command used to launch Git Bash on Windows. 'bash' is resolved from the
	process PATH; invoking it by the bare name (rather than its spaced full path) avoids
	cmd.exe's mis-parsing of a command line that starts with a quoted executable path."

	^ 'bash'
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> sampleFileIn: anExtractionDirectory prefixedWithPayload: aBoolean [
	"Answer the path of the sample file within anExtractionDirectory. Native entries carry a
	payload/ prefix because they were archived with 'zip -r native.zip payload/'."

	^ anExtractionDirectory
		/ ((aBoolean ifTrue: [ 'payload/' ] ifFalse: [ '' ]) , self class sampleFileRelativePath)
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> shellQuotedPath: aFileSystemEntry [
	"Answer aFileSystemEntry's full path wrapped in single quotes so it is safe on a shell
	command line even when it contains spaces."

	^ '''', aFileSystemEntry fullName, ''''
]

{ #category : 'helpers' }
LAArchivePerformanceTest >> verifyNativeArchive: aFileReference [
	"Ask unzip to verify the integrity of aFileReference, failing if it reports a problem."

	self runNativeShellCommand:
		('unzip -t ', (self shellQuotedPath: aFileReference), ' >/dev/null 2>&1')
]

{ #category : 'tests' }
LAArchivePerformanceTest >> testArchiveCreationAndExtractionPerformanceComparison [
	"Create and extract a zip of the payload with libarchive/Pharo, Pharo's built-in
	ZipArchive and the native zip/unzip tools; assert correctness and archive size
	(including cross-reads between the implementations), then check the libarchive timings
	stay within a generous ratio of the native ones."

	| libarchiveArchiveFile extractedWithLibarchive
	  nativeArchiveFile extractedWithNative
	  zipArchiveFile extractedWithZipArchive
	  libarchiveCreationMilliseconds nativeCreationMilliseconds zipArchiveCreationMilliseconds
	  libarchiveExtractionMilliseconds nativeExtractionMilliseconds zipArchiveExtractionMilliseconds
	  libarchiveCreationRatio libarchiveExtractionRatio createdFileCount |
	self assertNativeToolsAvailable.
	libarchiveArchiveFile := workingRoot / 'pharo.zip'.
	nativeArchiveFile := workingRoot / 'native.zip'.
	zipArchiveFile := workingRoot / 'ziparchive.zip'.
	extractedWithLibarchive := self extractionDirectoryOf: 'extracted-with-libarchive'.
	extractedWithNative := self extractionDirectoryOf: 'extracted-with-native'.
	extractedWithZipArchive := self extractionDirectoryOf: 'extracted-with-ziparchive'.

	libarchiveCreationMilliseconds := self
		millisecondsOf: [ self createLibarchiveArchiveToFile: libarchiveArchiveFile fromDirectory: payloadDirectory ].
	nativeCreationMilliseconds := self
		millisecondsOf: [ self createNativeArchiveToFile: nativeArchiveFile fromDirectory: payloadDirectory ].
	zipArchiveCreationMilliseconds := self
		millisecondsOf: [ self createZipArchiveToFile: zipArchiveFile fromDirectory: payloadDirectory ].

	libarchiveExtractionMilliseconds := self
		millisecondsOf: [ self extractLibarchiveArchive: libarchiveArchiveFile to: extractedWithLibarchive ].
	nativeExtractionMilliseconds := self
		millisecondsOf: [ self extractNativeArchive: nativeArchiveFile to: extractedWithNative ].
	zipArchiveExtractionMilliseconds := self
		millisecondsOf: [ self extractZipArchive: zipArchiveFile to: extractedWithZipArchive ].

	libarchiveCreationRatio := self ratio: libarchiveCreationMilliseconds over: nativeCreationMilliseconds.
	libarchiveExtractionRatio := self ratio: libarchiveExtractionMilliseconds over: nativeExtractionMilliseconds.

	createdFileCount := self fileCountInDirectory: payloadDirectory.
	self assertArchiveSize: libarchiveArchiveFile.
	self assert: nativeArchiveFile exists
		description: 'The native zip was not created.'.
	self assert: zipArchiveFile exists
		description: 'The Pharo ZipArchive output was not created.'.
	self assertSimilarSizes: nativeArchiveFile and: libarchiveArchiveFile.

	"Cross-interoperability: libarchive must fully read what the other tools produced."
	self assert: (self readFileCountOfArchiveFile: nativeArchiveFile) = createdFileCount
		description: 'libarchive could not fully read the archive produced by unzip.'.
	self assert: (self readFileCountOfArchiveFile: zipArchiveFile) = createdFileCount
		description: 'libarchive could not fully read the archive produced by Pharo ZipArchive.'.
	"...and unzip must read and verify the archive produced by libarchive."
	self verifyNativeArchive: libarchiveArchiveFile.

	self assert: (self fileCountInDirectory: extractedWithLibarchive) = createdFileCount
		description: 'libarchive extraction produced a wrong file count.'.
	self assert: (self fileCountInDirectory: extractedWithNative) = createdFileCount
		description: 'unzip extraction produced a wrong file count.'.
	self assert: (self fileCountInDirectory: extractedWithZipArchive) = createdFileCount
		description: 'ZipArchive extraction produced a wrong file count.'.
	self assertSampleFileMatchesPayloadIn: extractedWithLibarchive.
	self assertSampleFile: (self sampleFileIn: extractedWithNative prefixedWithPayload: true).
	self assertSampleFileMatchesPayloadIn: extractedWithZipArchive.

	self assert: libarchiveCreationRatio < self class performanceRatioLimit
		description: ('libarchive creation too slow (', libarchiveCreationRatio printString,
			'x native, limit ', self class performanceRatioLimit printString, 'x).').
	self assert: libarchiveExtractionRatio < self class performanceRatioLimit
		description: ('libarchive extraction too slow (', libarchiveExtractionRatio printString,
			'x native, limit ', self class performanceRatioLimit printString, 'x).').

	Transcript
		crShow: ('pharo-archive perf archiveBytes=', libarchiveArchiveFile size printString,
			' nativeBytes=', nativeArchiveFile size printString,
			' zipArchiveBytes=', zipArchiveFile size printString,
			' files=', createdFileCount printString);
		crShow: ('  create  libarchiveMs=', libarchiveCreationMilliseconds printString,
			' nativeMs=', nativeCreationMilliseconds printString,
			' zipArchiveMs=', zipArchiveCreationMilliseconds printString,
			' ratio(libarchive/native)=', libarchiveCreationRatio printString);
		crShow: ('  extract libarchiveMs=', libarchiveExtractionMilliseconds printString,
			' nativeMs=', nativeExtractionMilliseconds printString,
			' zipArchiveMs=', zipArchiveExtractionMilliseconds printString,
			' ratio(libarchive/native)=', libarchiveExtractionRatio printString)
]
