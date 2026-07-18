export class BiMap<K, V> {
	private forward = new Map<K, V>();
	private reverse = new Map<V, K>();

	set(key: K, value: V) {
		this.forward.set(key, value);
		this.reverse.set(value, key);
	}

	get(key: K): V | undefined {
		return this.forward.get(key);
	}

	getKey(value: V): K | undefined {
		return this.reverse.get(value);
	}

	delete(key: K) {
		let value: V | undefined = this.forward.get(key);
		if (value === undefined) { return; }
		this.forward.delete(key);
		this.reverse.delete(value);
	}

	deleteKey(value: V) {
		let key: K | undefined = this.reverse.get(value);
		if (key === undefined) { return; }
		this.forward.delete(key);
		this.reverse.delete(value);
	}

	*entries(): Generator<[K, V], void, void>  {
		for (const [key, value] of this.forward) {
			yield [key, value];
		}
	}
}
