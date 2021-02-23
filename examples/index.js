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

      const color = BigInt(-9580266); // color as 32bit representation of abgr!
      const centerX = Math.round(cvsImageData.width * 0.5);
      const centerY = Math.round(cvsImageData.height * 0.5);
        
      cvsRef.onmousemove = (e) => {
        if(window.inited) {
          window.ldExport.draw(centerX, centerY, e.offsetX, e.offsetY, color, 1);
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

