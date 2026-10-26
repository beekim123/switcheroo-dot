/** Original integer-only palette canvas. Transparent pixels are always RGBA 0. */
function integers(...values) {
  if (values.some(value => !Number.isInteger(value))) throw new Error('Pixel coordinates must be integers');
}
export class PixelCanvas {
  constructor(width, height, palette) {
    integers(width,height);
    if (width<1 || height<1 || width*height>16_777_216) throw new Error('Invalid canvas size');
    this.width=width; this.height=height; this.palette=palette;
    this.data=new Uint8Array(width*height*4);
    this.colors=new Map(Object.entries(palette.colors).map(([name,hex])=>{
      if (!/^#[0-9a-f]{6}$/i.test(hex)) throw new Error(`Invalid palette color: ${name}`);
      return [name,[...hex.slice(1).match(/../g).map(value=>parseInt(value,16)),255]];
    }));
    this.colors.set('.', [0,0,0,0]);
  }
  color(name) {
    if (!this.colors.has(name)) throw new Error(`Unknown palette color: ${name}`);
    return this.colors.get(name);
  }
  px(x,y,name) {
    integers(x,y); const color=this.color(name);
    if (x>=0&&y>=0&&x<this.width&&y<this.height) this.data.set(color,(y*this.width+x)*4);
    return this;
  }
  fill(name) { return this.rect(0,0,this.width,this.height,name); }
  rect(x,y,width,height,name) {
    integers(x,y,width,height); this.color(name);
    if(width<0||height<0) throw new Error('Rectangle size cannot be negative');
    for(let py=Math.max(0,y);py<Math.min(this.height,y+height);py++) for(let px=Math.max(0,x);px<Math.min(this.width,x+width);px++) this.px(px,py,name);
    return this;
  }
  line(x0,y0,x1,y1,name) {
    integers(x0,y0,x1,y1); this.color(name);
    const dx=Math.abs(x1-x0),sx=x0<x1?1:-1,dy=-Math.abs(y1-y0),sy=y0<y1?1:-1;
    let error=dx+dy;
    while(true) { this.px(x0,y0,name); if(x0===x1&&y0===y1)break; const twice=2*error; if(twice>=dy){error+=dy;x0+=sx;} if(twice<=dx){error+=dx;y0+=sy;} }
    return this;
  }
  ellipse(x,y,width,height,name) {
    integers(x,y,width,height); this.color(name);
    if(width<1||height<1) throw new Error('Ellipse size must be positive');
    for(let py=Math.max(0,y);py<Math.min(this.height,y+height);py++) for(let px=Math.max(0,x);px<Math.min(this.width,x+width);px++) {
      const dx=2*(px-x)+1-width,dy=2*(py-y)+1-height;
      if(dx*dx*height*height+dy*dy*width*width<=width*width*height*height)this.px(px,py,name);
    }
    return this;
  }
  polygon(points,name) {
    if(points.length<3)throw new Error('Polygon needs three vertices');
    points.forEach(point=>integers(...point)); this.color(name);
    const minY=Math.max(0,Math.min(...points.map(p=>p[1]))),maxY=Math.min(this.height-1,Math.max(...points.map(p=>p[1])));
    for(let y=minY;y<=maxY;y++) {
      const crossings=[];
      for(let i=0,j=points.length-1;i<points.length;j=i++) {
        const [ax,ay]=points[i],[bx,by]=points[j];
        if((ay<=y&&by>y)||(by<=y&&ay>y))crossings.push(ax+(y-ay)*(bx-ax)/(by-ay));
      }
      crossings.sort((a,b)=>a-b);
      for(let i=0;i<crossings.length;i+=2)for(let x=Math.max(0,Math.ceil(crossings[i]));x<=Math.min(this.width-1,Math.floor(crossings[i+1]));x++)this.px(x,y,name);
    }
    for(let i=0;i<points.length;i++)this.line(...points[i],...points[(i+1)%points.length],name);
    return this;
  }
  stamp(source,x,y,scale=1) {
    integers(x,y,scale); if(scale<1)throw new Error('Stamp scale must be positive');
    for(let sy=0;sy<source.height;sy++)for(let sx=0;sx<source.width;sx++) {
      const index=(sy*source.width+sx)*4;
      if(source.data[index+3]===0)continue;
      if(source.data[index+3]!==255)throw new Error('Stamp only supports binary alpha');
      for(let dy=0;dy<scale;dy++)for(let dx=0;dx<scale;dx++) {
        const tx=x+sx*scale+dx,ty=y+sy*scale+dy;
        if(tx>=0&&ty>=0&&tx<this.width&&ty<this.height)this.data.set(source.data.subarray(index,index+4),(ty*this.width+tx)*4);
      }
    }
    return this;
  }
  recolor(mapping) {
    const lookup=new Map(Object.entries(mapping).map(([from,to])=>[this.color(from).join(','),this.color(to)]));
    for(let i=0;i<this.data.length;i+=4){const replacement=lookup.get(this.data.subarray(i,i+4).join(','));if(replacement)this.data.set(replacement,i);}
    return this;
  }
}
export function characterFrame(rows, palette, size) {
  const [width,height]=size;
  if(rows.length!==height || rows.some(row=>typeof row!=='string'||row.length!==width))throw new Error('Character frame dimensions do not match size');
  const canvas=new PixelCanvas(width,height,palette);
  rows.forEach((row,y)=>[...row].forEach((symbol,x)=>{
    if(symbol!=='.'&&!palette.chars[symbol])throw new Error(`Unknown character symbol: ${symbol}`);
    canvas.px(x,y,symbol==='.'?'.':palette.chars[symbol]);
  }));
  return canvas;
}
