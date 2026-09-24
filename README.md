# Archive

A library to work with [libarchive](https://libarchive.org) from [Pharo](https://pharo.org):

- [`Archive`](src/Archive/) — a hand-written, high-level archive library that mirrors the
  Compression package's `Archive` document model, so common operations feel idiomatic, while
  the heavy lifting (read/write/extract for many container formats) is delegated to
  libarchive — preserving POSIX permissions and modification times for free.
- [`Archive-Bindings`](src/Archive-Bindings/) — **generated** low-level FFI bindings
  (`LibArchive`, `ArchiveEntry`, pools `ArchiveConstants`/`ArchiveTypedef`, ...) produced by
  [pharo-cig](https://github.com/estebanlm/pharo-cig). Do **not** hand-edit them; regenerate
  by applying the recipe stored in the [`LibArchive` class
  comment](src/Archive-Bindings/LibArchive.class.st).

## Package layout

| Package | Origin | What it contains |
| --- | --- | --- |
| [`Archive`](src/Archive/) | hand-written | High-level, idiomatic Pharo API (`LAArchive`, `LAArchiveReader`, `LAArchiveWriter`, `LAArchiveMember`, `LAArchiveFormat`, `LAArchiveError`, ...) built on the generated bindings. |
| [`Archive-Tests`](src/Archive-Tests/) | hand-written | Tests for the hand-written `Archive` package. |
| [`Archive-PerformanceTests`](src/Archive-PerformanceTests/) | hand-written | Performance benchmarks (`LAArchivePerformanceTest`), not loaded by default — run via the `Performance` group. |
| [`Archive-Bindings`](src/Archive-Bindings/) | **generated** | Low-level FFI bindings produced by **pharo-cig**. **Do not hand-edit** — regenerate instead. |
| [`Archive-Bindings-Tests`](src/Archive-Bindings-Tests/) | **generated** | Tests for the generated bindings. |

Any package whose name ends with `-Bindings` is generated and must not be edited by hand.

The high-level `Archive` API:

- **Document model** — `LAArchive` builds, inspects, edits and round-trips an archive in
  memory.
- **Streaming read/write** — `LAArchiveReader` and `LAArchiveWriter` work directly with
  files, streams or byte buffers.
- **Native extraction** — permissions and timestamps are preserved with no extra work.
- **Format auto-detection on read** — you just open the archive; the format is detected.
- **Many writer formats** — zip, tar (pax), gnutar, 7zip, cpio, xar and iso.

## Requirements

- A Pharo image (developed and tested against Pharo 14).
- The **libarchive** native library. The FFI resolves it from `CIG/lib` **relative to the
  Pharo working directory** (i.e. `./CIG/lib/libarchive.{so|dylib|dll}`). See
  `.github/workflows/tests.yml` for how CI supplies it on each OS.

## Installation

Load the project and its tests with Metacello:

```smalltalk
Metacello new
	baseline: 'Archive';
	repository: 'github://pharo-cig/pharo-archive:main/src';
	load.
```

This loads the whole project including tests (the `default` group). To load only the core
(bindings + high-level API) use the `core` group:

```smalltalk
Metacello new
	baseline: 'Archive';
	repository: 'github://pharo-cig/pharo-archive:main/src';
	load: #core.
```

## Quick start

### One-shot: build & extract a zip

If you just need to compress a folder into a zip, or unpack a zip — both in a single
expression — this is the API for you. zip is libarchive's default on write and is
auto-detected on read.

Build a zip from a directory and all of its subdirectories (one expression):

```smalltalk
(LAArchive new
	addEntriesFromDirectory: '/path/to/folder';
	writeToFile: '/tmp/folder.zip')
```

Unpack that zip back, preserving permissions and modification times (one expression):

```smalltalk
(LAArchive new
	readFrom: '/tmp/folder.zip';
	extractAllTo: '/tmp/extracted')
```

Building records each file's POSIX permission and modification-time metadata; extracting
restores them natively. The subsections below keep the more granular, step-by-step coverage.

### Build an archive from the document model and write it

```smalltalk
| archive |
archive := LAArchive new.
archive
	addDirectory: 'docs';
	addString: 'Hello document!' as: 'hello.txt';
	addString: ('# Title', String lf) as: 'docs/notes.md';
	addFile: '/path/to/a-file.txt' as: 'assets/a-file.txt'.
archive writeToFile: '/tmp/example.zip'.
```

### Read an archive back, inspect it and extract everything

```smalltalk
| archive |
archive := (LAArchive new) readFrom: '/tmp/example.zip'.
archive memberNames.                                   "-> #('docs' 'docs/notes.md' 'hello.txt' 'assets/a-file.txt')"
archive contentsOf: 'hello.txt'.                       "a ByteArray"
archive extractAllTo: '/tmp/extracted'.
```

The extraction directory now contains the archive contents with their original
permissions and modification times.

### Stream an archive without building a document model

```smalltalk
| target |
target := '/tmp/stream.zip'.
LAArchiveWriter writeToFile: target format: #zip during: [ :writer |
	writer
		addDirectory: 'docs';
		addFileNamed: 'hello.txt' content: 'file contents' asByteArray;
		addFileNamed: 'docs/notes.md' content: '# Title' asByteArray ].
```

### Pack a whole directory tree

```smalltalk
| archive |
archive := LAArchive new.
archive addEntriesFromDirectory: '/path/to/payload'.   "recursively walks the tree"
archive writeToFile: '/tmp/payload.tar'.               "choose any supported format"
```

Because the members are taken from real files, their POSIX permissions and mtimes are
recorded in the archive.

### Read a single entry's bytes and extract a single member

```smalltalk
| reader entry |
reader := LAArchiveReader onFile: '/tmp/example.zip'.
entry := reader entries detect: [ :each | each pathname = 'hello.txt' ].
reader contentsOf: entry.                              "the raw bytes of that entry"

reader extractTo: '/tmp/all'.                          "native, perms + mtimes preserved"

| model |
model := LAArchive new readFrom: '/tmp/example.zip'.
model extractMember: 'hello.txt' to: '/tmp/single'.    "just one member"
```

### Choose a different output format

Reads are format-agnostic (libarchive auto-detects). Writes pick a format by name:

```smalltalk
| archive |
archive := LAArchive new.
archive
	addString: 'alpha' as: 'a.txt';
	addString: 'beta' as: 'b.txt'.
archive writeToFile: '/tmp/out.zip'.    "zip"
archive writeToFile: '/tmp/out.tar'.    "tar (pax)"
archive writeTo: '/tmp/out.7z' format: #sevenzip.
archive writeTo: '/tmp/out.cpio' format: #cpio.
```

## Document model vs. backing file

`LAArchive` is both a document model and, after `readFrom:`/`writeToFile:`, a wrapper over
a **backing file**. Mutations (`addMember:`/`addFile:`/`addString:`/`addDirectory:`,
`removeMember:`, `replaceMember:`, `setContentsOf:`) change only the in-memory model; the
backing file is untouched. This divergence is tracked with an internal `isDirty` flag:

- `extractAllTo:` extracts **natively from the backing file** while the model still matches
  it (the fast path, preserving permissions/timestamps). Once the model has been edited, the
  **model is the source of truth** and is extracted instead, so your edits are honored.
- `writeTo:`/`writeToFile:` serializes the (possibly edited) model and resets the flag —
  it produces an archive that faithfully reflects the document model.
- `contentsOf:` and `extractMember:` always honor the model, reading on demand from the
  backing file when content was not explicitly set.

Example of editing a read archive and having the edits reflected on extraction:

```smalltalk
| archive |
archive := LAArchive new readFrom: '/tmp/example.zip'.
archive setContentsOf: 'hello.txt' to: 'edited content'.
archive removeMember: 'docs/notes.md'.
archive addString: 'a new file' as: 'new.txt'.
archive extractAllTo: '/tmp/edited'.    "hello.txt has 'edited content'; notes.md is gone; new.txt present"
```

## API overview

| Class | Responsibility | Notable selectors |
| --- | --- | --- |
| `LAArchive` | High-level in-memory document model; round-trip to/from disk | `addMember:` `addFile:` `addString:` `addDirectory:` `addEntriesFromDirectory:` `removeMember:` `replaceMember:` `setContentsOf:` `contentsOf:` `extractAllTo:` `extractMember:` `readFrom:` `writeTo:` `writeToFile:` `members` `memberNamed:` `memberNames` `numberOfMembers` `isDirty` |
| `LAArchiveReader` | Opens an existing archive; enumerate, read bytes, extract natively | `onFile:` `onBytes:` `onStream:` `entries` `contentsOf:` `extractTo:` |
| `LAArchiveWriter` | Builds a new archive; streaming or block-based | `toFile:` `toStream:` `writeToFile:format:during:` `writeToStream:format:during:` `addEntryNamed:` `addFileNamed:content:` `addDirectory:` `addEntriesFromDirectory:` `finish` |
| `LAArchiveMember` | Immutable description of a single entry | `pathname` `size` `mtime` `mode` `filetype` `isDirectory` `isFile` `isSymlink` `symlink` |
| `LAArchiveFormat` | Value describing an output container format | `named:` `zip` `tar` `gnutar` `sevenZip` `cpio` `xar` `iso` |
| `LAArchiveError` | Raised when libarchive reports a failure (carries a readable message) | `signalOn:errorString:` |
| `LAArchiveWorkingDirectory` | Switches CWD around native extraction (thread-safe restore) | `in:during:` |

## Low-level bindings usage

Operating directly on the generated bindings:

```smalltalk
"list contents of a file"
| fileRef arc archive paths entryHolder entry |

arc := LibArchive uniqueInstance.

fileRef := '/path/to/file.zip' asFileReference.
fileRef exists 
	ifFalse: [ self error: 'File ', fileRef fullName, ' not found.' ]. 

archive := arc read_new.
arc read_support_filter_all: archive.
arc read_support_format_all: archive.
arc 
	read_open_filenameArg1: archive 
	_filename: fileRef fullName 
	_block_size: 10240.

paths := OrderedCollection new.
entryHolder := ArchiveEntry newValueHolder.
[ (arc read_next_headerArg1: archive arg2: entryHolder) = 0 ] 
whileTrue: [ 
	entry := entryHolder value.
	paths add: (arc entry_pathname: entry). 
	arc read_data_skip: archive.
].

arc read_free: archive.

paths inspect
```

The generation recipe can be found at the class comment of [LibArchive class](src/Archive-Bindings/LibArchive.class.st).
