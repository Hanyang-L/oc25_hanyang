const canvas_image = document.getElementById("Image");
const ctx_image = canvas_image.getContext("2d");
const img_wukong = new Image();
ctx_image.imageSmoothingEnabled = false

const canvasSizeX = 600;
const canvasSizeY = 500;
let x = 90;
let y = 0;
const yMin = 0;
const yMax = 20;
let dy = 0.5; //gère la vitesse
function down_up() {
    img_wukong.src = "/2_web/images/wukong_anim.png";
    window.requestAnimationFrame(draw);
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
down_up();