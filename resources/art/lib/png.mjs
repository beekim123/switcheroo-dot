/** Original dependency-free PNG codec. RGBA8 only; no timestamps or metadata. */
import { deflateSync, inflateSync, constants } from 'node:zlib';

const SIGNATURE = Buffer.from([137,80,78,71,13,10,26,10]);
const MAX_PIXELS = 16_777_216;
const CRC_TABLE = Uint32Array.from({ length: 256 }, (_, value) => {
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});
export function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = CRC_TABLE[(crc ^ byte) & 255] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data = Buffer.alloc(0)) {
  const name = Buffer.from(type, 'ascii');
  const result = Buffer.alloc(data.length + 12);
  result.writeUInt32BE(data.length, 0);
  name.copy(result, 4);
  data.copy(result, 8);
  result.writeUInt32BE(crc32(Buffer.concat([name, data])), data.length + 8);
  return result;
}
function dimensions(width, height) {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || width * height > MAX_PIXELS) {
    throw new Error('PNG dimensions must be positive integers within the pixel limit');
  }
}
export function encodePNG({ width, height, data }) {
  dimensions(width, height);
  if (!(data instanceof Uint8Array) || data.length !== width * height * 4) throw new Error('PNG RGBA data length mismatch');
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const stride = width * 4;
  const scanlines = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) scanlines.set(data.subarray(y * stride, (y + 1) * stride), y * (stride + 1) + 1);
  // Fixed Huffman blocks, filter 0, no metadata: byte-identical rebuilds.
  const compressed = deflateSync(scanlines, { level: 9, strategy: constants.Z_FIXED });
  return Buffer.concat([SIGNATURE, chunk('IHDR', ihdr), chunk('IDAT', compressed), chunk('IEND')]);
}
function paeth(a,b,c) {
  const p=a+b-c, pa=Math.abs(p-a), pb=Math.abs(p-b), pc=Math.abs(p-c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}
export function decodePNG(input) {
  const bytes = Buffer.from(input);
  if (!bytes.subarray(0, 8).equals(SIGNATURE)) throw new Error('Invalid PNG signature');
  let width, height, offset = 8, ended = false, seenData = false;
  const pieces = [];
  while (offset < bytes.length) {
    if (offset + 12 > bytes.length) throw new Error('Truncated PNG chunk');
    const length = bytes.readUInt32BE(offset), end = offset + 12 + length;
    if (end > bytes.length) throw new Error('Truncated PNG chunk data');
    const type = bytes.toString('ascii', offset+4, offset+8), data = bytes.subarray(offset+8,end-4);
    if (crc32(bytes.subarray(offset+4,end-4)) !== bytes.readUInt32BE(end-4)) throw new Error(`PNG CRC mismatch: ${type}`);
    if (!width && type !== 'IHDR') throw new Error('PNG IHDR must be first');
    if (type === 'IHDR') {
      if (width || length !== 13) throw new Error('Invalid PNG IHDR');
      width=data.readUInt32BE(0); height=data.readUInt32BE(4); dimensions(width,height);
      if (data[8]!==8 || data[9]!==6 || data[10]!==0 || data[11]!==0 || data[12]!==0) throw new Error('Only non-interlaced RGBA8 PNG is supported');
    } else if (type === 'IDAT') { pieces.push(data); seenData=true; }
    else if (type === 'IEND') { if (length || !seenData || end !== bytes.length) throw new Error('Invalid PNG IEND'); ended=true; break; }
    else if (type[0] === type[0].toUpperCase()) throw new Error(`Unsupported critical PNG chunk: ${type}`);
    offset=end;
  }
  if (!ended) throw new Error('PNG missing IEND');
  const stride=width*4, expected=(stride+1)*height;
  const raw=inflateSync(Buffer.concat(pieces), { maxOutputLength: expected });
  if (raw.length!==expected) throw new Error('PNG scanline length mismatch');
  const data = new Uint8Array(width*height*4);
  for (let y=0;y<height;y++) {
    const filter=raw[y*(stride+1)];
    if (filter>4) throw new Error('Unsupported PNG filter');
    for (let x=0;x<stride;x++) {
      const i=y*stride+x, a=x>=4?data[i-4]:0, b=y?data[i-stride]:0, c=y&&x>=4?data[i-stride-4]:0;
      const predictor=filter===0?0:filter===1?a:filter===2?b:filter===3?Math.floor((a+b)/2):paeth(a,b,c);
      data[i]=(raw[y*(stride+1)+x+1]+predictor)&255;
    }
  }
  return { width, height, data };
}
