export const CHUNK_SIZE_BYTES = 512 * 1024; // 512 KB

export interface FileChunkInfo {
  totalChunks: number;
  totalSize: number;
  getChunkBuffer: (index: number) => Promise<ArrayBuffer>;
}

export function prepareFileChunker(file: File): FileChunkInfo {
  const totalSize = file.size;
  const totalChunks = Math.max(1, Math.ceil(totalSize / CHUNK_SIZE_BYTES));

  const getChunkBuffer = async (index: number): Promise<ArrayBuffer> => {
    if (index < 0 || index >= totalChunks) {
      throw new Error(`Chunk index ${index} out of bounds (0 to ${totalChunks - 1})`);
    }

    const start = index * CHUNK_SIZE_BYTES;
    const end = Math.min(start + CHUNK_SIZE_BYTES, totalSize);
    const slice = file.slice(start, end);

    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        if (reader.result instanceof ArrayBuffer) {
          resolve(reader.result);
        } else {
          reject(new Error('Failed to read chunk as ArrayBuffer'));
        }
      };
      reader.onerror = () => reject(reader.error);
      reader.readAsArrayBuffer(slice);
    });
  };

  return {
    totalChunks,
    totalSize,
    getChunkBuffer,
  };
}
