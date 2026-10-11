const fs=require('fs');
const path=require('path');
const output=path.join(__dirname,'exports');
fs.mkdirSync(output,{recursive:true});
const sharp=require(process.env.TACHOBOOK_SHARP_MODULE || 'sharp');
const book=fs.readFileSync(path.join(__dirname,'source/book.svg'),'utf8').match(/<g[\s\S]*<\/g>/)[0];
const badge=fs.readFileSync(path.join(__dirname,'source/badge.svg'),'utf8').match(/<g[\s\S]*<\/g>/)[0];
const artwork=`<rect width="200" height="200" fill="#116B93"/><g transform="translate(33 33)"><g transform="translate(5.625 11.25)">${book}</g><g transform="translate(15.0795 76.9635)">${badge}</g></g>`;
const svg=n=>`<svg xmlns="http://www.w3.org/2000/svg" width="${n}" height="${n}" viewBox="0 0 200 200">${artwork}</svg>`;
const sizes=[20,29,40,58,60,76,80,87,120,152,167,180,1024];
(async()=>{for(const n of sizes){fs.writeFileSync(`${output}/AppIcon-${n}.svg`,svg(n));await sharp(Buffer.from(svg(n))).flatten({background:'#116B93'}).removeAlpha().png({compressionLevel:9,palette:false}).toFile(`${output}/AppIcon-${n}.png`);}
let x=0;const groups=sizes.map(n=>{let g=`<g id="AppIcon-${n}x${n}" transform="translate(${x} 0)"><svg width="${n}" height="${n}" viewBox="0 0 200 200">${artwork}</svg></g>`;x+=n+40;return g;});
fs.writeFileSync(path.join(output,'AppIcon-iOS-Sizes.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${x}" height="1024">${groups.join('')}</svg>`);
console.log('Generated',sizes.join(', '));})();
