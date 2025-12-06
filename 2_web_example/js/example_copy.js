var jean = {
    nom:'jean',
    classe:'guerrier',
    niveau:'2',
    passer_niveau: function() {
        this.niveau++;
    }
};

console.log(jean);
console.log(jean.niveau);
jean.passer_niveau();
console.log(jean.niveau)

function creer_perso(nom, classe, niveau) {
    var nouveau_perso = {
        nom: nom,
        classe: classe,
        niveau: niveau,
        passer_niveau: function() {
            this.niveau++;
        },
        creer_li: function(){
            var li_perso = document.createElement('li');
            var texte_perso = document.createTextNode(
                this.nom + '(' + this.classe + ', niveau '+ this.niveau + ')'
            );
            li_perso.appendChild(texte_perso);
            li_perso.setAttribute('class', this.classe)
            return li_perso;
        }
    }

    return nouveau_perso;
};

var nicole = creer_perso('Nicole', 'voleur', 3);
console.log(nicole);

var troupe= [
    creer_perso('Jean', 'guerrier', 2),
    creer_perso('Nicole', 'voleur', 3),
    creer_perso('Matt', 'magicien', 4)
];

console.log(troupe);
console.log(troupe[0]);

 for (var i=0; i < troupe.length; i++) {
    var perso = troupe[i];
    li_perso = perso.creer_li();
    var liste_perso = document.getElementById("liste_perso")
    liste_perso.appendChild(li_perso);
 };
