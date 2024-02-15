# Map Save Format

Put simply, the map is saved in a binary format in order to reduce filesize, as
a map can easily and quickly get hundreds of thousands to millions of entries.

The map system itself can support any size of map, however the save format is
limited to 65535x65535x65535, as with CC a map of that size is already going to
be a ridiculous size. If it can, it will save in a smaller format that supports
255x255x255 size maps, but if it can't it will save in the larger format.

All values are big endian.

## Header

The main header is a minimum of 18 bytes long, and is as follows:

- 6 bytes: String literal: **"CCSMAP"** (0x4343534d4150)
- 2 bytes: Unsigned int: **Version** (0x1 - 0xFFFF) - A loader will need to
  check the version and load the map accordingly. The file io implementation is
  **NOT** guaranteed to be able to load every previous version, and will be
  unable to load newer versions.
- 2 bytes: Bits: **Flags** (0x0 - 0xFFFF)
- 1 byte: Unsigned int: **Length of map name** (0x0 - 0xFF)
- < Length of map name > bytes: String literal: **Map name**
- 6 bytes: The **amount of "Node Runs"** in the map (0x0 - 0xFFFFFFFFFFFF) - This
  is not present in the header if this is the second (or later) file in a
  multi-file map. The first file will have the total amount of node runs across
  all files in the map.
- 6 bytes: The **size of the map in each dimension** (0x0 - 0xFFFFFFFFFFFF) -
  This value should be treated specially, as the map actually expands into the
  negative range as well, but this value is a positive number. The actual
  dimensions of the map are 2 * this value + 1. This is not present in the
  header if this is the second (or later) file in a multi-file map. The first
  file will have the size of the map in each dimension.

At the moment, only a few flags exist (but there are 16 bits, so there's room
for more):

- -- -- -- -- -- -- -- -1: Map is in the larger format
- -- -- -- -- -- -- -- 1-: Map is part of a multi-file map. At the end of the 
  header, a length will be specified for the path to the next file in the map,
  as well as the path itself.
- -- -- -- -- -- -- -1 --: Map is part of a multi-file map, but is the last 
  file. No length or path will be specified at the end of the header.
- -- -- -- -- -- -- 1- --: Map is part of a multi-file map, but is the first 
  file. 

### Flag-Dependent Header Data

If the map is the smaller format, the next 3 bytes after the map name will be
the size of the map in each dimension. If the map is the larger format, the next
6 bytes after the map name will be the size of the map in each dimension (2
bytes per dimension).

If the map is part of a multi-file map, the next 2 bytes after the size will be
the length of the path to the next file in the map. If the map is the last file
in a multi-file map, the next 2 bytes after the size will be 0x0000. This will
instead be after the version (and everything past the version will be excluded)
if the map is the second or later file in a multi-file map.

### Illustration

```
| "CCSMAP" | VERSION | FLAGS | NAME LENGTH (L) | NAME | SIZE | PATH LENGTH (P) | PATH | NODE RUNS | MAP SIZE | ... (node runs)
0          6         8       10                12    12+L   15+L              17+L  17+L+P      23+L+P     29+L+P   (Small size version)
0          6         8       10                12    12+L   18+L              20+L  20+L+P      26+L+P     32+L+P   (Large size version)
```

Note, again, that the path length and path are only present if the map is part
of a multi-file map.

#### Multifile Continuation Headers Illustration

```
| "CCSMAP" | VERSION | PATH LENGTH (P) | PATH | ... (node runs)
0          6         8                 10    10+P
```

## Data

The data is segmented into *node runs*. A node run is a series of nodes that are
all the same type, and are adjacent to each other. The format of a node run is
as follows:

- 1 byte: Node type (0x0 - 0x1) - 0 -> Air, 1 -> Solid, unknown nodes are not
  saved.
- 1 or 2 bytes (depending on the size of the map): Amount of nodes in the run
  (0x0 - 0xFFFFFFFF) - This is the amount of nodes in the run.
- 3 or 6 bytes (depending on the size of the map): Position of the first node in
  the run (0x0 - 0xFFFFFFFFFFFF). Signed integer, so the maximum value is 127,
  and the minimum value is -128. The position is in the order of X, Y, Z.

The data is then repeated for each node run in the map.

### Illustration

```
| NODE TYPE | NODES - 1 | POSITION |
0           1           3           (Small size version)
0           1           6           (Large size version)
```

## Multi-File Maps

If a map is part of a multi-file map, the second and later files will have no
node run count in the header, as the first file will have the total amount of
node runs across all files in the map. Everything else is the same as a normal
map, except for the fact that the last file will have no path length or path in
the header.