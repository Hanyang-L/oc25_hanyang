const canvas_image = document.getElementById("Image");
const ctx_image = canvas_image.getContext("2d");
const img_wukong = new Image();
ctx_image.imageSmoothingEnabled = false

const canvasSizeX = 500;
const canvasSizeY = 500;
canvas_image.width  = canvasSizeX;
canvas_image.height = canvasSizeY;
let x = 180;
let y = 220;
const yMin = 200;
const yMax = 260;
let dy = 1;
function init() {
    img_wukong.src = "/2_web/images/wukong_anim.png";
    img_wukong.onload = () => {
        window.requestAnimationFrame(draw);
    };
}
function draw() {
    ctx_image.clearRect(0, 0, canvasSizeX, canvasSizeY);
    y += dy;
    if (y > yMax || y < yMin) {
        dy = -dy;
    }
    ctx_image.drawImage(img_wukong, x, y, 460, 390); //x=80, y=68, ratio:0.85
    window.requestAnimationFrame(draw);
}
init();