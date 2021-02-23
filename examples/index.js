window.cvsImageData = undefined;
window.cvsContext = undefined;
window.inited = false;
window.init = function(canvasId) {

      const cvsRef = document.getElementById(canvasId);
      const cvsContext = cvsRef.getContext('2d', { alpha: false });
      window.cvsContext = cvsContext;
      const cvsImageData = cvsContext.getImageData(0, 0, cvsRef.width, cvsRef.height);
      window.cvsImageData = cvsImageData;
      const pixels = (cvsRef.width * cvsRef.height) * 4;
      const pages = Math.ceil(pixels / 65536);
      window.memory = new WebAssembly.Memory({initial: pages + 1});
      WebAssembly.instantiateStreaming(fetch('../dist/line-drawer.wasm'), {js: {memory: window.memory } }).then(
        obj => { window.ldExport = obj.instance.exports; 
        });

      const color = (22 << 24) + (209 << 16) + (109 << 8) + 255;
      const color3 = (255 << 24) + (109 << 16) + (209 << 8) + 22;
      const color4 = BigInt(-9580266);
      const centerX = Math.round(cvsImageData.width * 0.5);
      const centerY = Math.round(cvsImageData.height * 0.5);
        
      cvsRef.onmousemove = (e) => {
        if(window.inited) {
          window.ldExport.draw(centerX, centerY, e.offsetX, e.offsetY, color4, 1);
          //window.ldExport.draw(0, 0, e.offsetX, e.offsetY, color2, 1);
          //window.ldExport.draw(e.offsetX, 0, e.offsetX + 100, e.offsetY, color, 1);
          cvsContext.putImageData(window.cvsImageData, 0, 0);
        }
      }
}

window.startWebAssembly = function() {
  window.ldExport.init(window.cvsImageData.width, window.cvsImageData.height, window.cvsImageData.width * 4);
  const data = new Uint8ClampedArray(window.memory.buffer, 0, window.cvsImageData.width * window.cvsImageData.height * 4);
  window.cvsImageData = new ImageData(data, window.cvsImageData.width, window.cvsImageData.height);
  window.cvsContext.createImageData(window.cvsImageData);
  window.ldExport.fill(BigInt(255 << 24));
  window.inited = true;
}

window.checkFunc = function() {
  //const res = window.ldExport.c_s_u(50);
  const res = window.ldExport.draw(150, 250, 50, 50, 120, 20, 20, 255);
  window.cvsImageData.data.set(window.wasmArray);
  window.cvsContext.putImageData(window.cvsImageData, 0, 0);
  // const res = window.ldExport.clearAll(255);
  // window.cvsImageData.data.set(window.wasmArray);
  // window.cvsContext.putImageData(window.cvsImageData, 0, 0);
}

window.setBackground = function()
{
    const data = window.cvsImageData.data;
    const stride = window.cvsImageData.width * 4;

    let pixel = 0;
    for (let i = 0; i < window.cvsImageData.height; i++) {
        for (let j = 0; j < window.cvsImageData.width; j++) {
            pixel = i * stride + j * 4;
            data[pixel] = 50;
            data[pixel + 1] = 50;
            data[pixel + 2] = 50;
            data[pixel + 3] = 255;
        }
    }

    window.cvsContext.putImageData(window.cvsImageData, 0, 0);
}
