export class Credentials {
	ruid: integer = 0;
	euid: integer = 0;
	suid: integer = 0;
	fsuid: integer = 0;
	rgid: integer = 0;
	egid: integer = 0;
	sgid: integer = 0;
	fsgid: integer = 0;
	supplementary_groups: integer[] = [];

	private matches_any_uid(uid: integer) {
		return (uid === this.ruid || uid === this.euid || uid === this.suid);
	}

	private matches_any_gid(gid: integer) {
		return (gid === this.rgid || gid === this.egid || gid === this.sgid);
	}

	private has_perms() {
		// also check for CAP_SETUID?
		return this.euid === 0
	}

	setuid(uid: integer) {
		if (this.has_perms()) {
			this.ruid = this.suid = this.euid = uid;
		} else if (uid === this.ruid || uid === this.suid) {
			this.euid === uid;
		}
	}

	seteuid(uid: integer) {
		if (this.has_perms() || uid === this.ruid || uid === this.suid) {
			this.euid = uid;
		}
	}

	setreuid(ruid: integer, euid: integer) {	}

	setresuid(ruid: integer, euid: integer, suid: integer) {	}

	setgid(gid: integer) {
		if (this.has_perms()) {
			this.rgid = this.egid = this.sgid = gid;
		} else if ( this.matches_any_gid(gid) ) {
			this.egid = gid;
		}
	}

	setegid(gid: integer) {
		if (this.euid === 0) {
			this.egid = gid;
		} else if ( this.matches_any_gid(gid) ) {
			this.egid = gid;
		}
	}

	setregid(rgid: integer, egid: integer) { }

	setresgid(rgid: integer, egid: integer, sgid: integer) { }

	get_gids(): integer[] {
		let gids: integer[] = [ this.egid ];
		for (const gid of this.supplementary_groups) {
			gids.push(gid);
		}
		return gids;
	}
}

export function create(): Credentials {
    return new Credentials();
}
