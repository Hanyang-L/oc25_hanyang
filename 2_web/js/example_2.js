console.log("bon")

const statut = document.getElementById("statut");
const ctx_statut = statut.getContext("2d");
console.log(ctx_statut);

ctx_statut.fillStyle = "red";
ctx_statut.fillRect(0,0,300,300);

const dessin = document.getElementById("dessin");
const context = dessin.getContext("2d");

context.fillStyle = "green";
context.fillRect(0,0,200,100);
context.fillRect(200,200,100,100);

