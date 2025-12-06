const canvas_image = document.getElementById("Image");
const ctx_image = canvas_image.getContext("2d");

const img = new Image();
const img_chef = new Image();
// img.onload = function() {
//     ctx_image.drawImage(img, 150, 150, 50, 50);
//     ctx_image.drawImage(img_chef, 150, 150, 50, 50);
// }
// img.src = "/2_web/images/m_archer.jpg";
// img.src = "/2_web/images/chef.svg";

const canvasSizeX = 500;
const canvasSizeY = 500;
const dx = 1;
const dy = 1;
var x = 1;
var y = 1;

function int() {
    img_chef.src = "/2_web/images/chef.svg";
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
    ctx_image.drawImage(img_chef, 1, 1, 150, 150);
    ctx_image.translate(dx, dy);
    x = x + dx;
    y = x + dy;
    }
    window.requestAnimationFrame(draw);
}
int()

