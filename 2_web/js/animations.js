const canvas_image = document.getElementById("Image");
const ctx_image = canvas_image.getContext("2d");

const img_wukong = new Image();

const canvasSizeX = 500;
const canvasSizeY = 500;
const dx = 1;
const dy = 1;
var x = 1;
var y = 1;

function int() {
    img_wukong.src = "/2_web/images/wukong_anim.png";
    window.requestAnimationFrame(draw);
}
function draw() {
    ctx_image.clearRect(0, 0, 500, 500);
    if(x > canvasSizeX){
    ctx_image.translate(-canvasSizeX, -canvasSizeY);
    x = 1;
    y = 1;
    }
    else {
    ctx_image.drawImage(img_wukong, 1, 1, 150, 150);
    ctx_image.translate(dx, dy);
    x = x + dx;
    y = x + dy;
    }
    window.requestAnimationFrame(draw);
}
int()

