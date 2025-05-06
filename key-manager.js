class KeyManager {
    constructor() {
        this.storage = window.localStorage;
    }

    async generateKey() {
        const array = new Uint32Array(8);
        window.crypto.getRandomValues(array);
        return Array.from(array, dec => dec.toString(16).padStart(8, '0')).join('');
    }

    async encryptFile(file, key) {
        const fileBuffer = await file.arrayBuffer();
        const iv = CryptoJS.lib.WordArray.random(16);
        const keyHex = CryptoJS.enc.Hex.parse(key);
        
        const encrypted = CryptoJS.AES.encrypt(
            CryptoJS.lib.WordArray.create(new Uint8Array(fileBuffer)),
            keyHex,
            { iv: iv }
        );
        
        return {
            encrypted: new Blob([encrypted.toString()]),
            iv: iv.toString()
        };
    }

    async decryptFile(encryptedBlob, key, iv) {
        const encryptedText = await encryptedBlob.text();
        const keyHex = CryptoJS.enc.Hex.parse(key);
        const ivHex = CryptoJS.enc.Hex.parse(iv);
        
        const decrypted = CryptoJS.AES.decrypt(
            encryptedText,
            keyHex,
            { iv: ivHex }
        );
        
        return new Blob([new Uint8Array(decrypted.words.length * 4)]);
    }

    async storeKey(keyId, key) {
        this.storage.setItem(keyId, key);
    }

    async getKey(keyId) {
        const key = this.storage.getItem(keyId);
        if (!key) {
            throw new Error('Key not found');
        }
        return key;
    }

    async deleteKey(keyId) {
        this.storage.removeItem(keyId);
    }
}