// Run with Node.js and sharp installed: node scripts/banner.cjs
const sharp = require('sharp');
const path = require('node:path');

async function main() {
  const assets = path.resolve(__dirname, '../docs/assets/img');
  const fontfile = path.resolve(__dirname, 'assets/news-cycle/NewsCycle-Bold.ttf');
  const background = path.resolve(__dirname, 'assets/banner-background.png');
  const lines = ['Códigos', 'postales', 'de España'];
  const overlays = await Promise.all(lines.map(async (line, index) => ({
    input: await sharp({ text: {
      text: `<span foreground="#222222">${line}</span>`,
      font: 'News Cycle Bold 150',
      fontfile,
      dpi: 72,
      rgba: true
    } }).png().toBuffer(),
    left: 98,
    top: 135 + index * 160
  })));
  const source = path.join(assets, 'github-preview-source.png');
  await sharp(background).composite(overlays).png().toFile(source);
  await sharp(source).resize(1280, 640)
    .jpeg({ quality: 90, mozjpeg: true })
    .toFile(path.join(assets, 'github-preview.jpg'));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
