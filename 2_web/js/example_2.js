console.log("bon")

const statut = document.getElementById("statut");
const ctx_statut = statut.getContext("2d");
console.log(ctx_statut);

ctx_statut.fillStyle = "red";
ctx_statut.fillRect(0,0,300,300);

const dessin = document.getElementById("dessin");
const context = dessin.getContext("2d");

context.beginPath();
context.strokeStyle = "red";
context.moveTo(250, 250);
context.lineTo(100, 250);
context.lineTo(250, 400);
context.lineTo(400, 250);
context.closePath();
context.fillStyle = "green";
context.fillStyle();
context.stroke();

context.beginPath();
context.arc(250, 250, 100  , 0, 2 * Maths.PI);
// (coordonné x du centre, coordoné y du centre, 
// rayon en px, angle de départ, angle en RAD)
context.fillStyle = "red";
context.fill();

// context.fillStyle = "green";
// context.fillRect(0,0,200,100);
// context.fillRect(200,200,100,100);

