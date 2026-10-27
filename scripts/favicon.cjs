// Run with Node.js and sharp installed: node scripts/favicon.cjs
const sharp = require('sharp');
const path = require('node:path');
const fs = require('node:fs/promises');

async function main() {
  const assets = path.resolve(__dirname, '../docs/assets/img');
  const source = path.join(assets, 'favicon.svg');
  for (const size of [16, 32, 180, 192, 512]) {
    const name = size === 180 ? 'apple-touch-icon.png' : `favicon-${size}.png`;
    await sharp(source).resize(size, size).png().toFile(path.join(assets, name));
  }
  const sizes = [16, 32, 48];
  const images = await Promise.all(sizes.map(size => sharp(source).resize(size, size).png().toBuffer()));
  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);
  let offset = header.length;
  images.forEach((image, index) => {
    const entry = 6 + index * 16;
    header[entry] = sizes[index];
    header[entry + 1] = sizes[index];
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(image.length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += image.length;
  });
  await fs.writeFile(path.join(assets, 'favicon.ico'), Buffer.concat([header, ...images]));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
