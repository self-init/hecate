import type { Inode as InodeClass } from "./vfs/inode/init";
import type { Credentials as CredentialsClass } from "./processes/credentials";

declare global {
	type Inode = InodeClass;
	type Credentials = CredentialsClass;
}
