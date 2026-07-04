# TODO

## Block device / filesystem separation

Currently `BaseFS` conflates two responsibilities that real Unix systems keep separate:

- **Block device driver** — talks to hardware (or a file), exposes a raw byte sequence
- **Filesystem driver** — reads those raw bytes and interprets an on-disk format (inodes, directories, block bitmaps)

This separation is what allows any filesystem to run on any storage backend, and makes intermediate layers (encryption, compression, RAID, loop devices) possible.

Implementing this properly requires committing to a real binary on-disk format first — something like a simplified ext2 layout (superblock, inode table, block bitmap, data blocks). Once that exists, the block/filesystem split follows naturally.

This is a significant undertaking and should be revisited after the new VFS layer is stable and well-tested.

**Options:**
- Design a custom format tailored to this project
- Implement a real documented format (ext2 is simple and well-documented)
